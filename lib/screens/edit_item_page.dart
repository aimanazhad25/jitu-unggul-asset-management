import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';

class EditItemPage extends StatefulWidget {
  final Item item;

  const EditItemPage({super.key, required this.item});

  @override
  State<EditItemPage> createState() => _EditItemPageState();
}

class _EditItemPageState extends State<EditItemPage> {
  final formKey = GlobalKey<FormState>();
  bool isUpdating = false;
  late TextEditingController nameController;
  late TextEditingController brandController;
  late TextEditingController modelController;
  late TextEditingController quantityController;
  late TextEditingController locationController;
  late TextEditingController descriptionController;

  late String selectedCategory;
  late String selectedCondition;

  final categories = [
    'Gaming Console',
    'Racing Simulator',
    'VR Equipment',
    'Computer / Laptop',
    'Monitor / TV',
    'Controller',
    'Audio Equipment',
    'Network Equipment',
    'Cable / Adapter',
    'Furniture',
    'Other',
  ];

  final conditions = ['Good', 'Damaged', 'Maintenance'];

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.item.name);
    brandController = TextEditingController(text: widget.item.brand);
    modelController = TextEditingController(text: widget.item.model);

    quantityController = TextEditingController(
      text: widget.item.totalQuantity.toString(),
    );

    locationController = TextEditingController(text: widget.item.location);

    descriptionController = TextEditingController(
      text: widget.item.description,
    );

    selectedCategory = widget.item.category;
    selectedCondition = widget.item.condition;
  }

  @override
  void dispose() {
    nameController.dispose();
    brandController.dispose();
    modelController.dispose();
    quantityController.dispose();
    locationController.dispose();
    descriptionController.dispose();

    super.dispose();
  }

  Future<void> updateItem() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (isUpdating) return;

    setState(() {
      isUpdating = true;
    });

    try {
      final newTotal = int.parse(quantityController.text.trim());

      final difference = newTotal - widget.item.totalQuantity;
      final newAvailable = widget.item.availableQuantity + difference;

      await FirebaseFirestore.instance
          .collection('items')
          .doc(widget.item.id)
          .update({
            'name': nameController.text.trim(),
            'category': selectedCategory,
            'brand': brandController.text.trim(),
            'model': modelController.text.trim(),

            'totalQuantity': newTotal,
            'availableQuantity': newAvailable,

            'location': locationController.text.trim(),
            'condition': selectedCondition,
            'description': descriptionController.text.trim(),

            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Update the local object only after Firestore succeeds.
      widget.item.name = nameController.text.trim();
      widget.item.category = selectedCategory;
      widget.item.brand = brandController.text.trim();
      widget.item.model = modelController.text.trim();

      widget.item.totalQuantity = newTotal;
      widget.item.availableQuantity = newAvailable;

      widget.item.location = locationController.text.trim();
      widget.item.condition = selectedCondition;
      widget.item.description = descriptionController.text.trim();

      if (!mounted) return;

      Navigator.pop(context, true);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database error: ${e.message ?? e.code}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update item. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),

      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),

      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Edit Item',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),

        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),

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
                  const Text(
                    'Edit Item Information',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 30),

                  TextFormField(
                    controller: nameController,
                    decoration: inputDecoration(
                      'Item Name',
                      Icons.inventory_2_outlined,
                    ),

                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the item name.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,

                    decoration: inputDecoration(
                      'Category',
                      Icons.category_outlined,
                    ),

                    items: categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),

                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedCategory = value;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 18),

                  TextFormField(
                    controller: brandController,
                    decoration: inputDecoration(
                      'Brand',
                      Icons.business_outlined,
                    ),
                  ),

                  const SizedBox(height: 18),

                  TextFormField(
                    controller: modelController,
                    decoration: inputDecoration('Model', Icons.label_outline),
                  ),

                  const SizedBox(height: 18),

                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,

                    decoration: inputDecoration(
                      'Total Quantity',
                      Icons.numbers,
                    ),

                    validator: (value) {
                      final quantity = int.tryParse(value ?? '');

                      if (quantity == null || quantity <= 0) {
                        return 'Enter a valid quantity.';
                      }

                      final unavailable =
                          widget.item.outQuantity +
                          widget.item.damagedQuantity +
                          widget.item.maintenanceQuantity +
                          widget.item.missingQuantity;

                      if (quantity < unavailable) {
                        return 'Total cannot be lower than $unavailable unavailable items.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  TextFormField(
                    controller: locationController,

                    decoration: inputDecoration(
                      'Storage Location',
                      Icons.location_on_outlined,
                    ),

                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter location.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  DropdownButtonFormField<String>(
                    initialValue: selectedCondition,

                    decoration: inputDecoration(
                      'Condition',
                      Icons.build_outlined,
                    ),

                    items: conditions.map((condition) {
                      return DropdownMenuItem(
                        value: condition,
                        child: Text(condition),
                      );
                    }).toList(),

                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedCondition = value;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 18),

                  TextFormField(
                    controller: descriptionController,
                    maxLines: 4,

                    decoration: inputDecoration('Description', Icons.notes),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 52,

                    child: FilledButton.icon(
                      onPressed: isUpdating ? null : updateItem,

                      icon: isUpdating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),

                      label: Text(
                        isUpdating ? 'UPDATING...' : 'UPDATE ITEM',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
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
}
