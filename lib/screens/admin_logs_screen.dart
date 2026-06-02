import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedAction;
  DateTime? _selectedDate;
  
  final List<String> _actions = [
    "LOGIN", "LOGOUT", "DASHBOARD_REFRESH", "ADD_FARMER", "EDIT_FARMER", 
    "DELETE_FARMER", "CREATE_BILL", "EDIT_BILL", "DELETE_BILL", 
    "PAYMENT_ADDED", "WHATSAPP_BILL_SHARE_PDF", "WHATSAPP_BILL_SHARE_TEXT"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Audit Logs", style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download),
            onPressed: _exportLogsToPdf,
            tooltip: "Export to PDF",
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getLogsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final logs = snapshot.data!.docs;
                if (logs.isEmpty) return const Center(child: Text("No logs found"));

                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index].data() as Map<String, dynamic>;
                    return _buildLogTile(log);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: _selectedDate == null ? "Date" : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                  onTap: _selectDate,
                  isSelected: _selectedDate != null,
                  onClear: () => setState(() => _selectedDate = null),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: _selectedAction ?? "Action",
                  onTap: _selectAction,
                  isSelected: _selectedAction != null,
                  onClear: () => setState(() => _selectedAction = null),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required VoidCallback onTap, bool isSelected = false, VoidCallback? onClear}) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      onDeleted: isSelected ? onClear : null,
      deleteIcon: const Icon(Icons.close, size: 14),
    );
  }

  Stream<QuerySnapshot> _getLogsStream() {
    Query query = _firestore.collection('audit_logs').orderBy('createdAt', descending: true);
    
    if (_selectedAction != null) {
      query = query.where('action', isEqualTo: _selectedAction);
    }
    
    if (_selectedDate != null) {
      final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                   .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay));
    }

    return query.snapshots();
  }

  Widget _buildLogTile(Map<String, dynamic> log) {
    final DateTime? date = (log['createdAt'] as Timestamp?)?.toDate();
    final String timeStr = date != null ? DateFormat('dd/MM/yy HH:mm').format(date) : "N/A";
    final bool isSuccess = log['status'] == 'success';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: Icon(
          _getIconForAction(log['action']),
          color: isSuccess ? Colors.green : Colors.red,
        ),
        title: Text(
          log['action'] ?? "UNKNOWN",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          "${log['userEmail']} • $timeStr",
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Icon(
          isSuccess ? Icons.check_circle : Icons.error,
          color: isSuccess ? Colors.green : Colors.red,
          size: 16,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow("User", "${log['userName']} (${log['userId']})"),
                _buildDetailRow("Screen", log['screen'] ?? "N/A"),
                _buildDetailRow("Device", log['deviceInfo'] ?? "N/A"),
                _buildDetailRow("App Version", log['appVersion'] ?? "N/A"),
                if (!isSuccess && log['errorMessage'].toString().isNotEmpty)
                  _buildDetailRow("Error", log['errorMessage'], color: Colors.red),
                if (log['oldData'] != null)
                  _buildDataSection("Old Data", log['oldData']),
                if (log['newData'] != null)
                  _buildDataSection("New Data", log['newData']),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: color))),
        ],
      ),
    );
  }

  Widget _buildDataSection(String title, dynamic data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            const JsonEncoder.withIndent('  ').convert(data),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
          ),
        ),
      ],
    );
  }

  IconData _getIconForAction(String? action) {
    switch (action) {
      case "LOGIN": return LucideIcons.logIn;
      case "LOGOUT": return LucideIcons.logOut;
      case "CREATE_BILL": return LucideIcons.filePlus;
      case "EDIT_BILL": return LucideIcons.fileEdit;
      case "DELETE_BILL": return LucideIcons.fileX;
      case "ADD_FARMER": return LucideIcons.userPlus;
      case "WHATSAPP_BILL_SHARE_PDF":
      case "WHATSAPP_BILL_SHARE_TEXT": return LucideIcons.share2;
      default: return LucideIcons.activity;
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectAction() async {
    final String? picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Select Action"),
        children: _actions.map((a) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, a),
          child: Text(a),
        )).toList(),
      ),
    );
    if (picked != null) setState(() => _selectedAction = picked);
  }

  Future<void> _exportLogsToPdf() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final querySnapshot = await _getLogsStream().first;
      final logs = querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      final doc = pw.Document();
      final font = await PdfGoogleFonts.poppinsRegular();
      final boldFont = await PdfGoogleFonts.poppinsBold();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) => pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Farmite VEGETABLES - AUDIT LOGS", style: pw.TextStyle(font: boldFont, fontSize: 18, color: PdfColors.blue)),
                  pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 10),
            ],
          ),
          build: (pw.Context context) {
            return [
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2), // Timestamp
                  1: const pw.FlexColumnWidth(2), // User
                  2: const pw.FlexColumnWidth(2), // Action
                  3: const pw.FlexColumnWidth(2), // Screen
                  4: const pw.FlexColumnWidth(1), // Status
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildTableCell("Date & Time", boldFont, isHeader: true),
                      _buildTableCell("User", boldFont, isHeader: true),
                      _buildTableCell("Action", boldFont, isHeader: true),
                      _buildTableCell("Page", boldFont, isHeader: true),
                      _buildTableCell("Status", boldFont, isHeader: true),
                    ],
                  ),
                  ...logs.map((log) {
                    final DateTime? date = (log['createdAt'] as Timestamp?)?.toDate();
                    return pw.TableRow(
                      children: [
                        _buildTableCell(date != null ? DateFormat('dd/MM/yy HH:mm').format(date) : "N/A", font),
                        _buildTableCell(log['userName'] ?? log['userEmail'] ?? "N/A", font),
                        _buildTableCell(log['action'] ?? "N/A", font),
                        _buildTableCell(log['screen'] ?? "N/A", font),
                        _buildTableCell(log['status'] ?? "N/A", font, color: log['status'] == 'success' ? PdfColors.green : PdfColors.red),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      final pdfBytes = await doc.save();
      final fileName = "audit_logs_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.pdf";
      
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/$fileName').create();
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        Navigator.pop(context); // Remove loading
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, name: fileName)],
          subject: 'Audit Logs Export',
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Remove loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error exporting PDF: $e")));
      }
    }
  }

  pw.Widget _buildTableCell(String text, pw.Font font, {bool isHeader = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 10 : 8,
          color: color,
        ),
      ),
    );
  }
}
