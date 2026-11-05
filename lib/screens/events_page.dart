import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event.dart';

import '../models/event_data.dart';

import 'add_event_page.dart';

class EventsPage extends StatefulWidget {
  final bool embedded;

  const EventsPage({super.key, this.embedded = false});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    loadEvents();
  }

  Future<void> loadEvents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .orderBy('startDate')
          .get();

      final loadedEvents = snapshot.docs.map((doc) {
        final data = doc.data();

        return Event(
          id: doc.id,

          name: data['name']?.toString() ?? '',

          location: data['location']?.toString() ?? '',

          startDate: data['startDate'] is Timestamp
              ? (data['startDate'] as Timestamp).toDate()
              : DateTime.now(),

          endDate: data['endDate'] is Timestamp
              ? (data['endDate'] as Timestamp).toDate()
              : DateTime.now(),

          personInCharge: data['personInCharge']?.toString() ?? '',

          status: data['status']?.toString() ?? 'Upcoming',

          notes: data['notes']?.toString() ?? '',
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        eventList
          ..clear()
          ..addAll(loadedEvents);

        isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load events: ${e.message ?? e.code}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to load events: $e')));
    }
  }

  String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Display-only status, calculated from the event's calendar dates.
  // Does not overwrite the Firestore 'status' field.
  String getAutomaticEventStatus(DateTime startDate, DateTime endDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    if (today.isBefore(start)) return 'Upcoming';
    if (today.isAfter(end)) return 'Completed';
    return 'Ongoing';
  }

  Color getStatusBackgroundColor(String status) {
    switch (status) {
      case 'Ongoing':
        return const Color(0xFFDDF5E6);
      case 'Completed':
        return const Color(0xFFE5E7EB);
      default:
        return const Color(0xFFFFF3CD);
    }
  }

  Color getStatusTextColor(String status) {
    switch (status) {
      case 'Ongoing':
        return const Color(0xFF166534);
      case 'Completed':
        return const Color(0xFF374151);
      default:
        return const Color(0xFF854D0E);
    }
  }

  Future<void> deleteEvent(Event event) async {
    try {
      // =========================================================

      // 1. LOAD ALL MOVEMENTS FOR THIS EVENT

      // =========================================================

      final snapshot = await FirebaseFirestore.instance
          .collection('movements')
          .where('eventId', isEqualTo: event.id)
          .get();

      // itemId -> OUT quantity

      final Map<String, int> outTotals = {};

      // itemId -> IN quantity

      final Map<String, int> inTotals = {};

      // itemId -> item name

      final Map<String, String> itemNames = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final String itemId = data['itemId']?.toString() ?? '';

        final String itemName = data['itemName']?.toString() ?? 'Unknown Item';

        final String type = data['type']?.toString().toUpperCase() ?? '';

        final int quantity = (data['quantity'] as num?)?.toInt() ?? 0;

        if (itemId.isEmpty) {
          continue;
        }

        itemNames[itemId] = itemName;

        if (type == 'OUT') {
          outTotals[itemId] = (outTotals[itemId] ?? 0) + quantity;
        } else if (type == 'IN') {
          inTotals[itemId] = (inTotals[itemId] ?? 0) + quantity;
        }
      }

      // =========================================================

      // 2. CALCULATE OUTSTANDING ITEMS

      // =========================================================

      final Map<String, int> outstandingItems = {};

      for (final entry in outTotals.entries) {
        final String itemId = entry.key;

        final int quantityOut = entry.value;

        final int quantityIn = inTotals[itemId] ?? 0;

        final int outstanding = quantityOut - quantityIn;

        if (outstanding > 0) {
          outstandingItems[itemId] = outstanding;
        }
      }

      if (!mounted) return;

      // =========================================================

      // 3. BLOCK DELETION IF ITEMS ARE STILL OUT

      // =========================================================

      if (outstandingItems.isNotEmpty) {
        await showDialog<void>(
          context: context,

          builder: (dialogContext) {
            return AlertDialog(
              icon: const Icon(
                Icons.warning_amber_rounded,

                size: 45,

                color: Colors.orange,
              ),

              title: const Text('Cannot Delete Event'),

              content: SizedBox(
                width: 420,

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      '"${event.name}" still has equipment '
                      'that has not been returned.',
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Outstanding Items:',

                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 8),

                    ...outstandingItems.entries.map((entry) {
                      final itemName = itemNames[entry.key] ?? 'Unknown Item';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),

                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 18),

                            const SizedBox(width: 8),

                            Expanded(child: Text(itemName)),

                            Text(
                              '${entry.value} out',

                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 14),

                    const Text(
                      'Return all outstanding equipment '
                      'before deleting this event.',
                    ),
                  ],
                ),
              ),

              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },

                  child: const Text('OK'),
                ),
              ],
            );
          },
        );

        return;
      }

      // =========================================================

      // 4. ASK FOR DELETE CONFIRMATION

      // =========================================================

      final bool? confirmed = await showDialog<bool>(
        context: context,

        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(Icons.delete_outline, size: 42, color: Colors.red),

            title: const Text('Delete Event?'),

            content: Text(
              'Are you sure you want to delete '
              '"${event.name}"?\n\n'
              'This action cannot be undone.',
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },

                child: const Text('Cancel'),
              ),

              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },

                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,

                  foregroundColor: Colors.white,
                ),

                icon: const Icon(Icons.delete_outline),

                label: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }

      // =========================================================

      // 5. DELETE FROM FIRESTORE

      // =========================================================

      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .delete();

      if (!mounted) return;

      // =========================================================

      // 6. UPDATE LOCAL EVENT LIST

      // =========================================================

      setState(() {
        eventList.removeWhere((existingEvent) => existingEvent.id == event.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${event.name} deleted successfully.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to delete event: '
            '${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to delete event: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),

      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: Colors.white,

              title: const Text(
                'Events',

                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            'Events',

                            style: TextStyle(
                              fontSize: 26,

                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 4),

                          Text(
                            'Manage Jitu Unggul events',

                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),

                      FilledButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (context) => const AddEventPage(),
                            ),
                          );

                          if (result == true) {
                            await loadEvents();
                          }
                        },

                        icon: const Icon(Icons.add),

                        label: const Text('Add Event'),

                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),

                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,

                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  Expanded(
                    child: eventList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,

                              children: [
                                Icon(
                                  Icons.event_outlined,

                                  size: 70,

                                  color: Colors.grey.shade400,
                                ),

                                const SizedBox(height: 15),

                                const Text(
                                  'No events created',

                                  style: TextStyle(
                                    fontSize: 20,

                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  'Create your first Jitu Unggul event.',

                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: eventList.length,

                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),

                            itemBuilder: (context, index) {
                              final event = eventList[index];
                              final displayStatus = getAutomaticEventStatus(
                                event.startDate,
                                event.endDate,
                              );

                              return Card(
                                color: Colors.white,

                                child: Padding(
                                  padding: const EdgeInsets.all(20),

                                  child: Row(
                                    children: [
                                      Container(
                                        width: 60,

                                        height: 60,

                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEAF0F7),

                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),

                                        child: const Icon(
                                          Icons.event,

                                          color: Color(0xFF1E3A5F),
                                        ),
                                      ),

                                      const SizedBox(width: 18),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,

                                          children: [
                                            Text(
                                              event.name,

                                              style: const TextStyle(
                                                fontSize: 18,

                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),

                                            const SizedBox(height: 7),

                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.location_on_outlined,

                                                  size: 17,
                                                ),

                                                const SizedBox(width: 5),

                                                Text(event.location),
                                              ],
                                            ),

                                            const SizedBox(height: 5),

                                            Text(
                                              '${formatDate(event.startDate)} - '
                                              '${formatDate(event.endDate)}',
                                            ),

                                            const SizedBox(height: 5),

                                            Text(
                                              'PIC: ${event.personInCharge}',
                                            ),
                                          ],
                                        ),
                                      ),

                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,

                                          vertical: 7,
                                        ),

                                        decoration: BoxDecoration(
                                          color: getStatusBackgroundColor(
                                            displayStatus,
                                          ),

                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),

                                        child: Text(
                                          displayStatus,

                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: getStatusTextColor(
                                              displayStatus,
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      IconButton(
                                        tooltip: 'Delete Event',

                                        onPressed: () async {
                                          await deleteEvent(event);
                                        },

                                        icon: const Icon(
                                          Icons.delete_outline,

                                          color: Colors.red,
                                        ),
                                      ),
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
    );
  }
}
