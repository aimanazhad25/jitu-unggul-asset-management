import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';

import '../models/item_data.dart';

import '../models/event.dart';

import '../models/event_data.dart';

import '../models/movement.dart';

import '../models/movement_data.dart';

class ItemOutPage extends StatefulWidget {
  final String handledBy;
  final bool embedded;
  final VoidCallback? onCompleted;

  const ItemOutPage({
    super.key,
    required this.handledBy,
    this.embedded = false,
    this.onCompleted,
  });

  @override
  State<ItemOutPage> createState() => _ItemOutPageState();
}

class _ItemOutPageState extends State<ItemOutPage> {
  final formKey = GlobalKey<FormState>();

  // ============================================================

  // EQUIPMENT CONTROLLERS

  // ============================================================

  // ============================================================

  // CLIENT CONTROLLERS

  // ============================================================

  final clientCompanyController = TextEditingController();

  final contactPersonController = TextEditingController();

  final clientPhoneController = TextEditingController();

  final clientEmailController = TextEditingController();

  final clientLocationController = TextEditingController();

  final clientReferenceController = TextEditingController();

  final clientNotesController = TextEditingController();

  Event? selectedEvent;

  final List<_CheckoutItem> checkoutItems = [];

  bool isSubmitting = false;

  // ============================================================

  // DISPOSE

  // ============================================================

  @override
  void dispose() {
    clientCompanyController.dispose();

    contactPersonController.dispose();

    clientPhoneController.dispose();

    clientEmailController.dispose();

    clientLocationController.dispose();

    clientReferenceController.dispose();

    clientNotesController.dispose();

    super.dispose();
  }

  // Search and select multiple items with individual quantities.
  Future<void> showItemPicker() async {
    if (isSubmitting) return;

    final searchController = TextEditingController();
    final Map<String, int> pending = {};
    String search = '';
    String? error;

    try {
      final result = await showDialog<Map<String, int>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, updateDialog) {
            final availableItems = itemList.where((item) {
              final alreadyAdded = checkoutItems
                  .where((entry) => entry.item.id == item.id)
                  .fold<int>(0, (sum, entry) => sum + entry.quantity);
              return item.availableQuantity - alreadyAdded > 0;
            }).toList();

            final filtered =
                availableItems.where((item) {
                  final text = [
                    item.name,
                    item.category,
                    item.brand,
                    item.model,
                    item.location,
                  ].join(' ').toLowerCase();
                  return text.contains(search.toLowerCase().trim());
                }).toList()..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );

            return AlertDialog(
              title: const Text('Select Equipment'),
              contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              content: SizedBox(
                width: 650,
                height: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search name, category, brand, model...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => updateDialog(() => search = value),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${pending.length} item type(s) selected',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('No matching available items.'),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                final alreadyAdded = checkoutItems
                                    .where((entry) => entry.item.id == item.id)
                                    .fold<int>(
                                      0,
                                      (sum, entry) => sum + entry.quantity,
                                    );
                                final remaining =
                                    item.availableQuantity - alreadyAdded;
                                final checked = pending.containsKey(item.id);
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: checked,
                                          onChanged: (value) =>
                                              updateDialog(() {
                                                if (value == true) {
                                                  pending[item.id] = 1;
                                                } else {
                                                  pending.remove(item.id);
                                                }
                                                error = null;
                                              }),
                                        ),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => updateDialog(() {
                                              if (checked) {
                                                pending.remove(item.id);
                                              } else {
                                                pending[item.id] = 1;
                                              }
                                              error = null;
                                            }),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  '$remaining available • ${item.location}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (checked) ...[
                                          IconButton(
                                            tooltip: 'Decrease quantity',
                                            onPressed: pending[item.id]! > 1
                                                ? () => updateDialog(
                                                    () => pending[item.id] =
                                                        pending[item.id]! - 1,
                                                  )
                                                : null,
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                            ),
                                          ),
                                          Text(
                                            '${pending[item.id]}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Increase quantity',
                                            onPressed:
                                                pending[item.id]! < remaining
                                                ? () => updateDialog(
                                                    () => pending[item.id] =
                                                        pending[item.id]! + 1,
                                                  )
                                                : null,
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL'),
                ),
                FilledButton.icon(
                  onPressed: pending.isEmpty
                      ? null
                      : () {
                          for (final entry in pending.entries) {
                            final item = availableItems.firstWhere(
                              (item) => item.id == entry.key,
                            );
                            final existing = checkoutItems
                                .where((row) => row.item.id == item.id)
                                .fold<int>(0, (sum, row) => sum + row.quantity);
                            if (entry.value < 1 ||
                                entry.value + existing >
                                    item.availableQuantity) {
                              updateDialog(
                                () => error =
                                    'Invalid quantity for ${item.name}.',
                              );
                              return;
                            }
                          }
                          Navigator.pop(
                            dialogContext,
                            Map<String, int>.from(pending),
                          );
                        },
                  icon: const Icon(Icons.add),
                  label: Text('ADD ${pending.length} SELECTED'),
                ),
              ],
            );
          },
        ),
      );

      if (!mounted || result == null || result.isEmpty) return;
      setState(() {
        for (final entry in result.entries) {
          final item = itemList.firstWhere((item) => item.id == entry.key);
          final index = checkoutItems.indexWhere(
            (row) => row.item.id == item.id,
          );
          if (index >= 0) {
            checkoutItems[index].quantity += entry.value;
          } else {
            checkoutItems.add(_CheckoutItem(item: item, quantity: entry.value));
          }
        }
      });
    } finally {
      // Defer disposal until the dialog transition has completed.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => searchController.dispose(),
      );
    }
  }

  // ============================================================

  // REMOVE ITEM

  // ============================================================

  void removeCheckoutItem(int index) {
    setState(() {
      checkoutItems.removeAt(index);
    });
  }

  // ============================================================

  // TOTAL UNITS

  // ============================================================

  int get totalCheckoutUnits {
    return checkoutItems.fold<int>(0, (total, entry) => total + entry.quantity);
  }

  // ============================================================

  // CONFIRM ALL ITEMS OUT

  // ============================================================

  Future<void> confirmItemOut() async {
    if (isSubmitting) {
      return;
    }

    if (!formKey.currentState!.validate()) {
      return;
    }

    if (selectedEvent == null) {
      showMessage('Please select an event.');

      return;
    }

    if (checkoutItems.isEmpty) {
      showMessage('Please add at least one item to the checkout list.');

      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final eventRef = firestore.collection('events').doc(selectedEvent!.id);

      // Create one movement reference for every equipment type.

      final movementRefs = checkoutItems
          .map((_) => firestore.collection('movements').doc())
          .toList();

      await firestore.runTransaction((transaction) async {
        // ======================================================

        // READ ALL ITEM DOCUMENTS FIRST

        // ======================================================

        final List<DocumentSnapshot<Map<String, dynamic>>> itemSnapshots = [];

        for (final checkout in checkoutItems) {
          final itemRef = firestore.collection('items').doc(checkout.item.id);

          final snapshot = await transaction.get(itemRef);

          if (!snapshot.exists) {
            throw Exception(
              '${checkout.item.name} was not found in Firestore.',
            );
          }

          itemSnapshots.add(snapshot);
        }

        // ======================================================

        // VALIDATE CURRENT FIRESTORE QUANTITIES

        // ======================================================

        for (int i = 0; i < checkoutItems.length; i++) {
          final checkout = checkoutItems[i];

          final data = itemSnapshots[i].data()!;

          final int currentAvailable =
              (data['availableQuantity'] as num?)?.toInt() ?? 0;

          if (checkout.quantity > currentAvailable) {
            throw Exception(
              'Only $currentAvailable unit(s) of '
              '${checkout.item.name} are currently available.',
            );
          }
        }

        // ======================================================

        // SAVE CLIENT INFORMATION TO EVENT

        // ======================================================

        transaction.update(eventRef, {
          'clientCompany': clientCompanyController.text.trim(),

          'clientContactPerson': contactPersonController.text.trim(),

          'clientPhone': clientPhoneController.text.trim(),

          'clientEmail': clientEmailController.text.trim(),

          'clientLocation': clientLocationController.text.trim(),

          'clientReference': clientReferenceController.text.trim(),

          'clientNotes': clientNotesController.text.trim(),

          'updatedAt': FieldValue.serverTimestamp(),
        });

        // ======================================================

        // UPDATE EVERY ITEM + CREATE MOVEMENT

        // ======================================================

        for (int i = 0; i < checkoutItems.length; i++) {
          final checkout = checkoutItems[i];

          final itemRef = firestore.collection('items').doc(checkout.item.id);

          final data = itemSnapshots[i].data()!;

          final int currentAvailable =
              (data['availableQuantity'] as num?)?.toInt() ?? 0;

          final int currentOut = (data['outQuantity'] as num?)?.toInt() ?? 0;

          final int newAvailable = currentAvailable - checkout.quantity;

          final int newOut = currentOut + checkout.quantity;

          // UPDATE INVENTORY

          transaction.update(itemRef, {
            'availableQuantity': newAvailable,

            'outQuantity': newOut,

            'updatedAt': FieldValue.serverTimestamp(),
          });

          // CREATE INDIVIDUAL OUT MOVEMENT

          transaction.set(movementRefs[i], {
            'type': 'OUT',

            'itemId': checkout.item.id,

            'itemName': checkout.item.name,

            'eventId': selectedEvent!.id,

            'eventName': selectedEvent!.name,

            'quantity': checkout.quantity,

            'fromLocation': checkout.item.location,

            'toLocation': selectedEvent!.location,

            'handledBy': widget.handledBy,

            // Client snapshot
            'clientCompany': clientCompanyController.text.trim(),

            'clientContactPerson': contactPersonController.text.trim(),

            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // ========================================================

      // UPDATE LOCAL DATA

      // ========================================================

      for (int i = 0; i < checkoutItems.length; i++) {
        final checkout = checkoutItems[i];

        checkout.item.availableQuantity -= checkout.quantity;

        checkout.item.outQuantity += checkout.quantity;

        final movement = Movement(
          id: movementRefs[i].id,

          type: 'OUT',

          itemId: checkout.item.id,

          itemName: checkout.item.name,

          eventId: selectedEvent!.id,

          eventName: selectedEvent!.name,

          quantity: checkout.quantity,

          fromLocation: checkout.item.location,

          toLocation: selectedEvent!.location,

          handledBy: widget.handledBy,

          dateTime: DateTime.now(),
        );

        movementList.add(movement);
      }

      final totalUnits = totalCheckoutUnits;

      final totalTypes = checkoutItems.length;

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$totalUnits unit(s) across '
            '$totalTypes item type(s) '
            'successfully checked out.',
          ),
        ),
      );

      if (widget.embedded) {
        widget.onCompleted?.call();
        setState(() {
          checkoutItems.clear();
        });
      } else {
        Navigator.pop(context, true);
      }
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      showMessage(
        'Unable to check out items: '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      showMessage('Unable to check out items: $e');
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  // ============================================================

  // MESSAGE

  // ============================================================

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================

  // BUILD

  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),

      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: Colors.white,

              title: const Text(
                'Items Out',

                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),

        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 760),

            padding: const EdgeInsets.all(28),

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.circular(16),
            ),

            child: Form(
              key: formKey,

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // ==================================================

                  // HEADER

                  // ==================================================
                  const Text(
                    'Record Items Out',

                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Assign multiple equipment types to a '
                    'Jitu Unggul event.',

                    style: TextStyle(color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 30),

                  // ==================================================

                  // EVENT

                  // ==================================================
                  const _SectionTitle(
                    icon: Icons.event_outlined,

                    title: 'Event',
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<Event>(
                    initialValue: selectedEvent,

                    isExpanded: true,

                    decoration: inputDecoration('Event', Icons.event_outlined),

                    items: eventList.map((event) {
                      return DropdownMenuItem<Event>(
                        value: event,

                        child: Text(
                          '${event.name} — ${event.location}',

                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),

                    onChanged: isSubmitting
                        ? null
                        : (value) {
                            setState(() {
                              selectedEvent = value;
                            });
                          },

                    validator: (value) {
                      if (value == null) {
                        return 'Please select an event.';
                      }

                      return null;
                    },
                  ),

                  // ==================================================

                  // CLIENT INFORMATION

                  // ==================================================
                  const SizedBox(height: 30),

                  const _SectionTitle(
                    icon: Icons.business_outlined,

                    title: 'Client Information',
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Enter the client details for this event.',

                    style: TextStyle(color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 18),

                  TextFormField(
                    controller: clientCompanyController,

                    enabled: !isSubmitting,

                    decoration: inputDecoration(
                      'Client / Company Name',

                      Icons.business,
                    ),

                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter the client or company name.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: contactPersonController,

                    enabled: !isSubmitting,

                    decoration: inputDecoration(
                      'Contact Person',

                      Icons.person_outline,
                    ),

                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter the contact person.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: clientPhoneController,

                    enabled: !isSubmitting,

                    keyboardType: TextInputType.phone,

                    decoration: inputDecoration(
                      'Phone Number',

                      Icons.phone_outlined,
                    ),

                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter the phone number.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: clientEmailController,

                    enabled: !isSubmitting,

                    keyboardType: TextInputType.emailAddress,

                    decoration: inputDecoration(
                      'Email (Optional)',

                      Icons.email_outlined,
                    ),

                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null;
                      }

                      final email = value.trim();

                      if (!email.contains('@') || !email.contains('.')) {
                        return 'Enter a valid email address.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: clientLocationController,

                    enabled: !isSubmitting,

                    decoration: inputDecoration(
                      'Client Location',

                      Icons.location_on_outlined,
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: clientReferenceController,

                    enabled: !isSubmitting,

                    decoration: inputDecoration(
                      'Reference / PO No. (Optional)',

                      Icons.receipt_long_outlined,
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: clientNotesController,

                    enabled: !isSubmitting,

                    maxLines: 3,

                    decoration: inputDecoration(
                      'Client Notes (Optional)',

                      Icons.notes_outlined,
                    ),
                  ),

                  // ==================================================

                  // EQUIPMENT

                  // ==================================================
                  const SizedBox(height: 30),

                  const _SectionTitle(
                    icon: Icons.inventory_2_outlined,

                    title: 'Equipment',
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Search and select multiple equipment types, then adjust quantities.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: isSubmitting ? null : showItemPicker,
                      icon: const Icon(Icons.search),
                      label: const Text(
                        'SEARCH & SELECT MULTIPLE ITEMS',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // ==================================================

                  // SELECTED EQUIPMENT

                  // ==================================================
                  if (checkoutItems.isNotEmpty) ...[
                    const SizedBox(height: 28),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [
                        const Text(
                          'Selected Equipment',

                          style: TextStyle(
                            fontSize: 18,

                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,

                            vertical: 6,
                          ),

                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF0F7),

                            borderRadius: BorderRadius.circular(20),
                          ),

                          child: Text(
                            '$totalCheckoutUnits total unit(s)',

                            style: const TextStyle(
                              color: Color(0xFF1E3A5F),

                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    ...checkoutItems.asMap().entries.map((entry) {
                      final index = entry.key;

                      final checkout = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),

                        padding: const EdgeInsets.all(16),

                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),

                          borderRadius: BorderRadius.circular(12),

                          border: Border.all(color: Colors.grey.shade300),
                        ),

                        child: Row(
                          children: [
                            Container(
                              width: 44,

                              height: 44,

                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF0F7),

                                borderRadius: BorderRadius.circular(10),
                              ),

                              child: const Icon(
                                Icons.inventory_2_outlined,

                                color: Color(0xFF1E3A5F),
                              ),
                            ),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  Text(
                                    checkout.item.name,

                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,

                                      fontSize: 16,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    'Quantity: '
                                    '${checkout.quantity}',

                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),

                                  Text(
                                    'From: '
                                    '${checkout.item.location}',

                                    style: TextStyle(
                                      fontSize: 12,

                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            IconButton(
                              tooltip: 'Remove Item',

                              onPressed: isSubmitting
                                  ? null
                                  : () {
                                      removeCheckoutItem(index);
                                    },

                              icon: const Icon(
                                Icons.delete_outline,

                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // ==================================================

                  // HANDLED BY

                  // ==================================================
                  const SizedBox(height: 28),

                  Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(16),

                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),

                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Row(
                      children: [
                        const Icon(Icons.person_outline),

                        const SizedBox(width: 12),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              'Handled By',

                              style: TextStyle(
                                fontSize: 12,

                                color: Colors.grey.shade600,
                              ),
                            ),

                            Text(
                              widget.handledBy,

                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ==================================================

                  // WARNINGS

                  // ==================================================
                  if (eventList.isEmpty) ...[
                    const SizedBox(height: 20),

                    const Text(
                      '⚠ No events available. '
                      'Create an event first.',

                      style: TextStyle(
                        color: Colors.orange,

                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],

                  if (itemList.isEmpty) ...[
                    const SizedBox(height: 10),

                    const Text(
                      '⚠ No items available. '
                      'Register an item first.',

                      style: TextStyle(
                        color: Colors.orange,

                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],

                  // ==================================================

                  // CONFIRM

                  // ==================================================
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,

                    height: 54,

                    child: FilledButton.icon(
                      onPressed:
                          eventList.isEmpty || itemList.isEmpty || isSubmitting
                          ? null
                          : confirmItemOut,

                      icon: isSubmitting
                          ? const SizedBox(
                              width: 20,

                              height: 20,

                              child: CircularProgressIndicator(
                                strokeWidth: 2,

                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.outbox_outlined),

                      label: Text(
                        isSubmitting
                            ? 'PROCESSING...'
                            : 'CONFIRM ALL ITEMS OUT',

                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),

                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================

  // INPUT DECORATION

  // ============================================================

  InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,

      prefixIcon: Icon(icon),

      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// ================================================================

// CHECKOUT ITEM

// ================================================================

class _CheckoutItem {
  final Item item;

  int quantity;

  _CheckoutItem({required this.item, required this.quantity});
}

// ================================================================

// SECTION TITLE

// ================================================================

class _SectionTitle extends StatelessWidget {
  final IconData icon;

  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1E3A5F)),

        const SizedBox(width: 10),

        Text(
          title,

          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
