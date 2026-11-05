import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

import 'dart:convert';

import 'package:csv/csv.dart';

class ImportItemsPage extends StatefulWidget {
  const ImportItemsPage({super.key});

  @override
  State<ImportItemsPage> createState() => _ImportItemsPageState();
}

class _ImportItemsPageState extends State<ImportItemsPage> {
  List<Map<String, dynamic>> previewItems = [];
  List<Map<String, dynamic>> rejectedItems = [];

  bool isReading = false;
  bool isImporting = false;

  String? fileName;
  String? errorMessage;

  // This importer is designed for our cleaned workbook:
  // Jitu_Unggul_Firestore_Import_Ready.xlsx
  Future<void> pickExcelFile() async {
    setState(() {
      isReading = true;
      errorMessage = null;
      previewItems.clear();
      rejectedItems.clear();
      fileName = null;
    });

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (file == null) {
        if (mounted) {
          setState(() {
            isReading = false;
          });
        }
        return;
      }

      final bytes = await file.readAsBytes();

      // utf8.decode handles the CSV file contents.
      // allowMalformed prevents unusual characters in old inventory
      // descriptions from crashing the importer.
      var csvText = utf8.decode(bytes, allowMalformed: true);

      // Remove UTF-8 BOM if present.
      if (csvText.startsWith('\uFEFF')) {
        csvText = csvText.substring(1);
      }

      final rows = CsvDecoder().convert(csvText);

      if (rows.isEmpty) {
        throw Exception('The selected CSV file is empty.');
      }

      final headers = rows.first
          .map((value) => value.toString().trim())
          .toList();

      int column(String name) {
        return headers.indexOf(name);
      }

      final nameIndex = column('name');
      final modelIndex = column('model');
      final codeIndex = column('assetCode');
      final descriptionIndex = column('description');
      final totalIndex = column('totalQuantity');
      final availableIndex = column('availableQuantity');
      final outIndex = column('outQuantity');
      final maintenanceIndex = column('maintenanceQuantity');
      final missingIndex = column('missingQuantity');
      final siteIndex = column('site');
      final locationIndex = column('location');
      final remarksIndex = column('remarks');
      final categoryIndex = column('category');
      final sourceRowIndex = column('sourceRow');

      if (nameIndex == -1 || totalIndex == -1) {
        throw Exception(
          'Invalid inventory CSV. Required columns were not found.',
        );
      }

      String textValue(List<dynamic> row, int index) {
        if (index < 0 || index >= row.length) {
          return '';
        }

        return row[index].toString().trim();
      }

      int intValue(List<dynamic> row, int index) {
        if (index < 0 || index >= row.length) {
          return 0;
        }

        final value = row[index].toString().trim();

        if (value.isEmpty) {
          return 0;
        }

        // Handles both "8" and "8.0".
        return double.tryParse(value)?.toInt() ?? 0;
      }

      final items = <Map<String, dynamic>>[];
      final rejected = <Map<String, dynamic>>[];

      // Row 0 contains the column headers.
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];

        final name = textValue(row, nameIndex);

        if (name.isEmpty) {
          continue;
        }

        final totalQuantity = intValue(row, totalIndex);

        if (totalQuantity <= 0) {
          rejected.add({
            'row': i + 1,
            'name': name,
            'quantity': totalQuantity,
            'reason': 'Total quantity is 0 or missing',
          });

          continue;
        }

        final availableQuantity = availableIndex >= 0
            ? intValue(row, availableIndex)
            : totalQuantity;

        final outQuantity = outIndex >= 0 ? intValue(row, outIndex) : 0;

        final maintenanceQuantity = maintenanceIndex >= 0
            ? intValue(row, maintenanceIndex)
            : 0;

        final missingQuantity = missingIndex >= 0
            ? intValue(row, missingIndex)
            : 0;

        final category = textValue(row, categoryIndex);

        items.add({
          'name': name,
          'category': category.isEmpty ? 'Other' : category,

          'brand': '',
          'model': textValue(row, modelIndex),
          'assetCode': textValue(row, codeIndex),
          'description': textValue(row, descriptionIndex),

          'totalQuantity': totalQuantity,
          'availableQuantity': availableQuantity,
          'outQuantity': outQuantity,

          'damagedQuantity': 0,
          'maintenanceQuantity': maintenanceQuantity,
          'missingQuantity': missingQuantity,

          'site': textValue(row, siteIndex),
          'location': textValue(row, locationIndex),
          'remarks': textValue(row, remarksIndex),

          'condition': maintenanceQuantity > 0 ? 'Maintenance' : 'Good',

          'sourceRow': sourceRowIndex >= 0
              ? intValue(row, sourceRowIndex)
              : i + 1,

          'importSource': 'jitu-initial-inventory',
        });
      }

      if (items.isEmpty) {
        throw Exception('No valid inventory records were found.');
      }

      if (!mounted) return;

      setState(() {
        previewItems = items;
        rejectedItems = rejected;
        fileName = file.name;
        isReading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isReading = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> importItems() async {
    if (previewItems.isEmpty || isImporting) {
      return;
    }

    setState(() {
      isImporting = true;
      errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // Prevent accidental repeat of our initial inventory import.
      final existingImport = await firestore
          .collection('items')
          .where('importSource', isEqualTo: 'jitu-initial-inventory')
          .limit(1)
          .get();

      if (existingImport.docs.isNotEmpty) {
        throw Exception(
          'The initial Jitu Unggul inventory has already been imported.',
        );
      }

      // Firestore batches support up to 500 writes.
      // Our initial inventory is below that limit.
      final batch = firestore.batch();

      for (final item in previewItems) {
        final document = firestore.collection('items').doc();

        batch.set(document, {
          ...item,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'importedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${previewItems.length} items imported successfully.'),
        ),
      );

      Navigator.pop(context, true);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        isImporting = false;
        errorMessage = 'Firebase error: ${e.message ?? e.code}';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isImporting = false;
        errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Import Inventory',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inventory Import',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the cleaned Jitu Unggul CSV inventory file.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),

                FilledButton.icon(
                  onPressed: isReading || isImporting ? null : pickExcelFile,
                  icon: isReading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(
                    isReading ? 'READING FILE...' : 'SELECT CSV FILE',
                  ),
                ),

                if (fileName != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Selected: $fileName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],

                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ),
                ],

                if (previewItems.isNotEmpty) ...[
                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF0F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${previewItems.length + rejectedItems.length} inventory records found',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          '✓ ${previewItems.length} ready to import',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),

                        Text(
                          '⚠ ${rejectedItems.length} need review',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: rejectedItems.isEmpty
                                ? Colors.green
                                : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  if (rejectedItems.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${rejectedItems.length} ITEMS NEED REVIEW',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),

                          const SizedBox(height: 10),

                          ...rejectedItems.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '• ${item['name']} — '
                                '${item['reason']} '
                                '(CSV row ${item['row']})',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Preview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Expanded(
                    child: ListView.separated(
                      itemCount: previewItems.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = previewItems[index];

                        return ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(
                            item['name'].toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${item['site']} • '
                            '${item['location']}\n'
                            'Model: ${item['model']}',
                          ),
                          trailing: Text(
                            'Qty ${item['totalQuantity']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: isImporting ? null : importItems,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                      ),
                      icon: isImporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(
                        isImporting
                            ? 'IMPORTING...'
                            : 'IMPORT ${previewItems.length} ITEMS',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
