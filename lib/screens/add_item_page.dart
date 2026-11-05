import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';
import '../models/item_data.dart';

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final formKey = GlobalKey<FormState>();
  bool isSaving = false;
  final nameController = TextEditingController();
  final brandController = TextEditingController();
  final modelController = TextEditingController();
  final quantityController = TextEditingController();
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();

  String? selectedCategory;
  String selectedCondition = 'Good';

  final List<String> categories = [
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

  final List<String> conditions = ['Good', 'Damaged', 'Maintenance'];

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

  Future<void> saveItem() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (isSaving) return;

    setState(() {
      isSaving = true;
    });

    try {
      final quantity = int.parse(quantityController.text.trim());

      // Create a new Firestore document reference.
      final document = FirebaseFirestore.instance.collection('items').doc();

      final newItem = Item(
        id: document.id,
        name: nameController.text.trim(),
        category: selectedCategory!,
        brand: brandController.text.trim(),
        model: modelController.text.trim(),
        totalQuantity: quantity,
        availableQuantity: quantity,
        outQuantity: 0,
        damagedQuantity: 0,
        maintenanceQuantity: 0,
        missingQuantity: 0,
        location: locationController.text.trim(),
        condition: selectedCondition,
        description: descriptionController.text.trim(),
      );

      print('FIRESTORE: Starting item save...');
      print('FIRESTORE DOCUMENT ID: ${document.id}');

      // Save permanently to Firestore.
      await document.set({
        'name': newItem.name,
        'category': newItem.category,
        'brand': newItem.brand,
        'model': newItem.model,

        'totalQuantity': newItem.totalQuantity,
        'availableQuantity': newItem.availableQuantity,
        'outQuantity': newItem.outQuantity,
        'damagedQuantity': newItem.damagedQuantity,
        'maintenanceQuantity': newItem.maintenanceQuantity,
        'missingQuantity': newItem.missingQuantity,

        'location': newItem.location,
        'condition': newItem.condition,
        'description': newItem.description,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('FIRESTORE: Item saved successfully!');
      // Keep the existing app working for now.
      itemList.add(newItem);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item saved to database successfully.')),
      );

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
          content: Text('Unable to save item. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),

      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Add Item',
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
                    'Register New Item',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Enter the equipment information below.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 30),

                  // ITEM NAME
                  TextFormField(
                    controller: nameController,

                    decoration: inputDecoration(
                      'Item Name',
                      'Example: Logitech G29',
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

                  // CATEGORY
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,

                    decoration: inputDecoration(
                      'Category',
                      'Select category',
                      Icons.category_outlined,
                    ),

                    items: categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),

                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value;
                      });
                    },

                    validator: (value) {
                      if (value == null) {
                        return 'Please select a category.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // BRAND
                  TextFormField(
                    controller: brandController,

                    decoration: inputDecoration(
                      'Brand',
                      'Example: Logitech',
                      Icons.business_outlined,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // MODEL
                  TextFormField(
                    controller: modelController,

                    decoration: inputDecoration(
                      'Model',
                      'Example: G29',
                      Icons.label_outline,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // QUANTITY
                  TextFormField(
                    controller: quantityController,

                    keyboardType: TextInputType.number,

                    decoration: inputDecoration(
                      'Total Quantity',
                      'Example: 20',
                      Icons.numbers,
                    ),

                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the quantity.';
                      }

                      final quantity = int.tryParse(value);

                      if (quantity == null || quantity <= 0) {
                        return 'Enter a valid quantity.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // LOCATION
                  TextFormField(
                    controller: locationController,

                    decoration: inputDecoration(
                      'Storage Location',
                      'Example: Main Store',
                      Icons.location_on_outlined,
                    ),

                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the storage location.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // CONDITION
                  DropdownButtonFormField<String>(
                    initialValue: selectedCondition,

                    decoration: inputDecoration(
                      'Condition',
                      'Select condition',
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

                  // DESCRIPTION
                  TextFormField(
                    controller: descriptionController,

                    maxLines: 4,

                    decoration: inputDecoration(
                      'Description',
                      'Additional information about this item',
                      Icons.notes,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },

                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 17),
                          ),

                          child: const Text('CANCEL'),
                        ),
                      ),

                      const SizedBox(width: 15),

                      Expanded(
                        child: FilledButton.icon(
                          onPressed: isSaving ? null : saveItem,

                          icon: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),

                          label: Text(
                            isSaving ? 'SAVING...' : 'SAVE ITEM',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),

                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A5F),

                            padding: const EdgeInsets.symmetric(vertical: 17),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,

      prefixIcon: Icon(icon),

      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
