import 'dart:convert';

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:csv/csv.dart';

import 'package:file_saver/file_saver.dart';

import 'package:flutter/material.dart';

import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;

import 'package:printing/printing.dart';

class MovementHistoryPage extends StatefulWidget {
  final bool embedded;

  const MovementHistoryPage({super.key, this.embedded = false});

  @override
  State<MovementHistoryPage> createState() => _MovementHistoryPageState();
}

class _MovementHistoryPageState extends State<MovementHistoryPage> {
  bool isLoading = true;

  List<Map<String, dynamic>> movements = [];

  String searchQuery = '';

  String selectedFilter = 'ALL';

  DateTime? fromDate;

  DateTime? toDate;

  final List<String> filters = [
    'ALL',

    'OUT',

    'IN',

    'REPAIRED',

    'FOUND',

    'DAMAGED',
  ];

  @override
  void initState() {
    super.initState();

    loadMovements();
  }

  // ============================================================

  // LOAD MOVEMENTS

  // ============================================================

  Future<void> loadMovements() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('movements')
          .orderBy('createdAt', descending: true)
          .get();

      final loadedMovements = snapshot.docs.map((doc) {
        return <String, dynamic>{'id': doc.id, ...doc.data()};
      }).toList();

      if (!mounted) return;

      setState(() {
        movements = loadedMovements;

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load movement history: $e')),
      );
    }
  }

  // ============================================================

  // DISPLAY TYPE

  // ============================================================

  String getDisplayType(String type) {
    switch (type) {
      case 'OUT':
        return 'OUT';

      case 'IN':
        return 'IN';

      case 'MAINTENANCE_COMPLETED':
        return 'REPAIRED';

      case 'MISSING_FOUND':
        return 'FOUND';

      case 'DAMAGED_REPAIRED':
        return 'REPAIRED';

      case 'DAMAGED_TO_MAINTENANCE':
        return 'DAMAGED';

      default:
        return type.isEmpty ? 'UNKNOWN' : type;
    }
  }

  // ============================================================

  // MOVEMENT ICON

  // ============================================================

  IconData getMovementIcon(String type) {
    switch (type) {
      case 'OUT':
        return Icons.outbox_outlined;

      case 'IN':
        return Icons.move_to_inbox_outlined;

      case 'MAINTENANCE_COMPLETED':
      case 'DAMAGED_REPAIRED':
        return Icons.build_outlined;

      case 'MISSING_FOUND':
        return Icons.search_outlined;

      case 'DAMAGED_TO_MAINTENANCE':
        return Icons.report_problem_outlined;

      default:
        return Icons.history;
    }
  }

  // ============================================================

  // MOVEMENT COLOR

  // ============================================================

  Color getMovementColor(String type) {
    switch (type) {
      case 'OUT':
        return Colors.orange.shade700;

      case 'IN':
        return Colors.green.shade700;

      case 'MAINTENANCE_COMPLETED':
      case 'DAMAGED_REPAIRED':
        return Colors.blue.shade700;

      case 'MISSING_FOUND':
        return Colors.teal.shade700;

      case 'DAMAGED_TO_MAINTENANCE':
        return Colors.red.shade700;

      default:
        return Colors.grey.shade700;
    }
  }

  // ============================================================

  // FILTER MOVEMENTS

  // ============================================================

  bool matchesFilter(Map<String, dynamic> movement) {
    final String type = movement['type']?.toString() ?? '';

    final String displayType = getDisplayType(type);

    // TYPE FILTER

    if (selectedFilter != 'ALL') {
      if (selectedFilter == 'DAMAGED') {
        if (type != 'DAMAGED_TO_MAINTENANCE') {
          return false;
        }
      } else {
        if (displayType != selectedFilter) {
          return false;
        }
      }
    }

    // DATE FILTER

    final createdAt = movement['createdAt'];

    if (createdAt is Timestamp) {
      final movementDate = createdAt.toDate();

      if (fromDate != null) {
        final start = DateTime(fromDate!.year, fromDate!.month, fromDate!.day);

        if (movementDate.isBefore(start)) {
          return false;
        }
      }

      if (toDate != null) {
        final end = DateTime(
          toDate!.year,

          toDate!.month,

          toDate!.day,

          23,

          59,

          59,

          999,
        );

        if (movementDate.isAfter(end)) {
          return false;
        }
      }
    }

    // SEARCH FILTER

    if (searchQuery.trim().isEmpty) {
      return true;
    }

    final query = searchQuery.trim().toLowerCase();

    final itemName = movement['itemName']?.toString().toLowerCase() ?? '';

    final eventName = movement['eventName']?.toString().toLowerCase() ?? '';

    final handledBy = movement['handledBy']?.toString().toLowerCase() ?? '';

    final notes = movement['notes']?.toString().toLowerCase() ?? '';

    final searchableType = displayType.toLowerCase();

    return itemName.contains(query) ||
        eventName.contains(query) ||
        handledBy.contains(query) ||
        notes.contains(query) ||
        searchableType.contains(query);
  }

  // ============================================================

  // FORMAT FIRESTORE DATE

  // ============================================================

  String formatDate(dynamic value) {
    if (value is! Timestamp) {
      return '-';
    }

    final date = value.toDate();

    String twoDigits(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/'
        '${date.year} '
        '${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)}';
  }

  // ============================================================

  // FORMAT SELECTED DATE

  // ============================================================

  String formatSelectedDate(DateTime? date) {
    if (date == null) {
      return 'Select date';
    }

    String twoDigits(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/'
        '${date.year}';
  }

  // ============================================================

  // FROM DATE

  // ============================================================

  Future<void> selectFromDate() async {
    final selected = await showDatePicker(
      context: context,

      initialDate: fromDate ?? DateTime.now(),

      firstDate: DateTime(2025),

      lastDate: DateTime(2035),
    );

    if (selected == null) return;

    setState(() {
      fromDate = selected;

      if (toDate != null && toDate!.isBefore(selected)) {
        toDate = null;
      }
    });
  }

  // ============================================================

  // TO DATE

  // ============================================================

  Future<void> selectToDate() async {
    final selected = await showDatePicker(
      context: context,

      initialDate: toDate ?? fromDate ?? DateTime.now(),

      firstDate: fromDate ?? DateTime(2025),

      lastDate: DateTime(2035),
    );

    if (selected == null) return;

    setState(() {
      toDate = selected;
    });
  }

  // ============================================================

  // CLEAR DATE FILTER

  // ============================================================

  void clearDates() {
    setState(() {
      fromDate = null;

      toDate = null;
    });
  }

  // ============================================================

  // DETAIL ROW

  // ============================================================

  Widget buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          SizedBox(
            width: 115,

            child: Text(
              label,

              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  // ============================================================

  // MOVEMENT DETAILS

  // ============================================================

  void showMovementDetails(Map<String, dynamic> movement) {
    final String type = movement['type']?.toString() ?? '';

    final String displayType = getDisplayType(type);

    final String itemName = movement['itemName']?.toString() ?? 'Unknown Item';

    final int quantity = (movement['quantity'] as num?)?.toInt() ?? 0;

    final String handledBy = movement['handledBy']?.toString() ?? 'Unknown';

    final String eventName = movement['eventName']?.toString() ?? '';

    final String notes = movement['notes']?.toString() ?? '';

    final String fromLocation = movement['fromLocation']?.toString() ?? '';

    final String toLocation = movement['toLocation']?.toString() ?? '';

    showDialog(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(getMovementIcon(type), color: const Color(0xFF1E3A5F)),

              const SizedBox(width: 10),

              const Expanded(
                child: Text('Movement Details', overflow: TextOverflow.ellipsis),
              ),
            ],
          ),

          content: SizedBox(
            width: 480,

            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  buildDetailRow('Item', itemName),

                  buildDetailRow('Action', displayType),

                  buildDetailRow('Quantity', quantity.toString()),

                  if (eventName.isNotEmpty) buildDetailRow('Event', eventName),

                  buildDetailRow('Handled By', handledBy),

                  buildDetailRow(
                    'Date & Time',

                    formatDate(movement['createdAt']),
                  ),

                  if (fromLocation.isNotEmpty)
                    buildDetailRow('From', fromLocation),

                  if (toLocation.isNotEmpty) buildDetailRow('To', toLocation),

                  buildDetailRow('Notes', notes.isEmpty ? '-' : notes),
                ],
              ),
            ),
          ),

          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },

              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================

  // MOVEMENT CARD

  // ============================================================

  // Responsive movement card. Layout changes only; Firestore data is unchanged.
  Widget buildMovementCard(Map<String, dynamic> movement) {
    final String type = movement['type']?.toString() ?? '';
    final String displayType = getDisplayType(type);
    final String itemName = movement['itemName']?.toString() ?? 'Unknown Item';
    final int quantity = (movement['quantity'] as num?)?.toInt() ?? 0;
    final String handledBy = movement['handledBy']?.toString() ?? 'Unknown';
    final String eventName = movement['eventName']?.toString() ?? '';
    final String notes = movement['notes']?.toString() ?? '';
    final String description = eventName.isNotEmpty
        ? 'Event: $eventName'
        : notes.isNotEmpty
            ? notes
            : 'No additional details';
    final Color movementColor = getMovementColor(type);

    final Widget statusChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: movementColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayType,
        style: TextStyle(
          color: movementColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );

    final Widget itemIcon = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        getMovementIcon(type),
        color: const Color(0xFF1E3A5F),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 630;
        return Card(
          margin: EdgeInsets.zero,
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            onTap: () => showMovementDetails(movement),
            child: Padding(
              padding: EdgeInsets.all(compact ? 14 : 18),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            itemIcon,
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '$itemName × $quantity',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                softWrap: true,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.chevron_right, color: Colors.grey.shade500),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(description),
                        const SizedBox(height: 4),
                        Text(
                          'Handled by: $handledBy',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Text(
                              formatDate(movement['createdAt']),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            statusChip,
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        itemIcon,
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$itemName × $quantity',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(description),
                              const SizedBox(height: 4),
                              Text(
                                'Handled by: $handledBy',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatDate(movement['createdAt']),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        statusChip,
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right, color: Colors.grey.shade500),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================

  // EXPORT CSV

  // ============================================================

  Future<void> exportCsv(List<Map<String, dynamic>> filteredMovements) async {
    if (filteredMovements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There are no movement records to export.'),
        ),
      );

      return;
    }

    try {
      final List<List<dynamic>> rows = [
        [
          'Date & Time',

          'Action',

          'Item',

          'Quantity',

          'Event',

          'Handled By',

          'Notes',
        ],
      ];

      for (final movement in filteredMovements) {
        final type = movement['type']?.toString() ?? '';

        final itemName = movement['itemName']?.toString() ?? '';

        final quantity = (movement['quantity'] as num?)?.toInt() ?? 0;

        final eventName = movement['eventName']?.toString() ?? '';

        final handledBy = movement['handledBy']?.toString() ?? '';

        final notes = movement['notes']?.toString() ?? '';

        rows.add([
          formatDate(movement['createdAt']),

          getDisplayType(type),

          itemName,

          quantity,

          eventName,

          handledBy,

          notes,
        ]);
      }

      final csvString = csv.encode(rows);

      // UTF-8 BOM helps Microsoft Excel correctly detect UTF-8.

      final Uint8List bytes = Uint8List.fromList(
        utf8.encode('\uFEFF$csvString'),
      );

      final now = DateTime.now();

      String twoDigits(int number) {
        return number.toString().padLeft(2, '0');
      }

      final fileName =
          'jitu_unggul_movement_history_'
          '${now.year}'
          '${twoDigits(now.month)}'
          '${twoDigits(now.day)}_'
          '${twoDigits(now.hour)}'
          '${twoDigits(now.minute)}';

      await FileSaver.instance.saveFile(
        name: fileName,

        bytes: bytes,

        fileExtension: 'csv',

        mimeType: MimeType.csv,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${filteredMovements.length} movement records exported successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to export CSV: $e')));
    }
  }

  // ============================================================

  // EXPORT PDF

  // ============================================================

  Future<void> exportPdf(List<Map<String, dynamic>> filteredMovements) async {
    if (filteredMovements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There are no movement records to export.'),
        ),
      );

      return;
    }

    try {
      final pdf = pw.Document();

      final now = DateTime.now();

      String twoDigits(int number) {
        return number.toString().padLeft(2, '0');
      }

      final generatedDate =
          '${twoDigits(now.day)}/'
          '${twoDigits(now.month)}/'
          '${now.year} '
          '${twoDigits(now.hour)}:'
          '${twoDigits(now.minute)}';

      final dateFilter =
          '${fromDate == null ? 'Any date' : formatSelectedDate(fromDate)}'
          ' - '
          '${toDate == null ? 'Any date' : formatSelectedDate(toDate)}';

      final searchFilter = searchQuery.trim().isEmpty
          ? 'None'
          : searchQuery.trim();

      int totalQuantity = 0;

      for (final movement in filteredMovements) {
        totalQuantity += (movement['quantity'] as num?)?.toInt() ?? 0;
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,

          margin: const pw.EdgeInsets.all(28),

          header: (context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 15),

              padding: const pw.EdgeInsets.only(bottom: 10),

              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1)),
              ),

              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,

                children: [
                  pw.Text(
                    'JITU UNGGUL',

                    style: pw.TextStyle(
                      fontSize: 18,

                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                  pw.Text(
                    'Asset Management System',

                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            );
          },

          footer: (context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 10),

              alignment: pw.Alignment.centerRight,

              child: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',

                style: const pw.TextStyle(
                  fontSize: 9,

                  color: PdfColors.grey700,
                ),
              ),
            );
          },

          build: (context) {
            return [
              pw.Text(
                'ASSET MOVEMENT REPORT',

                style: pw.TextStyle(
                  fontSize: 24,

                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 5),

              pw.Text(
                'Generated: $generatedDate',

                style: const pw.TextStyle(
                  fontSize: 10,

                  color: PdfColors.grey700,
                ),
              ),

              pw.SizedBox(height: 20),

              // FILTER INFORMATION
              pw.Container(
                padding: const pw.EdgeInsets.all(12),

                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,

                  borderRadius: pw.BorderRadius.circular(5),
                ),

                child: pw.Row(
                  children: [
                    pw.Expanded(child: pw.Text('Action: $selectedFilter')),

                    pw.Expanded(child: pw.Text('Date: $dateFilter')),

                    pw.Expanded(child: pw.Text('Search: $searchFilter')),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // SUMMARY
              pw.Text(
                'SUMMARY',

                style: pw.TextStyle(
                  fontSize: 13,

                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 8),

              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),

                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                      ),

                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,

                        children: [
                          pw.Text(
                            'Movement Records',

                            style: const pw.TextStyle(
                              fontSize: 9,

                              color: PdfColors.grey700,
                            ),
                          ),

                          pw.SizedBox(height: 4),

                          pw.Text(
                            '${filteredMovements.length}',

                            style: pw.TextStyle(
                              fontSize: 18,

                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 10),

                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),

                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                      ),

                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,

                        children: [
                          pw.Text(
                            'Total Quantity',

                            style: const pw.TextStyle(
                              fontSize: 9,

                              color: PdfColors.grey700,
                            ),
                          ),

                          pw.SizedBox(height: 4),

                          pw.Text(
                            '$totalQuantity',

                            style: pw.TextStyle(
                              fontSize: 18,

                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // MOVEMENT TABLE
              pw.Text(
                'MOVEMENT RECORDS',

                style: pw.TextStyle(
                  fontSize: 13,

                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 8),

              pw.TableHelper.fromTextArray(
                headers: const [
                  'Date & Time',

                  'Action',

                  'Item',

                  'Qty',

                  'Event',

                  'Handled By',

                  'Notes',
                ],

                data: filteredMovements.map((movement) {
                  final type = movement['type']?.toString() ?? '';

                  return [
                    formatDate(movement['createdAt']),

                    getDisplayType(type),

                    movement['itemName']?.toString() ?? '',

                    ((movement['quantity'] as num?)?.toInt() ?? 0).toString(),

                    movement['eventName']?.toString() ?? '',

                    movement['handledBy']?.toString() ?? '',

                    movement['notes']?.toString() ?? '',
                  ];
                }).toList(),

                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,

                  fontSize: 9,
                ),

                cellStyle: const pw.TextStyle(fontSize: 8),

                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),

                cellAlignment: pw.Alignment.centerLeft,

                cellPadding: const pw.EdgeInsets.all(5),

                columnWidths: {
                  0: const pw.FlexColumnWidth(1.3),

                  1: const pw.FlexColumnWidth(0.9),

                  2: const pw.FlexColumnWidth(1.5),

                  3: const pw.FlexColumnWidth(0.5),

                  4: const pw.FlexColumnWidth(1.5),

                  5: const pw.FlexColumnWidth(1.2),

                  6: const pw.FlexColumnWidth(2),
                },
              ),

              pw.SizedBox(height: 20),

              pw.Text(
                'End of report',

                style: const pw.TextStyle(
                  fontSize: 8,

                  color: PdfColors.grey600,
                ),
              ),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();

      await Printing.sharePdf(
        bytes: pdfBytes,

        filename:
            'jitu_unggul_movement_report_'
            '${now.year}'
            '${twoDigits(now.month)}'
            '${twoDigits(now.day)}.pdf',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${filteredMovements.length} movement records exported to PDF.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to export PDF: $e')));
    }
  }

  // ============================================================

  // BUILD

  // ============================================================

  // ============================================================
  // RESPONSIVE FILTER / EXPORT CONTROLS
  // ============================================================

  Widget _dateButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.calendar_month_outlined, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _clearDateButton({bool stretch = false}) {
    return SizedBox(
      width: stretch ? double.infinity : null,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: fromDate == null && toDate == null ? null : clearDates,
        icon: const Icon(Icons.clear, size: 18),
        label: const Text('CLEAR'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _dateFilters(double width) {
    final from = _dateButton(
      label: fromDate == null ? 'From Date' : formatSelectedDate(fromDate),
      onPressed: selectFromDate,
    );
    final to = _dateButton(
      label: toDate == null ? 'To Date' : formatSelectedDate(toDate),
      onPressed: selectToDate,
    );

    if (width < 340) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          from,
          const SizedBox(height: 8),
          to,
          const SizedBox(height: 8),
          _clearDateButton(stretch: true),
        ],
      );
    }

    if (width < 780) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: from),
              const SizedBox(width: 10),
              Expanded(child: to),
            ],
          ),
          const SizedBox(height: 10),
          _clearDateButton(stretch: true),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: from),
        const SizedBox(width: 12),
        Expanded(child: to),
        const SizedBox(width: 12),
        _clearDateButton(),
      ],
    );
  }

  Widget _exportButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool small,
  }) {
    return SizedBox(
      height: 46,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: small ? 17 : 19),
        label: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: small ? 12 : 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: small ? 9 : 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _summaryAndExports(
    double width,
    List<Map<String, dynamic>> filteredMovements,
  ) {
    final canExport = filteredMovements.isNotEmpty;
    final dateRange = fromDate == null && toDate == null
        ? null
        : '${fromDate == null ? 'Any date' : formatSelectedDate(fromDate)}'
          ' → '
          '${toDate == null ? 'Any date' : formatSelectedDate(toDate)}';

    final recordCount = Text(
      '${filteredMovements.length} movement record'
      '${filteredMovements.length == 1 ? '' : 's'}',
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );

    final small = width < 360;
    final csvButton = _exportButton(
      label: small ? 'CSV' : 'EXPORT CSV',
      icon: Icons.download_outlined,
      onPressed: canExport ? () => exportCsv(filteredMovements) : null,
      small: width < 420,
    );
    final pdfButton = _exportButton(
      label: small ? 'PDF' : 'EXPORT PDF',
      icon: Icons.picture_as_pdf_outlined,
      onPressed: canExport ? () => exportPdf(filteredMovements) : null,
      small: width < 420,
    );

    if (width < 900) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          recordCount,
          if (dateRange != null) ...[
            const SizedBox(height: 4),
            Text(
              dateRange,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: csvButton),
              const SizedBox(width: 10),
              Expanded(child: pdfButton),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        recordCount,
        if (dateRange != null) ...[
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              dateRange,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ],
        const Spacer(),
        csvButton,
        const SizedBox(width: 10),
        pdfButton,
      ],
    );
  }

  // ============================================================
  // RESPONSIVE PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final filteredMovements = movements.where(matchesFilter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      // Keep embedded mode working with your existing app navigation.
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              title: const Text(
                'Movement History',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: isLoading ? null : loadMovements,
                  icon: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 10),
              ],
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;
          final sidePadding = isMobile ? 16.0 : 24.0;
          final contentWidth =
              (constraints.maxWidth > 1120 ? 1120.0 : constraints.maxWidth) -
              sidePadding * 2;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: sidePadding),
                child: RefreshIndicator(
                  onRefresh: loadMovements,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 18),
                            Text(
                              'Asset Movement History',
                              style: TextStyle(
                                fontSize: isMobile ? 22 : 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'View and audit all equipment movements.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 22),
                            TextField(
                              onChanged: (value) =>
                                  setState(() => searchQuery = value),
                              decoration: InputDecoration(
                                hintText: isMobile
                                    ? 'Search movements...'
                                    : 'Search item, event, staff, action or notes...',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Only the action filters scroll horizontally.
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: filters.map((filter) {
                                  final selected = selectedFilter == filter;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(filter),
                                      selected: selected,
                                      onSelected: (_) => setState(
                                        () => selectedFilter = filter,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _dateFilters(contentWidth),
                            const SizedBox(height: 20),
                            _summaryAndExports(
                              contentWidth,
                              filteredMovements,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      if (isLoading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (filteredMovements.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.history_outlined,
                                    size: 60,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No movement records found',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Try changing your search, type or date filter.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: buildMovementCard(filteredMovements[index]),
                            ),
                            childCount: filteredMovements.length,
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
