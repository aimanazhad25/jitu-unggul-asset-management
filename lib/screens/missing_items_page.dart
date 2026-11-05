import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';

class MissingItemsPage extends StatefulWidget {
  final String handledBy;
  final bool embedded;

  const MissingItemsPage({
    super.key,

    required this.handledBy,
    this.embedded = false,
  });

  @override
  State<MissingItemsPage> createState() => _MissingItemsPageState();
}

class _MissingItemsPageState extends State<MissingItemsPage> {
  bool isLoading = true;

  bool isProcessing = false;

  List<Item> missingItems = [];

  @override
  void initState() {
    super.initState();

    loadMissingItems();
  }

  Future<void> loadMissingItems() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('items')
          .where('missingQuantity', isGreaterThan: 0)
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
        missingItems = loadedItems;

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load missing items: $e')),
      );
    }
  }

  Future<void> showFoundDialog(Item item) async {
    final quantityController = TextEditingController(text: '1');

    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Resolve Missing Item — ${item.name}'),

          content: SizedBox(
            width: 450,

            child: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text('Currently missing: ${item.missingQuantity}'),

                const SizedBox(height: 20),

                TextField(
                  controller: quantityController,

                  keyboardType: TextInputType.number,

                  decoration: const InputDecoration(
                    labelText: 'Quantity Found',

                    prefixIcon: Icon(Icons.numbers),

                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 15),

                TextField(
                  controller: notesController,

                  maxLines: 3,

                  decoration: const InputDecoration(
                    labelText: 'Notes',

                    hintText: 'Example: Found in event storage room.',

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
                Navigator.pop(dialogContext, false);
              },

              child: const Text('CANCEL'),
            ),

            FilledButton.icon(
              onPressed: () {
                final quantity = int.tryParse(quantityController.text.trim());

                if (quantity == null || quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid quantity.')),
                  );

                  return;
                }

                if (quantity > item.missingQuantity) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Only ${item.missingQuantity} units are missing.',
                      ),
                    ),
                  );

                  return;
                }

                if (notesController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a note.')),
                  );

                  return;
                }

                Navigator.pop(dialogContext, true);
              },

              icon: const Icon(Icons.search_outlined),

              label: const Text('MARK AS FOUND'),
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

    await markItemFound(item: item, quantity: quantity, notes: notes);
  }

  Future<void> markItemFound({
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

      final movementRef = firestore.collection('movements').doc();

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(itemRef);

        if (!snapshot.exists) {
          throw Exception('Item no longer exists.');
        }

        final data = snapshot.data()!;

        final currentMissing = (data['missingQuantity'] as num?)?.toInt() ?? 0;

        final currentAvailable =
            (data['availableQuantity'] as num?)?.toInt() ?? 0;

        if (quantity > currentMissing) {
          throw Exception('Only $currentMissing units are currently missing.');
        }

        transaction.update(itemRef, {
          'missingQuantity': currentMissing - quantity,

          'availableQuantity': currentAvailable + quantity,

          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(movementRef, {
          'type': 'MISSING_FOUND',

          'itemId': item.id,

          'itemName': item.name,

          'quantity': quantity,

          'notes': notes,

          'fromLocation': 'Missing',

          'toLocation': item.location,

          'handledBy': widget.handledBy,

          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$quantity × ${item.name} marked as found.')),
      );

      await loadMissingItems();

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
        SnackBar(content: Text('Unable to resolve missing item: $e')),
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
                'Missing Items',

                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : missingItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Icon(
                    Icons.inventory_2_outlined,

                    size: 70,

                    color: Colors.grey.shade400,
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    'No missing items',

                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'All equipment is accounted for.',

                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: loadMissingItems,

              child: ListView.separated(
                padding: const EdgeInsets.all(24),

                itemCount: missingItems.length,

                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),

                itemBuilder: (context, index) {
                  final item = missingItems[index];

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
                              Icons.search_off_outlined,

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
                                  'Missing: ${item.missingQuantity}',

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
                                    showFoundDialog(item);
                                  },

                            icon: const Icon(Icons.search),

                            label: const Text('FOUND'),

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
