import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:farmitre_flutter/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../providers/farmitre_provider.dart';
import '../providers/bill_settings_provider.dart';
import '../models/types.dart';
import '../utils/constants.dart';
import '../utils/bill_utils.dart';
import '../widgets/premium_guard.dart';

class BillDetailsScreen extends StatelessWidget {
  final List<VegetableStock> stocks;

  const BillDetailsScreen({super.key, required this.stocks});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final farmitre = Provider.of<FarmitreProvider>(context);
    final billSettings = Provider.of<BillSettingsProvider>(context);
    final isTe = Localizations.localeOf(context).languageCode == 'te';
    final mode = isTe ? PdfLanguageMode.telugu : PdfLanguageMode.english;
    
    final firstStock = stocks.first;
    final farmer = farmitre.farmers.firstWhere((f) => f.id == firstStock.farmerId, orElse: () => Farmer(id: '', name: 'Unknown', createdAt: ''));

    DateTime dateObj;
    try {
      dateObj = DateTime.parse(firstStock.date);
    } catch (_) {
      dateObj = DateTime.now();
    }
    final String dayName = DateFormat('EEEE', isTe ? 'te_IN' : 'en_US').format(dateObj);
    final String dateFormatted = DateFormat('dd/MM/yyyy').format(dateObj);

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

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(t.billDetails, style: const TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF065F46).withValues(alpha: 0.03),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            billSettings.businessName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF065F46)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${billSettings.proprietorName}${billSettings.phoneNumber.isNotEmpty ? '. ${billSettings.phoneNumber}' : ''}",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B21A8)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(BillUtils.getLabel("sri", mode), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                              Text(farmer.name.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(dayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDB2777))),
                              Text(dateFormatted, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFDB2777))),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Divider(color: Color(0xFFDB2777), thickness: 1),
                    ),

                    const SizedBox(height: 12),

                    // Items List
                    ...stocks.map((s) {
                      final veg = vegetables.firstWhere((v) => v.id == s.vegetableId, orElse: () => vegetables.first);
                      final vegName = getVegetableName(s.vegetableId, isTe, isDemo: farmitre.isDemo);
                      final grouped = BillUtils.getGroupedPricing(s);

                      final sortedKgPrices = grouped['kgs']!.keys.toList()..sort((a, b) => double.parse(b).compareTo(double.parse(a)));
                      final sortedBagPrices = grouped['bags']!.keys.toList()..sort((a, b) => double.parse(b).compareTo(double.parse(a)));

                      double itemKgs = s.pricingRows.where((r) => r.type == 'kgs').fold(0, (sum, r) => sum + r.quantity);
                      double itemBags = s.pricingRows.where((r) => r.type == 'bags').fold(0, (sum, r) => sum + r.quantity);

                      return Column(
                        children: [
                          ...sortedKgPrices.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final priceKey = entry.value;
                            final q = grouped['kgs']![priceKey]!;
                            final price = double.parse(priceKey);
                            return _buildBillItemRow(
                              isFirst: idx == 0,
                              amount: (q * price).round(),
                              header: "${s.importedBags} ${vegName.toUpperCase()}",
                              quantity: q.toString(),
                              unit: "Kg",
                              rate: "${price % 1 == 0 ? price.toInt() : price}/-",
                              mode: mode,
                            );
                          }),
                          ...sortedBagPrices.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final priceKey = entry.value;
                            final q = grouped['bags']![priceKey]!;
                            final price = double.parse(priceKey);
                            return _buildBillItemRow(
                              isFirst: sortedKgPrices.isEmpty && idx == 0,
                              amount: (q * price).round(),
                              header: "${s.importedBags} ${vegName.toUpperCase()}",
                              quantity: q.toInt().toString(),
                              unit: "Bag",
                              rate: "${price % 1 == 0 ? price.toInt() : price}/-",
                              mode: mode,
                            );
                          }),

                          // Summary for the item
                          Padding(
                            padding: const EdgeInsets.only(right: 24, top: 4, bottom: 4),
                            child: Row(
                              children: [
                                const Spacer(flex: 6),
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    decoration: const BoxDecoration(border: Border(top: BorderSide(width: 1))),
                                    padding: const EdgeInsets.only(top: 2),
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (itemKgs > 0)
                                          Text("${itemKgs % 1 == 0 ? itemKgs.toInt() : itemKgs} K ",
                                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF064E3B), fontSize: 15)),
                                        if (itemBags > 0)
                                          Text("${itemBags.toInt()}",
                                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF064E3B), fontSize: 15)),
                                      ],
                                    ),
                                  ),
                                ),
                                const Spacer(flex: 3),
                              ],
                            ),
                          ),

                          // Sold/Remain Bags
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Expanded(flex: 2, child: SizedBox()),
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        decoration: const BoxDecoration(border: Border(top: BorderSide(width: 1))),
                                        padding: const EdgeInsets.only(top: 2),
                                        alignment: Alignment.center,
                                        child: Text("${s.soldBags}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF064E3B))),
                                      ),
                                      Text("(${s.importedBags - s.soldBags})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF064E3B))),
                                    ],
                                  ),
                                ),
                                const Expanded(flex: 6, child: SizedBox()),
                              ],
                            ),
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Divider(color: Color(0xFFDB2777), thickness: 0.5),
                          ),
                        ],
                      );
                    }),

                    const SizedBox(height: 32),

                    // Final Footer
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text("${grandGross.round()}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      Container(
                                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDC2626)))),
                                        child: Text("${totalExp.round()}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(BillUtils.getLabel("expenditure", mode), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 15)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      Text("${netTotal.round()}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
                                      const SizedBox(width: 8),
                                      Text(BillUtils.getLabel("totalAmount", mode), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 15)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildDetailExpRow(BillUtils.getLabel("kirayee", mode), grandKiraya.round()),
                                _buildDetailExpRow(BillUtils.getLabel("kooli", mode), grandKooli.round()),
                                _buildDetailExpRow(BillUtils.getLabel("commission", mode), grandCommission.round()),
                                const Divider(height: 16, thickness: 1, color: Colors.black),
                                _buildDetailExpRow(BillUtils.getLabel("total", mode), totalExp.round()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 30, offset: const Offset(0, -10))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: PremiumGuard(
                      child: ElevatedButton.icon(
                        onPressed: () => BillUtils.showShareOptions(
                          context, 
                          stocks, 
                          farmitre,
                          BillHeaderData(
                            businessName: billSettings.businessName,
                            proprietorName: billSettings.proprietorName,
                            phoneNumber: billSettings.phoneNumber,
                          ),
                        ),
                        icon: const Icon(LucideIcons.share2),
                        label: Text(t.sendBill, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillItemRow({
    required bool isFirst,
    required int amount,
    required String header,
    required String quantity,
    required String unit,
    required String rate,
    required PdfLanguageMode mode,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text("$amount", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626), fontSize: 16))),
          Expanded(flex: 4, child: Text(isFirst ? header : "", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF064E3B), fontSize: 16))),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(quantity, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF064E3B), fontSize: 16)),
                const SizedBox(width: 2),
                Text(unit == "Kg" ? "K" : "", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF064E3B), fontSize: 16)),
              ],
            )
          ),
          Expanded(
            flex: 3,
            child: Text(rate, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626), fontSize: 16), textAlign: TextAlign.right)
          ),
        ],
      ),
    );
  }

  Widget _buildDetailExpRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 13)),
            const SizedBox(width: 8),
            Text("$value", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A), fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
