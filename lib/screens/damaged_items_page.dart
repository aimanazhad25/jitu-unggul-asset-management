import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';

class DamagedItemsPage extends StatefulWidget {
  final String handledBy;
  final bool embedded;

  const DamagedItemsPage({
    super.key,

    required this.handledBy,
    this.embedded = false,
  });

  @override
  State<DamagedItemsPage> createState() => _DamagedItemsPageState();
}

class _DamagedItemsPageState extends State<DamagedItemsPage> {
  bool isLoading = true;

  bool isProcessing = false;

  List<Item> damagedItems = [];

  @override
  void initState() {
    super.initState();

    loadDamagedItems();
  }

  // ============================================================

  // LOAD DAMAGED ITEMS

  // ============================================================

  Future<void> loadDamagedItems() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('damagedQuantity', isGreaterThan: 0)
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
        damagedItems = loadedItems;

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load damaged items: $e')),
      );
    }
  }

  // ============================================================

  // RESOLVE DIALOG

  // ============================================================

  Future<void> showResolveDialog(Item item) async {
    final quantityController = TextEditingController(text: '1');

    final notesController = TextEditingController();

    String resolution = 'REPAIRED';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Resolve Damaged Item — ${item.name}'),

              content: SizedBox(
                width: 450,

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text('Currently damaged: ${item.damagedQuantity}'),

                    const SizedBox(height: 20),

                    TextField(
                      controller: quantityController,

                      keyboardType: TextInputType.number,

                      decoration: const InputDecoration(
                        labelText: 'Quantity to Resolve',

                        prefixIcon: Icon(Icons.numbers),

                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      initialValue: resolution,

                      decoration: const InputDecoration(
                        labelText: 'Resolution',

                        prefixIcon: Icon(Icons.build_outlined),

                        border: OutlineInputBorder(),
                      ),

                      items: const [
                        DropdownMenuItem(
                          value: 'REPAIRED',

                          child: Text('Repaired — Return to Available'),
                        ),

                        DropdownMenuItem(
                          value: 'MAINTENANCE',

                          child: Text('Send to Maintenance'),
                        ),
                      ],

                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            resolution = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: notesController,

                      maxLines: 3,

                      decoration: const InputDecoration(
                        labelText: 'Notes',

                        hintText: 'Example: HDMI port damaged.',

                        prefixIcon: Icon(Icons.notes),

                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },

                  child: const Text('CANCEL'),
                ),

                FilledButton.icon(
                  onPressed: () {
                    final quantity = int.tryParse(
                      quantityController.text.trim(),
                    );

                    if (quantity == null || quantity <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid quantity.'),
                        ),
                      );

                      return;
                    }

                    if (quantity > item.damagedQuantity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Only ${item.damagedQuantity} damaged units are available.',
                          ),
                        ),
                      );

                      return;
                    }

                    if (notesController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter notes.')),
                      );

                      return;
                    }

                    Navigator.pop(dialogContext, {
                      'quantity': quantity,

                      'notes': notesController.text.trim(),

                      'resolution': resolution,
                    });
                  },

                  icon: const Icon(Icons.check),

                  label: const Text('CONFIRM'),
                ),
              ],
            );
          },
        );
      },
    );

    quantityController.dispose();

    notesController.dispose();

    if (result == null) return;

    await resolveDamagedItem(
      item: item,

      quantity: result['quantity'] as int,

      notes: result['notes'] as String,

      resolution: result['resolution'] as String,
    );
  }

  // ============================================================

  // FIRESTORE TRANSACTION

  // ============================================================

  Future<void> resolveDamagedItem({
    required Item item,

    required int quantity,

    required String notes,

    required String resolution,
  }) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final itemRef = firestore.collection('items').doc(item.id);

      final movementRef = firestore.collection('movements').doc();

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(itemRef);

        if (!snapshot.exists) {
          throw Exception('Item no longer exists.');
        }

        final data = snapshot.data()!;

        final currentDamaged = (data['damagedQuantity'] as num?)?.toInt() ?? 0;

        final currentAvailable =
            (data['availableQuantity'] as num?)?.toInt() ?? 0;

        final currentMaintenance =
            (data['maintenanceQuantity'] as num?)?.toInt() ?? 0;

        if (quantity > currentDamaged) {
          throw Exception('Only $currentDamaged damaged units remain.');
        }

        // ==========================================

        // REPAIRED

        // ==========================================

        if (resolution == 'REPAIRED') {
          transaction.update(itemRef, {
            'damagedQuantity': currentDamaged - quantity,

            'availableQuantity': currentAvailable + quantity,

            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        // ==========================================
        // SEND TO MAINTENANCE
        // ==========================================
        else if (resolution == 'MAINTENANCE') {
          transaction.update(itemRef, {
            'damagedQuantity': currentDamaged - quantity,

            'maintenanceQuantity': currentMaintenance + quantity,

            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // ==========================================

        // ACTIVITY RECORD

        // ==========================================

        transaction.set(movementRef, {
          'type': resolution == 'REPAIRED'
              ? 'DAMAGED_REPAIRED'
              : 'DAMAGED_TO_MAINTENANCE',

          'itemId': item.id,

          'itemName': item.name,

          'quantity': quantity,

          'notes': notes,

          'handledBy': widget.handledBy,

          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resolution == 'REPAIRED'
                ? '$quantity × ${item.name} repaired and returned to available.'
                : '$quantity × ${item.name} sent to maintenance.',
          ),
        ),
      );

      await loadDamagedItems();

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
        SnackBar(content: Text('Unable to resolve damaged item: $e')),
      );
    }
  }

  // ============================================================

  // UI

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
                'Damaged Items',

                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : damagedItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Icon(
                    Icons.report_problem_outlined,

                    size: 70,

                    color: Colors.grey.shade400,
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    'No damaged items',

                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'No equipment is currently marked as damaged.',

                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: loadDamagedItems,

              child: ListView.separated(
                padding: const EdgeInsets.all(24),

                itemCount: damagedItems.length,

                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),

                itemBuilder: (context, index) {
                  final item = damagedItems[index];

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
                              color: const Color(0xFFFFE5E5),

                              borderRadius: BorderRadius.circular(12),
                            ),

                            child: const Icon(
                              Icons.report_problem_outlined,

                              color: Colors.red,
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

                                Text('Storage: ${item.location}'),

                                const SizedBox(height: 4),

                                Text(
                                  'Damaged: ${item.damagedQuantity}',

                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,

                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          FilledButton.icon(
                            onPressed: isProcessing
                                ? null
                                : () {
                                    showResolveDialog(item);
                                  },

                            icon: const Icon(Icons.build_outlined),

                            label: const Text('RESOLVE'),

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
