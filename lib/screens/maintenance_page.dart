import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';

class MaintenancePage extends StatefulWidget {
  final String handledBy;
  final bool embedded;

  const MaintenancePage({
    super.key,
    required this.handledBy,
    this.embedded = false,
  });

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  bool isLoading = true;

  bool isProcessing = false;

  List<Item> maintenanceItems = [];

  @override
  void initState() {
    super.initState();

    loadMaintenanceItems();
  }

  Future<void> loadMaintenanceItems() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('maintenanceQuantity', isGreaterThan: 0)
          .get();

      final loadedItems = snapshot.docs.map((doc) {
        final data = doc.data();

        return Item(
          id: doc.id,

          name: data['name']?.toString() ?? '',

          category: data['category']?.toString() ?? '',

          brand: data['brand']?.toString() ?? '',

          model: data['model']?.toString() ?? '',

          totalQuantity: (data['totalQuantity'] as num?)?.toInt() ?? 0,

          availableQuantity: (data['availableQuantity'] as num?)?.toInt() ?? 0,

          outQuantity: (data['outQuantity'] as num?)?.toInt() ?? 0,

          damagedQuantity: (data['damagedQuantity'] as num?)?.toInt() ?? 0,

          maintenanceQuantity:
              (data['maintenanceQuantity'] as num?)?.toInt() ?? 0,

          missingQuantity: (data['missingQuantity'] as num?)?.toInt() ?? 0,

          location: data['location']?.toString() ?? '',

          condition: data['condition']?.toString() ?? '',

          description: data['description']?.toString() ?? '',
        );
      }).toList();

      loadedItems.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      if (!mounted) return;

      setState(() {
        maintenanceItems = loadedItems;

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load maintenance items: $e')),
      );
    }
  }

  Future<void> showRepairDialog(Item item) async {
    final quantityController = TextEditingController(text: '1');

    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Complete Maintenance — ${item.name}'),

          content: SizedBox(
            width: 450,

            child: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'Currently in maintenance: '
                  '${item.maintenanceQuantity}',
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: quantityController,

                  keyboardType: TextInputType.number,

                  decoration: const InputDecoration(
                    labelText: 'Quantity Repaired',

                    border: OutlineInputBorder(),

                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),

                const SizedBox(height: 15),

                TextField(
                  controller: notesController,

                  maxLines: 3,

                  decoration: const InputDecoration(
                    labelText: 'Maintenance / Repair Notes',

                    hintText: 'Example: Controller repaired and tested.',

                    border: OutlineInputBorder(),

                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },

              child: const Text('CANCEL'),
            ),

            FilledButton.icon(
              onPressed: () async {
                final quantity = int.tryParse(quantityController.text.trim());

                if (quantity == null || quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid repair quantity.'),
                    ),
                  );

                  return;
                }

                if (quantity > item.maintenanceQuantity) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Only ${item.maintenanceQuantity} '
                        'units are in maintenance.',
                      ),
                    ),
                  );

                  return;
                }

                if (notesController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter maintenance notes.'),
                    ),
                  );

                  return;
                }

                Navigator.pop(dialogContext, true);
              },

              icon: const Icon(Icons.check_circle_outline),

              label: const Text('MARK REPAIRED'),
            ),
          ],
        );
      },
    );

    if (result != true) {
      quantityController.dispose();

      notesController.dispose();

      return;
    }

    final quantity = int.parse(quantityController.text.trim());

    final notes = notesController.text.trim();

    quantityController.dispose();

    notesController.dispose();

    await completeMaintenance(item: item, quantity: quantity, notes: notes);
  }

  Future<void> completeMaintenance({
    required Item item,

    required int quantity,

    required String notes,
  }) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final itemRef = firestore.collection('items').doc(item.id);

      final recordRef = firestore.collection('maintenance_records').doc();

      final movementRef = firestore.collection('movements').doc();

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(itemRef);

        if (!snapshot.exists) {
          throw Exception('Item no longer exists.');
        }

        final data = snapshot.data()!;

        final currentMaintenance =
            (data['maintenanceQuantity'] as num?)?.toInt() ?? 0;

        final currentAvailable =
            (data['availableQuantity'] as num?)?.toInt() ?? 0;

        if (quantity > currentMaintenance) {
          throw Exception(
            'Only $currentMaintenance units '
            'are currently in maintenance.',
          );
        }

        final newMaintenance = currentMaintenance - quantity;

        final newAvailable = currentAvailable + quantity;

        transaction.update(itemRef, {
          'maintenanceQuantity': newMaintenance,

          'availableQuantity': newAvailable,

          'condition': newMaintenance > 0 ? 'Maintenance' : 'Good',

          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(recordRef, {
          'itemId': item.id,

          'itemName': item.name,

          'quantity': quantity,

          'notes': notes,

          'handledBy': widget.handledBy,

          'status': 'COMPLETED',

          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(movementRef, {
          'type': 'MAINTENANCE_COMPLETED',

          'itemId': item.id,

          'itemName': item.name,

          'quantity': quantity,

          'notes': notes,

          'fromLocation': 'Maintenance',

          'toLocation': item.location,

          'handledBy': widget.handledBy,

          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$quantity × ${item.name} '
            'returned to available inventory.',
          ),
        ),
      );

      await loadMaintenanceItems();

      if (!mounted) return;

      setState(() {
        isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to complete maintenance: $e')),
      );
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
                'Maintenance',

                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : maintenanceItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Icon(
                    Icons.check_circle_outline,

                    size: 70,

                    color: Colors.grey.shade400,
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    'No items in maintenance',

                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'All equipment is ready for use.',

                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: loadMaintenanceItems,

              child: ListView.separated(
                padding: const EdgeInsets.all(24),

                itemCount: maintenanceItems.length,

                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),

                itemBuilder: (context, index) {
                  final item = maintenanceItems[index];

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
                              color: const Color(0xFFFFF3CD),

                              borderRadius: BorderRadius.circular(12),
                            ),

                            child: const Icon(
                              Icons.build_outlined,

                              color: Colors.orange,
                            ),
                          ),

                          const SizedBox(width: 18),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  item.name,

                                  style: const TextStyle(
                                    fontSize: 18,

                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text('${item.brand} ${item.model}'.trim()),

                                const SizedBox(height: 4),

                                Text('Location: ${item.location}'),

                                const SizedBox(height: 4),

                                Text(
                                  'Maintenance: '
                                  '${item.maintenanceQuantity}',

                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          FilledButton.icon(
                            onPressed: isProcessing
                                ? null
                                : () {
                                    showRepairDialog(item);
                                  },

                            icon: const Icon(Icons.construction),

                            label: const Text('COMPLETE'),

                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A5F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
