import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';

import '../models/item_data.dart';

import 'add_item_page.dart';

import 'edit_item_page.dart';

import 'import_items_page.dart';

class ItemsPage extends StatefulWidget {
  final String initialFilter;

  final String userRole;
  final bool embedded;

  const ItemsPage({
    super.key,

    this.initialFilter = 'ALL',

    this.userRole = 'staff',
    this.embedded = false,
  });

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  bool get isAdmin => widget.userRole.toLowerCase() == 'admin';

  bool isLoading = true;

  String? loadError;

  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';

  late String selectedFilter;

  final List<String> inventoryFilters = [
    'ALL',

    'AVAILABLE',

    'OUT',

    'DAMAGED',

    'MAINTENANCE',

    'MISSING',
  ];

  @override
  void initState() {
    super.initState();

    if (inventoryFilters.contains(widget.initialFilter)) {
      selectedFilter = widget.initialFilter;
    } else {
      selectedFilter = 'ALL';
    }

    loadItems();
  }

  List<Item> get filteredItems {
    final query = searchQuery.trim().toLowerCase();

    return itemList.where((item) {
      // ==============================

      // SEARCH

      // ==============================

      final matchesSearch =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.brand.toLowerCase().contains(query) ||
          item.model.toLowerCase().contains(query) ||
          item.location.toLowerCase().contains(query) ||
          item.condition.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query);

      if (!matchesSearch) {
        return false;
      }

      // ==============================

      // FILTER

      // ==============================

      switch (selectedFilter) {
        case 'AVAILABLE':
          return item.availableQuantity > 0;

        case 'OUT':
          return item.outQuantity > 0;

        case 'DAMAGED':
          return item.damagedQuantity > 0;

        case 'MAINTENANCE':
          return item.maintenanceQuantity > 0;

        case 'MISSING':
          return item.missingQuantity > 0;

        case 'ALL':
        default:
          return true;
      }
    }).toList();
  }

  Future<void> loadItems() async {
    try {
      setState(() {
        isLoading = true;

        loadError = null;
      });

      final snapshot = await FirebaseFirestore.instance
          .collection('items')
          .get();

      final loadedItems = snapshot.docs.map((doc) {
        final data = doc.data();

        return Item(
          id: doc.id,

          name: data['name']?.toString() ?? '',

          category: data['category']?.toString() ?? 'Other',

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

          condition: data['condition']?.toString() ?? 'Good',

          description: data['description']?.toString() ?? '',
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        itemList
          ..clear()
          ..addAll(loadedItems);

        isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;

        loadError = e.message ?? e.code;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;

        loadError = e.toString();
      });
    }
  }

  Future<void> deleteItem(BuildContext context, int index) async {
    final item = itemList[index];

    // ============================================================

    // SAFETY CHECK

    // ============================================================

    final List<String> problems = [];

    if (item.outQuantity > 0) {
      problems.add('${item.outQuantity} unit(s) currently OUT');
    }

    if (item.maintenanceQuantity > 0) {
      problems.add('${item.maintenanceQuantity} unit(s) under MAINTENANCE');
    }

    if (item.damagedQuantity > 0) {
      problems.add('${item.damagedQuantity} unit(s) marked DAMAGED');
    }

    if (item.missingQuantity > 0) {
      problems.add('${item.missingQuantity} unit(s) marked MISSING');
    }

    // ============================================================

    // BLOCK DELETE IF ITEM HAS UNRESOLVED QUANTITIES

    // ============================================================

    if (problems.isNotEmpty) {
      await showDialog<void>(
        context: context,

        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,

              color: Colors.orange,

              size: 48,
            ),

            title: const Text('Cannot Delete Item'),

            content: SizedBox(
              width: 420,

              child: Column(
                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    '"${item.name}" cannot be deleted '
                    'because it still has unresolved inventory.',
                  ),

                  const SizedBox(height: 18),

                  ...problems.map(
                    (problem) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),

                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          const Icon(
                            Icons.circle,

                            size: 8,

                            color: Colors.orange,
                          ),

                          const SizedBox(width: 10),

                          Expanded(child: Text(problem)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Resolve these quantities before deleting the item.',

                    style: TextStyle(fontWeight: FontWeight.w600),
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

    // ============================================================

    // CONFIRM DELETE

    // ============================================================

    final bool? confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 45),

          title: const Text('Delete Item?'),

          content: Text(
            'Are you sure you want to delete '
            '"${item.name}"?\n\n'
            'This action cannot be undone.',
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
                Navigator.pop(dialogContext, true);
              },

              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,

                foregroundColor: Colors.white,
              ),

              icon: const Icon(Icons.delete_outline),

              label: const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    // ============================================================

    // DELETE FROM FIRESTORE

    // ============================================================

    try {
      await FirebaseFirestore.instance
          .collection('items')
          .doc(item.id)
          .delete();

      if (!mounted) return;

      setState(() {
        itemList.removeWhere((existingItem) => existingItem.id == item.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} deleted successfully.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to delete item: '
            '${e.message ?? e.code}',
          ),

          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete item: $e'),

          backgroundColor: Colors.red,
        ),
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
                'Items',

                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // Responsive inventory header: stack actions on narrow screens.
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 650;
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Inventory',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage Jitu Unggul equipment',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                );
                final actions = Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (isAdmin)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (context) => const ImportItemsPage(),
                            ),
                          );

                          if (result == true) {
                            await loadItems();
                          }
                        },

                        icon: const Icon(Icons.upload_file),

                        label: const Text('Import CSV'),
                      ),
                    if (isAdmin)
                      FilledButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (context) => const AddItemPage(),
                            ),
                          );

                          if (result == true) {
                            await loadItems();
                          }
                        },

                        icon: const Icon(Icons.add),

                        label: const Text('Add Item'),

                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),

                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,

                            vertical: 16,
                          ),
                        ),
                      ),
                  ],
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading,
                      if (isAdmin) const SizedBox(height: 16),
                      if (isAdmin) actions,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: heading),
                    if (isAdmin) const SizedBox(width: 16),
                    if (isAdmin) actions,
                  ],
                );
              },
            ),

            const SizedBox(height: 25),

            // SEARCH BAR
            TextField(
              controller: searchController,

              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },

              decoration: InputDecoration(
                hintText: 'Search items...',

                prefixIcon: const Icon(Icons.search),

                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear Search',

                        onPressed: () {
                          searchController.clear();

                          setState(() {
                            searchQuery = '';
                          });
                        },

                        icon: const Icon(Icons.close),
                      )
                    : null,

                filled: true,

                fillColor: Colors.white,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),

                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 14),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,

              child: Row(
                children: inventoryFilters.map((filter) {
                  final bool selected = selectedFilter == filter;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),

                    child: ChoiceChip(
                      label: Text(filter),

                      selected: selected,

                      onSelected: (_) {
                        setState(() {
                          selectedFilter = filter;
                        });
                      },

                      selectedColor: const Color(0xFFDCE8F7),

                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xFF1E3A5F)
                            : Colors.grey.shade700,

                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),

                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF1E3A5F)
                            : Colors.grey.shade300,
                      ),

                      backgroundColor: Colors.white,

                      showCheckmark: selected,

                      checkmarkColor: const Color(0xFF1E3A5F),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              '${filteredItems.length} of ${itemList.length} items',

              style: TextStyle(
                color: Colors.grey.shade700,

                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 25),

            // ITEM LIST
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : loadError != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          const Icon(
                            Icons.error_outline,

                            size: 55,

                            color: Colors.red,
                          ),

                          const SizedBox(height: 12),

                          const Text(
                            'Unable to load inventory',

                            style: TextStyle(
                              fontSize: 18,

                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(loadError!),

                          const SizedBox(height: 16),

                          FilledButton.icon(
                            onPressed: loadItems,

                            icon: const Icon(Icons.refresh),

                            label: const Text('TRY AGAIN'),
                          ),
                        ],
                      ),
                    )
                  : itemList.isEmpty
                  // EMPTY INVENTORY
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
                            'No items registered',

                            style: TextStyle(
                              fontSize: 20,

                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'Add your first Jitu Unggul item.',

                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  // SHOW ITEMS
                  : ListView.separated(
                      itemCount: filteredItems.length,

                      separatorBuilder: (context, index) {
                        return const SizedBox(height: 12);
                      },

                      itemBuilder: (context, index) {
                        final item = filteredItems[index];

                        return Card(
                          color: Colors.white,

                          child: Padding(
                            padding: const EdgeInsets.all(18),

                            child: Row(
                              children: [
                                Container(
                                  width: 55,

                                  height: 55,

                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF0F7),

                                    borderRadius: BorderRadius.circular(12),
                                  ),

                                  child: const Icon(
                                    Icons.inventory_2_outlined,

                                    color: Color(0xFF1E3A5F),
                                  ),
                                ),

                                const SizedBox(width: 16),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                    children: [
                                      Text(
                                        item.name,

                                        style: const TextStyle(
                                          fontSize: 17,

                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      Text(
                                        item.category,

                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),

                                      const SizedBox(height: 7),

                                      const SizedBox(height: 8),

                                      Wrap(
                                        spacing: 18,

                                        runSpacing: 8,

                                        children: [
                                          _QuantityInfo(
                                            label: 'Total',

                                            value: item.totalQuantity,
                                          ),

                                          _QuantityInfo(
                                            label: 'Available',

                                            value: item.availableQuantity,
                                          ),

                                          _QuantityInfo(
                                            label: 'Out',

                                            value: item.outQuantity,
                                          ),

                                          _QuantityInfo(
                                            label: 'Damaged',

                                            value: item.damagedQuantity,
                                          ),

                                          _QuantityInfo(
                                            label: 'Maintenance',

                                            value: item.maintenanceQuantity,
                                          ),

                                          _QuantityInfo(
                                            label: 'Missing',

                                            value: item.missingQuantity,
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 8),

                                      Text('Location: ${item.location}'),
                                    ],
                                  ),
                                ),

                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,

                                        vertical: 7,
                                      ),

                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),

                                        borderRadius: BorderRadius.circular(20),
                                      ),

                                      child: Text(
                                        item.condition,

                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    if (isAdmin)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,

                                        children: [
                                          IconButton(
                                            tooltip: 'Edit',

                                            onPressed: () async {
                                              final result =
                                                  await Navigator.push(
                                                    context,

                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          EditItemPage(
                                                            item: item,
                                                          ),
                                                    ),
                                                  );

                                              if (result == true) {
                                                await loadItems();

                                                if (!context.mounted) return;

                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Item updated successfully.',
                                                        ),
                                                      ),
                                                    );
                                              }
                                            },

                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                          ),

                                          IconButton(
                                            tooltip: 'Delete',

                                            onPressed: () {
                                              final originalIndex = itemList
                                                  .indexWhere(
                                                    (existingItem) =>
                                                        existingItem.id ==
                                                        item.id,
                                                  );

                                              if (originalIndex != -1) {
                                                deleteItem(
                                                  context,

                                                  originalIndex,
                                                );
                                              }
                                            },

                                            icon: const Icon(
                                              Icons.delete_outline,

                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
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

  @override
  void dispose() {
    searchController.dispose();

    super.dispose();
  }
}

class _QuantityInfo extends StatelessWidget {
  final String label;

  final int value;

  const _QuantityInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          value.toString(),

          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),

        Text(
          label,

          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
