import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';
import '../models/item_data.dart';
import '../models/event.dart';
import '../models/event_data.dart';
import '../models/movement.dart';
import '../models/movement_data.dart';

class OutstandingCheckout {
  final Item item;
  final String eventId;
  final String eventName;
  final int quantity;
  final bool eventExists;

  const OutstandingCheckout({
    required this.item,
    required this.eventId,
    required this.eventName,
    required this.quantity,
    required this.eventExists,
  });
}

class _ReturnEntry {
  final OutstandingCheckout checkout;
  int good;
  int damaged;
  int maintenance;
  int missing;
  String maintenanceNotes;

  _ReturnEntry(this.checkout)
    : good = checkout.quantity,
      damaged = 0,
      maintenance = 0,
      missing = 0,
      maintenanceNotes = '';

  int get total => good + damaged + maintenance + missing;
}

class ItemInPage extends StatefulWidget {
  final String handledBy;
  final bool embedded;
  final VoidCallback? onCompleted;

  const ItemInPage({
    super.key,
    required this.handledBy,
    this.embedded = false,
    this.onCompleted,
  });

  @override
  State<ItemInPage> createState() => _ItemInPageState();
}

class _ItemInPageState extends State<ItemInPage> {
  Event? selectedEvent;
  bool isLoadingMovements = true;
  bool isSubmitting = false;
  String searchQuery = '';
  final Map<String, _ReturnEntry> selectedReturns = {};

  String checkoutKey(OutstandingCheckout c) => '${c.eventId}|||${c.item.id}';

  @override
  void initState() {
    super.initState();
    loadMovements();
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> loadMovements({bool showSpinner = true}) async {
    if (showSpinner && mounted) setState(() => isLoadingMovements = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('movements')
          .get();
      final loaded = snapshot.docs.map((doc) {
        final data = doc.data();
        final created = data['createdAt'];
        return Movement(
          id: doc.id,
          type: data['type']?.toString() ?? '',
          itemId: data['itemId']?.toString() ?? '',
          itemName: data['itemName']?.toString() ?? '',
          eventId: data['eventId']?.toString() ?? '',
          eventName: data['eventName']?.toString() ?? '',
          quantity: (data['quantity'] as num?)?.toInt() ?? 0,
          fromLocation: data['fromLocation']?.toString() ?? '',
          toLocation: data['toLocation']?.toString() ?? '',
          handledBy: data['handledBy']?.toString() ?? '',
          dateTime: created is Timestamp ? created.toDate() : DateTime.now(),
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        movementList
          ..clear()
          ..addAll(loaded);
        isLoadingMovements = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingMovements = false);
      showMessage('Unable to load movement history: $e');
    }
  }

  List<OutstandingCheckout> getAllOutstandingCheckouts() {
    final outTotals = <String, int>{};
    final inTotals = <String, int>{};
    final lastOut = <String, Movement>{};
    for (final movement in movementList) {
      final key = '${movement.eventId}|||${movement.itemId}';
      final type = movement.type.toUpperCase();
      if (type == 'OUT') {
        outTotals[key] = (outTotals[key] ?? 0) + movement.quantity;
        final previous = lastOut[key];
        if (previous == null || movement.dateTime.isAfter(previous.dateTime)) {
          lastOut[key] = movement;
        }
      } else if (type == 'IN') {
        inTotals[key] = (inTotals[key] ?? 0) + movement.quantity;
      }
    }
    final results = <OutstandingCheckout>[];
    for (final entry in outTotals.entries) {
      final outstanding = entry.value - (inTotals[entry.key] ?? 0);
      if (outstanding <= 0) continue;
      final movement = lastOut[entry.key];
      if (movement == null) continue;
      Item? item;
      for (final candidate in itemList) {
        if (candidate.id == movement.itemId) {
          item = candidate;
          break;
        }
      }
      if (item == null || item.outQuantity <= 0) continue;
      final quantity = outstanding < item.outQuantity
          ? outstanding
          : item.outQuantity;
      results.add(
        OutstandingCheckout(
          item: item,
          eventId: movement.eventId,
          eventName: movement.eventName.trim().isEmpty
              ? 'Unknown event'
              : movement.eventName,
          quantity: quantity,
          eventExists: eventList.any((e) => e.id == movement.eventId),
        ),
      );
    }
    results.sort(
      (a, b) => a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase()),
    );
    return results;
  }

  // The same item can be OUT for several events. Keep returns tied to the
  // original event so the movement ledger remains correct.
  List<OutstandingCheckout> get visibleCheckouts {
    final all = getAllOutstandingCheckouts();
    if (selectedEvent != null) {
      return all.where((c) => c.eventId == selectedEvent!.id).toList();
    }
    return all.where((c) => !c.eventExists).toList();
  }

  void toggleCheckout(OutstandingCheckout checkout, bool selected) {
    setState(() {
      final key = checkoutKey(checkout);
      if (selected) {
        selectedReturns[key] = _ReturnEntry(checkout);
      } else {
        selectedReturns.remove(key);
      }
    });
  }

  void updateQuantity(_ReturnEntry entry, String field, int value) {
    setState(() {
      switch (field) {
        case 'good':
          entry.good = value;
          break;
        case 'damaged':
          entry.damaged = value;
          break;
        case 'maintenance':
          entry.maintenance = value;
          break;
        case 'missing':
          entry.missing = value;
          break;
      }
    });
  }

  int get totalUnits =>
      selectedReturns.values.fold(0, (sum, e) => sum + e.total);

  String? validateReturns() {
    if (selectedReturns.isEmpty) return 'Select at least one item to return.';
    if (totalUnits <= 0) return 'Enter at least one unit to return.';
    final byItem = <String, int>{};
    for (final entry in selectedReturns.values) {
      if (entry.good < 0 ||
          entry.damaged < 0 ||
          entry.maintenance < 0 ||
          entry.missing < 0) {
        return '${entry.checkout.item.name}: quantities cannot be negative.';
      }
      if (entry.total > entry.checkout.quantity) {
        return '${entry.checkout.item.name}: maximum ${entry.checkout.quantity} outstanding units.';
      }
      if (entry.maintenance > 0 && entry.maintenanceNotes.trim().isEmpty) {
        return '${entry.checkout.item.name}: add maintenance notes.';
      }
      byItem.update(
        entry.checkout.item.id,
        (v) => v + entry.total,
        ifAbsent: () => entry.total,
      );
    }
    for (final entry in selectedReturns.values) {
      if (byItem[entry.checkout.item.id]! > entry.checkout.item.outQuantity) {
        return '${entry.checkout.item.name}: total returns exceed currently OUT stock.';
      }
    }
    return null;
  }

  Future<void> confirmItemsIn() async {
    if (isSubmitting) return;
    final error = validateReturns();
    if (error != null) {
      showMessage(error);
      return;
    }
    final entries = selectedReturns.values.where((e) => e.total > 0).toList();
    setState(() => isSubmitting = true);
    try {
      final firestore = FirebaseFirestore.instance;
      // Refresh movement history before committing to avoid stale event balances.
      final movementsSnapshot = await firestore.collection('movements').get();
      final balances = <String, int>{};
      for (final doc in movementsSnapshot.docs) {
        final d = doc.data();
        final type = d['type']?.toString().toUpperCase();
        if (type != 'OUT' && type != 'IN') continue;
        final key = '${d['eventId']}|||${d['itemId']}';
        final quantity = (d['quantity'] as num?)?.toInt() ?? 0;
        balances[key] =
            (balances[key] ?? 0) + (type == 'OUT' ? quantity : -quantity);
      }
      for (final entry in entries) {
        if (entry.total > (balances[checkoutKey(entry.checkout)] ?? 0)) {
          throw StateError(
            '${entry.checkout.item.name}: event outstanding quantity has changed. Refresh and try again.',
          );
        }
      }

      final refs = [
        for (final _ in entries) firestore.collection('movements').doc(),
      ];
      await firestore.runTransaction((transaction) async {
        final snapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        final totals = <String, List<int>>{};
        for (final entry in entries) {
          final id = entry.checkout.item.id;
          final bucket = totals.putIfAbsent(id, () => [0, 0, 0, 0, 0]);
          bucket[0] += entry.total;
          bucket[1] += entry.good;
          bucket[2] += entry.damaged;
          bucket[3] += entry.maintenance;
          bucket[4] += entry.missing;
        }
        // Read every distinct inventory document before any writes.
        for (final id in totals.keys) {
          final snapshot = await transaction.get(
            firestore.collection('items').doc(id),
          );
          if (!snapshot.exists) throw StateError('An item no longer exists.');
          snapshots[id] = snapshot;
        }
        for (final itemEntry in totals.entries) {
          final snapshot = snapshots[itemEntry.key]!;
          final d = snapshot.data()!;
          final q = itemEntry.value;
          int stock(String field) => (d[field] as num?)?.toInt() ?? 0;
          if (q[0] > stock('outQuantity')) {
            throw StateError(
              'Only ${stock('outQuantity')} units are currently OUT for this item.',
            );
          }
          transaction.update(snapshot.reference, {
            'availableQuantity': stock('availableQuantity') + q[1],
            'outQuantity': stock('outQuantity') - q[0],
            'damagedQuantity': stock('damagedQuantity') + q[2],
            'maintenanceQuantity': stock('maintenanceQuantity') + q[3],
            'missingQuantity': stock('missingQuantity') + q[4],
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        for (var i = 0; i < entries.length; i++) {
          final entry = entries[i];
          final c = entry.checkout;
          final event = eventList.where((e) => e.id == c.eventId).firstOrNull;
          transaction.set(refs[i], {
            'type': 'IN',
            'itemId': c.item.id,
            'itemName': c.item.name,
            'eventId': c.eventId,
            'eventName': c.eventName,
            'quantity': entry.total,
            'goodQuantity': entry.good,
            'damagedQuantity': entry.damaged,
            'maintenanceQuantity': entry.maintenance,
            'missingQuantity': entry.missing,
            'maintenanceNotes': entry.maintenanceNotes.trim(),
            'fromLocation': event?.location ?? 'Deleted Event',
            'toLocation': c.item.location,
            'handledBy': widget.handledBy,
            'createdAt': FieldValue.serverTimestamp(),
            'originalEventDeleted': !c.eventExists,
          });
        }
      });

      for (var i = 0; i < entries.length; i++) {
        final e = entries[i];
        final item = e.checkout.item;
        item.availableQuantity += e.good;
        item.outQuantity -= e.total;
        item.damagedQuantity += e.damaged;
        item.maintenanceQuantity += e.maintenance;
        item.missingQuantity += e.missing;
        final event = eventList
            .where((x) => x.id == e.checkout.eventId)
            .firstOrNull;
        movementList.add(
          Movement(
            id: refs[i].id,
            type: 'IN',
            itemId: item.id,
            itemName: item.name,
            eventId: e.checkout.eventId,
            eventName: e.checkout.eventName,
            quantity: e.total,
            fromLocation: event?.location ?? 'Deleted Event',
            toLocation: item.location,
            handledBy: widget.handledBy,
            dateTime: DateTime.now(),
          ),
        );
      }
      if (!mounted) return;
      final returned = entries.fold<int>(0, (sum, e) => sum + e.total);
      setState(() => selectedReturns.clear());
      showMessage(
        '$returned unit(s) across ${entries.length} item type(s) returned successfully.',
      );
      widget.onCompleted?.call();
      if (widget.embedded) {
        await loadMovements(showSpinner: false);
      } else if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      showMessage('Unable to return items: $e');
      // A failed transaction must never clear the user's selections.
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  InputDecoration decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget quantityField(
    _ReturnEntry entry,
    String field,
    String label,
    int value,
  ) {
    return SizedBox(
      width: 138,
      child: TextFormField(
        key: ValueKey('${checkoutKey(entry.checkout)}-$field'),
        initialValue: '$value',
        enabled: !isSubmitting,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (raw) {
          final number = int.tryParse(raw) ?? 0;
          updateQuantity(entry, field, number);
        },
      ),
    );
  }

  Widget selectedCard(_ReturnEntry entry) {
    final checkout = entry.checkout;
    final invalid = entry.total > checkout.quantity;
    return Container(
      key: ValueKey(checkoutKey(checkout)),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: invalid ? Colors.red : const Color(0xFFE0E6ED),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  checkout.item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove selection',
                onPressed: isSubmitting
                    ? null
                    : () => toggleCheckout(checkout, false),
                icon: const Icon(Icons.close, color: Colors.red),
              ),
            ],
          ),
          Text(
            'Event: ${checkout.eventName}  •  Outstanding: ${checkout.quantity}',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: [
              quantityField(entry, 'good', 'Good', entry.good),
              quantityField(entry, 'damaged', 'Damaged', entry.damaged),
              quantityField(
                entry,
                'maintenance',
                'Maintenance',
                entry.maintenance,
              ),
              quantityField(entry, 'missing', 'Missing', entry.missing),
            ],
          ),
          if (entry.maintenance > 0) ...[
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('${checkoutKey(checkout)}-notes'),
              initialValue: entry.maintenanceNotes,
              enabled: !isSubmitting,
              maxLines: 2,
              decoration: decoration(
                'Maintenance Notes (required)',
                Icons.build_outlined,
              ),
              onChanged: (text) => entry.maintenanceNotes = text,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Return total: ${entry.total} / ${checkout.quantity}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: invalid ? Colors.red : const Color(0xFF1E3A5F),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkouts = visibleCheckouts;
    final filtered = checkouts.where((c) {
      final q = searchQuery.toLowerCase().trim();
      final item = c.item;
      return q.isEmpty ||
          '${item.name} ${item.location} ${c.eventName} ${item.toString()}'
              .toLowerCase()
              .contains(q);
    }).toList();
    final all = getAllOutstandingCheckouts();
    final orphaned = all.where((c) => !c.eventExists).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              title: const Text('Items In'),
            ),
      body: isLoadingMovements
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Record Items In',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Search, select and return multiple equipment types in one operation.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'return-event-${selectedEvent?.id ?? 'deleted'}',
                        ),
                        initialValue: selectedEvent?.id ?? '__deleted__',
                        isExpanded: true,
                        decoration: decoration(
                          'Event / Return Source',
                          Icons.event_outlined,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '__deleted__',
                            child: Text('Deleted events / orphaned returns'),
                          ),
                          for (final event in eventList)
                            DropdownMenuItem(
                              value: event.id,
                              child: Text(
                                '${event.name} — ${event.location}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: isSubmitting
                            ? null
                            : (id) {
                                setState(() {
                                  selectedEvent = id == '__deleted__'
                                      ? null
                                      : eventList
                                            .where((e) => e.id == id)
                                            .firstOrNull;
                                  selectedReturns.clear();
                                  searchQuery = '';
                                });
                              },
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        enabled: !isSubmitting,
                        decoration: decoration(
                          'Search equipment or event',
                          Icons.search,
                        ),
                        onChanged: (text) => setState(() => searchQuery = text),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${filtered.length} matching items  •  ${selectedReturns.length} selected',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          child: Text(
                            checkouts.isEmpty
                                ? 'No outstanding items for this return source.'
                                : 'No matching items.',
                          ),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 330),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE0E6ED)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final checkout = filtered[index];
                              final selected = selectedReturns.containsKey(
                                checkoutKey(checkout),
                              );
                              return CheckboxListTile(
                                value: selected,
                                onChanged: isSubmitting
                                    ? null
                                    : (value) => toggleCheckout(
                                        checkout,
                                        value ?? false,
                                      ),
                                title: Text(
                                  checkout.item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${checkout.quantity} outstanding • ${checkout.eventName}${checkout.eventExists ? '' : ' (deleted event)'}',
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              );
                            },
                          ),
                        ),
                      if (orphaned.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          '⚠ ${orphaned.length} item type(s) have outstanding returns from deleted events. Select "Deleted events / orphaned returns" to process them.',
                          style: const TextStyle(color: Color(0xFF9B6500)),
                        ),
                      ],
                      if (selectedReturns.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        Text(
                          'Selected Equipment (${selectedReturns.length})',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...selectedReturns.values.map(selectedCard),
                        Text(
                          'Total units to return: $totalUnits',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          const Icon(Icons.person_outline),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Handled By: ${widget.handledBy}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A5F),
                          ),
                          onPressed: isSubmitting || selectedReturns.isEmpty
                              ? null
                              : confirmItemsIn,
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.move_to_inbox_outlined),
                          label: Text(
                            isSubmitting
                                ? 'PROCESSING...'
                                : 'CONFIRM ALL ITEMS IN',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
