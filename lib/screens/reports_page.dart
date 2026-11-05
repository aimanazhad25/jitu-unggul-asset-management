import 'dart:convert';

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:csv/csv.dart';

import 'package:file_saver/file_saver.dart';

import 'package:flutter/material.dart';

import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;

import 'package:printing/printing.dart';

class ReportsPage extends StatefulWidget {
  final String generatedBy;
  final bool embedded;

  const ReportsPage({
    super.key,
    required this.generatedBy,
    this.embedded = false,
  });

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const primary = Color(0xFF1E3A5F);

  bool loading = true;

  String? error;

  String reportType = 'Inventory Report';

  DateTime? fromDate;

  DateTime? toDate;

  List<Map<String, dynamic>> items = [];

  List<Map<String, dynamic>> movements = [];

  List<Map<String, dynamic>> events = [];

  final reportTypes = const [
    'Inventory Report',

    'Movement Report',

    'Event Report',

    'Asset Condition Report',
  ];

  @override
  void initState() {
    super.initState();

    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;

      error = null;
    });

    try {
      final db = FirebaseFirestore.instance;

      final result = await Future.wait([
        db.collection('items').get(),

        db.collection('movements').get(),

        db.collection('events').get(),
      ]);

      final loadedItems = result[0].docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList();

      final loadedMovements = result[1].docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList();

      final loadedEvents = result[2].docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList();

      loadedMovements.sort(
        (a, b) => _date(b['createdAt']).compareTo(_date(a['createdAt'])),
      );

      if (!mounted) return;

      setState(() {
        items = loadedItems;

        movements = loadedMovements;

        events = loadedEvents;

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;

        error = e.toString();
      });
    }
  }

  DateTime _date(dynamic value) {
    if (value is Timestamp) return value.toDate();

    if (value is DateTime) return value;

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool inRange(dynamic value) {
    final d = _date(value);

    if (d.millisecondsSinceEpoch == 0)
      return fromDate == null && toDate == null;

    if (fromDate != null) {
      final start = DateTime(fromDate!.year, fromDate!.month, fromDate!.day);

      if (d.isBefore(start)) return false;
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

      if (d.isAfter(end)) return false;
    }

    return true;
  }

  int sum(String field) =>
      items.fold(0, (s, x) => s + ((x[field] as num?)?.toInt() ?? 0));

  int get total => sum('totalQuantity');

  int get available => sum('availableQuantity');

  int get out => sum('outQuantity');

  int get maintenance => sum('maintenanceQuantity');

  int get damaged => sum('damagedQuantity');

  int get missing => sum('missingQuantity');

  String two(int n) => n.toString().padLeft(2, '0');

  String fmt(dynamic value) {
    if (value is! Timestamp && value is! DateTime) return '-';

    final d = _date(value);

    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  String fmtSelected(DateTime? d) =>
      d == null ? 'Any date' : '${two(d.day)}/${two(d.month)}/${d.year}';

  String displayType(String type) {
    switch (type) {
      case 'MAINTENANCE_COMPLETED':
        return 'REPAIRED';

      case 'MISSING_FOUND':
        return 'FOUND';

      case 'DAMAGED_REPAIRED':
        return 'DAMAGED - REPAIRED';

      case 'DAMAGED_TO_MAINTENANCE':
        return 'DAMAGED - TO MAINTENANCE';

      default:
        return type.isEmpty ? 'UNKNOWN' : type;
    }
  }

  dynamic eventDate(Map<String, dynamic> e) =>
      e['eventDate'] ?? e['date'] ?? e['startDate'] ?? e['createdAt'];

  List<String> get headers {
    switch (reportType) {
      case 'Movement Report':
        return [
          'Date & Time',

          'Action',

          'Item',

          'Quantity',

          'Event',

          'Handled By',

          'Notes',
        ];

      case 'Event Report':
        return [
          'Event',

          'Date',

          'Location',

          'Client Company',

          'Contact Person',

          'Phone',
        ];

      case 'Asset Condition Report':
        return [
          'Item',

          'Category',

          'Available',

          'Maintenance',

          'Damaged',

          'Missing',
        ];

      default:
        return [
          'Item',

          'Category',

          'Location',

          'Total',

          'Available',

          'Out',

          'Maintenance',

          'Damaged',

          'Missing',
        ];
    }
  }

  List<List<dynamic>> get rows {
    switch (reportType) {
      case 'Movement Report':
        return movements
            .where((m) => inRange(m['createdAt']))
            .map(
              (m) => [
                fmt(m['createdAt']),

                displayType(m['type']?.toString() ?? ''),

                m['itemName']?.toString() ?? '',

                (m['quantity'] as num?)?.toInt() ?? 0,

                m['eventName']?.toString() ?? '',

                m['handledBy']?.toString() ?? '',

                m['notes']?.toString() ?? '',
              ],
            )
            .toList();

      case 'Event Report':
        return events
            .where(
              (e) => fromDate == null && toDate == null
                  ? true
                  : inRange(eventDate(e)),
            )
            .map(
              (e) => [
                e['name']?.toString() ?? e['eventName']?.toString() ?? '',

                fmt(eventDate(e)),

                e['location']?.toString() ?? '',

                e['clientCompany']?.toString() ?? '',

                e['clientContactPerson']?.toString() ?? '',

                e['clientPhone']?.toString() ?? '',
              ],
            )
            .toList();

      case 'Asset Condition Report':
        return items
            .map(
              (x) => [
                x['name']?.toString() ?? x['itemName']?.toString() ?? '',

                x['category']?.toString() ?? '',

                (x['availableQuantity'] as num?)?.toInt() ?? 0,

                (x['maintenanceQuantity'] as num?)?.toInt() ?? 0,

                (x['damagedQuantity'] as num?)?.toInt() ?? 0,

                (x['missingQuantity'] as num?)?.toInt() ?? 0,
              ],
            )
            .toList();

      default:
        return items
            .map(
              (x) => [
                x['name']?.toString() ?? x['itemName']?.toString() ?? '',

                x['category']?.toString() ?? '',

                x['location']?.toString() ?? '',

                (x['totalQuantity'] as num?)?.toInt() ?? 0,

                (x['availableQuantity'] as num?)?.toInt() ?? 0,

                (x['outQuantity'] as num?)?.toInt() ?? 0,

                (x['maintenanceQuantity'] as num?)?.toInt() ?? 0,

                (x['damagedQuantity'] as num?)?.toInt() ?? 0,

                (x['missingQuantity'] as num?)?.toInt() ?? 0,
              ],
            )
            .toList();
    }
  }

  Future<void> pickFrom() async {
    final d = await showDatePicker(
      context: context,

      initialDate: fromDate ?? DateTime.now(),

      firstDate: DateTime(2025),

      lastDate: DateTime(2035),
    );

    if (d != null && mounted)
      setState(() {
        fromDate = d;

        if (toDate != null && toDate!.isBefore(d)) toDate = null;
      });
  }

  Future<void> pickTo() async {
    final d = await showDatePicker(
      context: context,

      initialDate: toDate ?? fromDate ?? DateTime.now(),

      firstDate: fromDate ?? DateTime(2025),

      lastDate: DateTime(2035),
    );

    if (d != null && mounted) setState(() => toDate = d);
  }

  String get prefix =>
      reportType.toLowerCase().replaceAll(' report', '').replaceAll(' ', '_');

  Future<void> exportCsv() async {
    if (rows.isEmpty) return message('There are no records to export.');

    try {
      final data = <List<dynamic>>[
        ['JITU UNGGUL - $reportType'],

        ['Generated By', widget.generatedBy],

        ['From Date', fmtSelected(fromDate)],

        ['To Date', fmtSelected(toDate)],

        [],

        headers,

        ...rows,
      ];

      final csvString = csv.encode(data);

      final bytes = Uint8List.fromList(utf8.encode('\uFEFF$csvString'));

      final now = DateTime.now();

      await FileSaver.instance.saveFile(
        name:
            'jitu_unggul_${prefix}_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}',

        bytes: bytes,

        fileExtension: 'csv',

        mimeType: MimeType.csv,
      );

      if (mounted) message('${rows.length} records exported successfully.');
    } catch (e) {
      if (mounted) message('Unable to export CSV: $e');
    }
  }

  Future<void> exportPdf() async {
    if (rows.isEmpty) return message('There are no records to export.');

    try {
      final pdf = pw.Document();

      final now = DateTime.now();

      final generated =
          '${two(now.day)}/${two(now.month)}/${now.year} ${two(now.hour)}:${two(now.minute)}';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,

          margin: const pw.EdgeInsets.all(28),

          header: (_) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),

            padding: const pw.EdgeInsets.only(bottom: 8),

            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey400),
              ),
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
          ),

          footer: (c) => pw.Align(
            alignment: pw.Alignment.centerRight,

            child: pw.Text(
              'Page ${c.pageNumber} of ${c.pagesCount}',

              style: const pw.TextStyle(fontSize: 9),
            ),
          ),

          build: (_) => [
            pw.Text(
              reportType.toUpperCase(),

              style: pw.TextStyle(fontSize: 23, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 5),

            pw.Text(
              'Generated: $generated  |  Generated by: ${widget.generatedBy}',

              style: const pw.TextStyle(fontSize: 10),
            ),

            pw.SizedBox(height: 10),

            pw.Text(
              'From: ${fmtSelected(fromDate)}    To: ${fmtSelected(toDate)}    Records: ${rows.length}',
            ),

            pw.SizedBox(height: 12),

            pw.Wrap(
              spacing: 7,

              runSpacing: 7,

              children: [
                pdfBox('Total', total),

                pdfBox('Available', available),

                pdfBox('Out', out),

                pdfBox('Maintenance', maintenance),

                pdfBox('Damaged', damaged),

                pdfBox('Missing', missing),
              ],
            ),

            pw.SizedBox(height: 15),

            pw.TableHelper.fromTextArray(
              headers: headers,

              data: rows
                  .map((r) => r.map((x) => x.toString()).toList())
                  .toList(),

              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,

                fontSize: 8,
              ),

              cellStyle: const pw.TextStyle(fontSize: 7),

              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),

              cellPadding: const pw.EdgeInsets.all(4),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),

        filename:
            'jitu_unggul_${prefix}_${now.year}${two(now.month)}${two(now.day)}.pdf',
      );

      if (mounted) message('${rows.length} records exported to PDF.');
    } catch (e) {
      if (mounted) message('Unable to export PDF: $e');
    }
  }

  pw.Widget pdfBox(String label, int value) => pw.Container(
    width: 105,

    padding: const pw.EdgeInsets.all(8),

    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400),
    ),

    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,

      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),

        pw.SizedBox(height: 3),

        pw.Text(
          '$value',

          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Widget stat(String label, int value, IconData icon) => Container(
    width: 190,

    padding: const EdgeInsets.all(18),

    decoration: BoxDecoration(
      color: Colors.white,

      borderRadius: BorderRadius.circular(14),

      border: Border.all(color: Colors.grey.shade200),
    ),

    child: Row(
      children: [
        Container(
          width: 46,

          height: 46,

          decoration: BoxDecoration(
            color: const Color(0xFFEAF0F7),

            borderRadius: BorderRadius.circular(10),
          ),

          child: Icon(icon, color: primary),
        ),

        const SizedBox(width: 12),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              '$value',

              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            Text(
              label,

              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),

      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: Colors.white,

              title: const Text(
                'Reports & Analytics',

                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              actions: [
                IconButton(
                  onPressed: loading ? null : loadData,

                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Icon(Icons.error_outline, size: 55, color: Colors.red),

                  const SizedBox(height: 10),

                  const Text(
                    'Unable to load reports',

                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Text(error!),

                  const SizedBox(height: 14),

                  FilledButton(
                    onPressed: loadData,

                    child: const Text('TRY AGAIN'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    'JITU UNGGUL Reports',

                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Review inventory status and generate management reports.',

                    style: TextStyle(color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 22),

                  Wrap(
                    spacing: 12,

                    runSpacing: 12,

                    children: [
                      stat('Total Items', total, Icons.inventory_2_outlined),

                      stat('Available', available, Icons.check_circle_outline),

                      stat('Items Out', out, Icons.outbox_outlined),

                      stat('Maintenance', maintenance, Icons.build_outlined),

                      stat('Damaged', damaged, Icons.report_problem_outlined),

                      stat('Missing', missing, Icons.search_off_outlined),
                    ],
                  ),

                  const SizedBox(height: 25),

                  Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(20),

                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius: BorderRadius.circular(14),

                      border: Border.all(color: Colors.grey.shade200),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'Generate Report',

                          style: TextStyle(
                            fontSize: 18,

                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 15),

                        DropdownButtonFormField<String>(
                          initialValue: reportType,

                          decoration: const InputDecoration(
                            labelText: 'Report Type',

                            border: OutlineInputBorder(),
                          ),

                          items: reportTypes
                              .map(
                                (x) =>
                                    DropdownMenuItem(value: x, child: Text(x)),
                              )
                              .toList(),

                          onChanged: (x) {
                            if (x != null) setState(() => reportType = x);
                          },
                        ),

                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 10,

                          runSpacing: 10,

                          children: [
                            OutlinedButton.icon(
                              onPressed: pickFrom,

                              icon: const Icon(Icons.calendar_month),

                              label: Text(
                                fromDate == null
                                    ? 'From Date'
                                    : fmtSelected(fromDate),
                              ),
                            ),

                            OutlinedButton.icon(
                              onPressed: pickTo,

                              icon: const Icon(Icons.calendar_month),

                              label: Text(
                                toDate == null
                                    ? 'To Date'
                                    : fmtSelected(toDate),
                              ),
                            ),

                            OutlinedButton.icon(
                              onPressed: fromDate == null && toDate == null
                                  ? null
                                  : () => setState(() {
                                      fromDate = null;

                                      toDate = null;
                                    }),

                              icon: const Icon(Icons.clear),

                              label: const Text('CLEAR'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 15),

                        Wrap(
                          spacing: 10,

                          children: [
                            FilledButton.icon(
                              onPressed: rows.isEmpty ? null : exportCsv,

                              icon: const Icon(Icons.download),

                              label: const Text('EXPORT CSV'),

                              style: FilledButton.styleFrom(
                                backgroundColor: primary,
                              ),
                            ),

                            FilledButton.icon(
                              onPressed: rows.isEmpty ? null : exportPdf,

                              icon: const Icon(Icons.picture_as_pdf),

                              label: const Text('EXPORT PDF'),

                              style: FilledButton.styleFrom(
                                backgroundColor: primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(20),

                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius: BorderRadius.circular(14),

                      border: Border.all(color: Colors.grey.shade200),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          'Report Preview — ${rows.length} records',

                          style: const TextStyle(
                            fontSize: 18,

                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        if (rows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(25),

                            child: Center(
                              child: Text('No records match this report.'),
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,

                            child: DataTable(
                              columns: headers
                                  .map(
                                    (h) => DataColumn(
                                      label: Text(
                                        h,

                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),

                              rows: rows
                                  .take(8)
                                  .map(
                                    (r) => DataRow(
                                      cells: r
                                          .map(
                                            (x) => DataCell(
                                              SizedBox(
                                                width: 120,

                                                child: Text(
                                                  x.toString(),

                                                  maxLines: 2,

                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),

                        if (rows.length > 8)
                          Text(
                            'Previewing first 8 of ${rows.length} records.',

                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
