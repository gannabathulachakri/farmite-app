import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/types.dart';
import '../providers/farmitre_provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../l10n/app_localizations.dart';
import '../services/audit_log_service.dart';
import 'constants.dart';

enum PdfLanguageMode { english, telugu }

class BillHeaderData {
  final String businessName;
  final String proprietorName;
  final String phoneNumber;

  BillHeaderData({
    required this.businessName,
    required this.proprietorName,
    required this.phoneNumber,
  });
}

class BillUtils {
  static final Map<String, Map<String, String>> _labels = {
    "companyName": {
      "en": "Farmite VEGETABLES & ONIONS - BHIMAVARAM",
      "te": "Farmite కూరగాయలు & ఉల్లిపాయలు - భీమవరం"
    },
    "proprietor": {
      "en": "Prop. Satyababu. 9989072773",
      "te": "ప్రొ. సత్యబాబు. 9989072773"
    },
    "bags": {"en": "Bgs", "te": "బస్తాలు"},
    "expenditure": {"en": "Expenditure", "te": "ఖర్చులు"},
    "totalAmount": {"en": "Total Amount", "te": "మొత్తం అమ్మకం"},
    "kirayee": {"en": "KIRAYEE :", "te": "కిరాయి :"},
    "kooli": {"en": "KOOLI :", "te": "కూలి :"},
    "commission": {"en": "COMMISSN:", "te": "కమిషన్ :"},
    "total": {"en": "Total :", "te": "మొత్తం :"},
    "sri": {"en": "Sri", "te": "శ్రీ"},
    "kg": {"en": "Kg", "te": "కేజీ"},
    "rs": {"en": "Rs", "te": "రూ"},
    "net": {"en": "Net", "te": "నికర"},
    "payable": {"en": "PAYABLE", "te": "చెల్లించవలసిన"},
  };

  static String getLabel(String key, PdfLanguageMode mode) {
    final en = _labels[key]?["en"] ?? key;
    final te = _labels[key]?["te"] ?? key;
    return mode == PdfLanguageMode.telugu ? te : en;
  }

  static Map<String, Map<String, double>> getGroupedPricing(VegetableStock item) {
    final Map<String, Map<String, double>> grouped = {
      'kgs': {},
      'bags': {}
    };
    for (var row in item.pricingRows) {
      if (row.quantity <= 0 || row.price <= 0) continue;
      final type = row.type;
      final priceKey = row.price.toStringAsFixed(2);
      grouped[type]![priceKey] = (grouped[type]![priceKey] ?? 0) + row.quantity;
    }
    return grouped;
  }

  static String generateBillText(BuildContext context, List<VegetableStock> stocks, FarmitreProvider farmitre, BillHeaderData header) {
    final isTe = Localizations.localeOf(context).languageCode == 'te';
    final firstStock = stocks.first;
    final farmer = farmitre.farmers.firstWhere((f) => f.id == firstStock.farmerId, orElse: () => Farmer(id: '', name: 'Unknown', createdAt: ''));

    String formattedDate = firstStock.date.substring(0, 10);
    try {
      final date = DateTime.parse(firstStock.date);
      formattedDate = DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {}

    String message = "*${header.businessName}*\n";
    message += "${header.proprietorName}${header.phoneNumber.isNotEmpty ? ' - ${header.phoneNumber}' : ''}\n";
    message += "———————————————\n";
    message += "*Date:* $formattedDate\n";
    message += "*Farmer:* ${farmer.name}\n";
    message += "———————————————\n\n";

    double totalGross = 0;
    double totalExpenses = 0;

    for (int i = 0; i < stocks.length; i++) {
      final item = stocks[i];
      final veg = vegetables.firstWhere((v) => v.id == item.vegetableId, orElse: () => VegetableInfo(id: '', nameEn: 'Unknown', nameTe: 'తెలియదు', emoji: '📦'));
      final vegName = getVegetableName(item.vegetableId, isTe, isDemo: farmitre.isDemo);
      
      double salesTotal = item.pricingRows.fold(0, (acc, row) => acc + (row.quantity * row.price));
      double commissionTotal = (salesTotal * (item.commissionRate / 100)).roundToDouble();
      double importChargeTotal = (item.importedBags - (item.oldBags ?? 0)) * item.koliRate;
      double expensesTotal = item.expenses.fold(0.0, (acc, exp) => acc + exp.amount) + commissionTotal + importChargeTotal;
      
      totalGross += salesTotal;
      totalExpenses += expensesTotal;

      message += "${i + 1}. *${vegName.toUpperCase()}*\n";
      message += "   Import Bgs: ${item.importedBags}\n";
      
      final grouped = getGroupedPricing(item);
      final sortedKgPrices = grouped['kgs']!.keys.toList()..sort((a, b) => double.parse(b).compareTo(double.parse(a)));
      for (var priceKey in sortedKgPrices) {
        final q = grouped['kgs']![priceKey]!;
        final price = double.parse(priceKey);
        message += "   $q Kg x Rs. $price = ${(q * price).round()}\n";
      }

      final sortedBagPrices = grouped['bags']!.keys.toList()..sort((a, b) => double.parse(b).compareTo(double.parse(a)));
      for (var priceKey in sortedBagPrices) {
        final q = grouped['bags']![priceKey]!;
        final price = double.parse(priceKey);
        message += "   ${q.toInt()} Bgs x Rs. $price = ${(q * price).round()}\n";
      }
      
      message += "   ———————\n";
      message += "   Total: Rs. ${salesTotal.round()}\n";
      message += "   Sold Bgs: ${item.soldBags}\n";
      message += "   Remain Bgs: ${item.importedBags - item.soldBags}\n\n";

      message += "   *EXPENSES:*\n";
      message += "   Commission (${item.commissionRate.round()}%): Rs. ${commissionTotal.round()}\n";
      message += "   Labour: Rs. ${importChargeTotal.round()}\n";

      for (var exp in item.expenses) {
        message += "   ${exp.name}: Rs. ${exp.amount.round()}\n";
      }
      
      message += "   ———————\n";
      message += "   *Net: Rs. ${(salesTotal - expensesTotal).round()}*\n\n";
      
      if (i < stocks.length - 1) {
        message += "———————————————\n\n";
      }
    }

    if (stocks.length > 1) {
      message += "———————————————\n";
      message += "*TOTAL PAYABLE: Rs. ${(totalGross - totalExpenses).round()}*\n";
      message += "———————————————\n\n";
    }
    
    message += "_Generated via Farmite App_";
    return message;
  }

  static Future<Uint8List> generatePdfBytes(BuildContext context, List<VegetableStock> stocks, FarmitreProvider farmitre, PdfLanguageMode mode, BillHeaderData header) async {
    final firstStock = stocks.first;
    final farmer = farmitre.farmers.firstWhere((f) => f.id == firstStock.farmerId, orElse: () => Farmer(id: '', name: 'Unknown', createdAt: ''));
    
    DateTime dateObj;
    try {
      dateObj = DateTime.parse(firstStock.date);
    } catch (_) {
      dateObj = DateTime.now();
    }
    final String dayName = DateFormat('EEEE', mode == PdfLanguageMode.telugu ? 'te_IN' : 'en_US').format(dateObj);
    final String dateFormatted = DateFormat('dd/MM/yyyy').format(dateObj);

    final englishFont = await PdfGoogleFonts.poppinsRegular();
    final englishBold = await PdfGoogleFonts.poppinsBold();

    final ByteData regularData = await rootBundle.load('assets/fonts/NotoSansTelugu-Regular.ttf');
    final ByteData boldData = await rootBundle.load('assets/fonts/NotoSansTelugu-Bold.ttf');
    final pw.Font teFont = pw.Font.ttf(regularData);
    final pw.Font teFontBold = pw.Font.ttf(boldData);

    // Explicitly define styles for Telugu and English
    final pw.TextStyle teStyle = pw.TextStyle(font: teFont);
    final pw.TextStyle teBold = pw.TextStyle(font: teFontBold, fontWeight: pw.FontWeight.bold);
    final pw.TextStyle enStyle = pw.TextStyle(font: englishFont);
    final pw.TextStyle enBold = pw.TextStyle(font: englishBold, fontWeight: pw.FontWeight.bold);

    // Helper to get correct style based on mode and need for bold
    pw.TextStyle s({bool bold = false}) {
      if (mode == PdfLanguageMode.telugu) {
        return bold ? teBold : teStyle;
      }
      // English mode with Telugu fallback
      return bold 
          ? enBold.copyWith(fontFallback: [teFontBold]) 
          : enStyle.copyWith(fontFallback: [teFont]);
    }

    final doc = pw.Document();
    
    double grandGross = 0;
    double grandKiraya = 0;
    double grandKooli = 0;
    double grandCommission = 0;

    for (var s in stocks) {
      double salesTotal = s.pricingRows.fold(0.0, (acc, r) => acc + (r.quantity * r.price));
      grandGross += salesTotal;
      grandCommission += (salesTotal * (s.commissionRate / 100)).roundToDouble();
      
      double importCharge = (s.importedBags - (s.oldBags ?? 0)) * s.koliRate;
      grandKooli += importCharge;

      for (var e in s.expenses) {
        if (e.name == "Transport" || e.name == "Hire" || e.name.toLowerCase().contains("kiray")) {
          grandKiraya += e.amount;
        } else {
          grandKooli += e.amount;
        }
      }
    }

    final double totalExp = grandKiraya + grandKooli + grandCommission;
    final double netTotal = grandGross - totalExp;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        theme: pw.ThemeData.withFont(
          base: mode == PdfLanguageMode.telugu ? teFont : englishFont, 
          bold: mode == PdfLanguageMode.telugu ? teFontBold : englishBold,
          fontFallback: [teFont, teFontBold, englishFont, englishBold],
        ),
        build: (pw.Context context) {
          final boldTextStyle = s(bold: true);
          final italicPink = s(bold: true).copyWith(
            fontStyle: pw.FontStyle.italic, 
            color: PdfColors.pink, 
            fontSize: 10
          );

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(child: pw.Text(header.businessName, style: boldTextStyle.copyWith(fontSize: 14, color: PdfColors.green), textAlign: pw.TextAlign.center)),
              pw.Center(child: pw.Text("${header.proprietorName}${header.phoneNumber.isNotEmpty ? '. ${header.phoneNumber}' : ''}", style: boldTextStyle.copyWith(fontSize: 12, color: PdfColors.purple), textAlign: pw.TextAlign.center)),
              pw.SizedBox(height: 10),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    child: pw.Text("${getLabel("sri", mode)} ${farmer.name}", style: boldTextStyle.copyWith(fontSize: 14, color: PdfColors.black)),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(dayName, style: italicPink),
                      pw.Text(dateFormatted, style: italicPink),
                    ],
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.pink, thickness: 1),
              pw.SizedBox(height: 10),
              
              ...stocks.map((s) {
                final veg = vegetables.firstWhere((v) => v.id == s.vegetableId, orElse: () => vegetables.first);
                final vegName = getVegetableName(s.vegetableId, mode == PdfLanguageMode.telugu, isDemo: farmitre.isDemo);
                final grouped = getGroupedPricing(s);
                
                final List<pw.Widget> rows = [];
                final sortedKgPrices = grouped['kgs']!.keys.toList()..sort((a, b) => double.parse(b).compareTo(double.parse(a)));
                final sortedBagPrices = grouped['bags']!.keys.toList()..sort((a, b) => double.parse(b).compareTo(double.parse(a)));
                
                bool itemHeaderShown = false;

                for (int i = 0; i < sortedKgPrices.length; i++) {
                  final priceKey = sortedKgPrices[i];
                  final q = grouped['kgs']![priceKey]!;
                  final price = double.parse(priceKey);
                  final rowTotal = (q * price).round();
                  
                  final String displayHeader = !itemHeaderShown ? "${s.importedBags} ${vegName.toUpperCase()}" : "";
                  itemHeaderShown = true;

                  rows.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Row(
                        children: [
                          pw.Expanded(flex: 25, child: pw.Text("$rowTotal", style: boldTextStyle.copyWith(fontSize: 12, color: PdfColors.red))),
                          pw.Expanded(flex: 35, child: pw.Text(displayHeader, style: boldTextStyle.copyWith(fontSize: 12, color: PdfColors.green900))),
                          pw.Expanded(flex: 20, child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            children: [
                              pw.Text("${q % 1 == 0 ? q.toInt() : q}K", style: boldTextStyle.copyWith(fontSize: 12, color: PdfColors.green900)),
                            ],
                          )),
                          pw.Expanded(flex: 20, child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            children: [
                              pw.Text("${price % 1 == 0 ? price.toInt() : price}/-", style: boldTextStyle.copyWith(fontSize: 12, color: PdfColors.red)),
                            ],
                          )),
                        ],
                      ),
                    )
                  );
                }

                for (var priceKey in sortedBagPrices) {
                  final q = grouped['bags']![priceKey]!;
                  final price = double.parse(priceKey);
                  final rowTotal = (q * price).round();

                  final String displayHeader = !itemHeaderShown ? "${s.importedBags} ${vegName.toUpperCase()}" : "";
                  itemHeaderShown = true;

                  rows.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Row(
                        children: [
                          pw.Expanded(flex: 25, child: pw.Text("$rowTotal", style: boldTextStyle.copyWith(fontSize: 12, color: PdfColors.red))),
                          pw.Expanded(flex: 35, child: pw.Text(displayHeader, style: boldTextStyle.copyWith(fontSize: 12, color: PdfColors.green900))),
                          pw.Expanded(flex: 20, child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            children: [
                              pw.Text("${q.toInt()}", style: boldTextStyle.copyWith(fontSize: 12, color: PdfColors.green900)),
                            ],
                          )),
                          pw.Expanded(flex: 20, child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            children: [
                              pw.Text("${price % 1 == 0 ? price.toInt() : price}/-", style: boldTextStyle.copyWith(fontSize: 12, color: PdfColors.red)),
                            ],
                          )),
                        ],
                      ),
                    )
                  );
                }

                double totalQuantityKgs = s.pricingRows.where((r) => r.type == 'kgs').fold(0, (acc, r) => acc + r.quantity);
                double totalQuantityBags = s.pricingRows.where((r) => r.type == 'bags').fold(0, (acc, r) => acc + r.quantity);

                return pw.Column(
                  children: [
                    ...rows,
                    pw.Row(
                      children: [
                        pw.Spacer(flex: 60),
                        pw.Expanded(flex: 20, child: pw.Container(
                          margin: const pw.EdgeInsets.only(top: 2, bottom: 2),
                          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1))),
                          alignment: pw.Alignment.centerRight,
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            children: [
                              if (totalQuantityKgs > 0)
                                pw.Text("${totalQuantityKgs % 1 == 0 ? totalQuantityKgs.toInt() : totalQuantityKgs} K ", style: boldTextStyle.copyWith(fontSize: 12, color: PdfColors.green900)),
                              if (totalQuantityBags > 0)
                                pw.Text("${totalQuantityBags.toInt()}", style: boldTextStyle.copyWith(fontSize: 12, color: PdfColors.green900)),
                            ],
                          ),
                        )),
                        pw.Spacer(flex: 20),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Expanded(flex: 25, child: pw.SizedBox()),
                        pw.Expanded(flex: 35, child: pw.Column(
                          children: [
                            pw.Container(
                              decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1))),
                              alignment: pw.Alignment.center,
                              child: pw.Text("${s.soldBags}", style: boldTextStyle.copyWith(fontSize: 12, color: PdfColors.green900)),
                            ),
                            pw.Text("(${s.importedBags - s.soldBags})", style: boldTextStyle.copyWith(fontSize: 10, color: PdfColors.green900)),
                          ]
                        )),
                        pw.Expanded(flex: 40, child: pw.SizedBox()),
                      ],
                    ),
                    pw.Divider(color: PdfColors.pink, thickness: 1),
                  ],
                );
              }),

              pw.SizedBox(height: 20),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 48,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("${grandGross.round()}", style: boldTextStyle.copyWith(fontSize: 12, color: PdfColors.red)),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.red, width: 1))),
                              child: pw.Text("${totalExp.round()}", style: boldTextStyle.copyWith(fontSize: 12, color: PdfColors.red)),
                            ),
                            pw.SizedBox(width: 4),
                            pw.Expanded(
                              child: pw.Text(getLabel("expenditure", mode), style: boldTextStyle.copyWith(fontSize: 10, color: PdfColors.blue)),
                            ),
                          ]
                        ),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("${netTotal.round()}", style: boldTextStyle.copyWith(fontSize: 12, color: PdfColors.red)),
                            pw.SizedBox(width: 4),
                            pw.Expanded(
                              child: pw.Text(getLabel("totalAmount", mode), style: boldTextStyle.copyWith(fontSize: 10, color: PdfColors.blue)),
                            ),
                          ]
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    flex: 52,
                    child: pw.Column(
                      children: [
                        _buildExpRow(getLabel("kirayee", mode), grandKiraya.round(), boldTextStyle.copyWith(fontSize: 11)),
                        pw.SizedBox(height: 6),
                        _buildExpRow(getLabel("kooli", mode), grandKooli.round(), boldTextStyle.copyWith(fontSize: 11)),
                        pw.SizedBox(height: 6),
                        _buildExpRow(getLabel("commission", mode), grandCommission.round(), boldTextStyle.copyWith(fontSize: 11)),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6),
                          child: pw.Container(width: 100, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1)))),
                        ),
                        _buildExpRow(getLabel("total", mode), totalExp.round(), boldTextStyle.copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text("Generated via Farmite App", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey))),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildExpRow(String label, int value, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(label, style: style.copyWith(color: PdfColors.blue900), maxLines: 1),
          ),
          pw.SizedBox(width: 4),
          pw.Text("$value", style: style.copyWith(color: PdfColors.blue900)),
        ],
      ),
    );
  }

  static void showShareOptions(BuildContext context, List<VegetableStock> stocks, FarmitreProvider farmitre, BillHeaderData header) {
    final t = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(t.sendBill, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.picture_as_pdf, color: Colors.white)),
              title: const Text("PDF (English)"),
              onTap: () {
                Navigator.pop(context);
                _shareAsPdf(context, stocks, farmitre, PdfLanguageMode.english, header);
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.picture_as_pdf, color: Colors.white)),
              title: const Text("PDF (తెలుగు)"),
              onTap: () {
                Navigator.pop(context);
                _shareAsPdf(context, stocks, farmitre, PdfLanguageMode.telugu, header);
              },
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.message, color: Colors.white)),
              title: const Text("Text / WhatsApp Message"),
              onTap: () {
                Navigator.pop(context);
                _shareAsText(context, stocks, farmitre, header);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  static Future<void> _shareAsPdf(BuildContext context, List<VegetableStock> stocks, FarmitreProvider farmitre, PdfLanguageMode mode, BillHeaderData header) async {
    final pdfBytes = await generatePdfBytes(context, stocks, farmitre, mode, header);
    final firstStock = stocks.first;
    final farmer = farmitre.farmers.firstWhere((f) => f.id == firstStock.farmerId, orElse: () => Farmer(id: '', name: 'Unknown', createdAt: ''));
    
    DateTime dateObj;
    try {
      dateObj = DateTime.parse(firstStock.date);
    } catch (_) {
      dateObj = DateTime.now();
    }
    final String dateFormatted = DateFormat('dd-MM-yyyy').format(dateObj);
    
    String fileName = farmer.name.trim();
    if (fileName.isEmpty) fileName = "Bill";
    fileName = fileName.replaceAll(RegExp(r'[^\w\s-]'), '');
    fileName = "${fileName}_$dateFormatted.pdf";

    final tempDir = await getTemporaryDirectory();
    final file = await File('${tempDir.path}/$fileName').create();
    await file.writeAsBytes(pdfBytes);

    if (!context.mounted) return;

    // Upload to Firebase if not in demo mode
    final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
    if (!auth.isDemoMode) {
      AuditLogService.logAction(
        action: "WHATSAPP_BILL_SHARE_PDF",
        screen: "BillDetailsPage",
        newData: {"billId": firstStock.id, "farmer": farmer.name, "mode": mode.toString()},
      );
      // Use the first stock's ID as the bill ID for now, or generate a group ID
      // If it's a single item bill, it works perfectly. 
      // If it's a group, we still link it to one of them or handle group sync.
      uploadBillPdf(billId: firstStock.id, pdfBytes: pdfBytes);
    }

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, name: fileName)],
      subject: 'Bill for ${farmer.name}',
    ));
  }

  static Future<String?> uploadBillPdf({
    required String billId,
    required Uint8List pdfBytes,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('bills')
          .child('$billId.pdf');

      final uploadTask = await storageRef.putData(
        pdfBytes,
        SettableMetadata(contentType: 'application/pdf'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Update firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bills')
          .doc(billId)
          .update({'pdfUrl': downloadUrl});

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading PDF: $e');
      return null;
    }
  }

  static void _shareAsText(BuildContext context, List<VegetableStock> stocks, FarmitreProvider farmitre, BillHeaderData header) {
    final message = generateBillText(context, stocks, farmitre, header);
    final firstStock = stocks.first;
    final farmer = farmitre.farmers.firstWhere((f) => f.id == firstStock.farmerId, orElse: () => Farmer(id: '', name: 'Unknown', createdAt: ''));
    
    AuditLogService.logAction(
      action: "WHATSAPP_BILL_SHARE_TEXT",
      screen: "BillDetailsPage",
      newData: {"billId": firstStock.id, "farmer": farmer.name},
    );

    SharePlus.instance.share(ShareParams(text: message, subject: 'Bill for ${farmer.name}'));
  }
}
