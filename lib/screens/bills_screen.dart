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
import 'bill_details_screen.dart';
import '../widgets/premium_guard.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final farmitre = Provider.of<FarmitreProvider>(context);
    final billSettings = Provider.of<BillSettingsProvider>(context);
    final isTe = Localizations.localeOf(context).languageCode == 'te';

    final groupedStocks = <String, List<VegetableStock>>{};
    for (var stock in farmitre.stocks) {
      final key = "${stock.farmerId}_${stock.date.substring(0, 10)}";
      if (!groupedStocks.containsKey(key)) {
        groupedStocks[key] = [];
      }
      groupedStocks[key]!.add(stock);
    }

    final sortedKeys = groupedStocks.keys.toList()
      ..sort((a, b) {
        final dateA = a.split('_')[1];
        final dateB = b.split('_')[1];
        return dateB.compareTo(dateA);
      });

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(t.bills, style: const TextStyle(fontWeight: FontWeight.w800)),
              titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: farmitre.stocks.isEmpty
                ? SliverFillRemaining(child: _buildEmptyState(t))
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final key = sortedKeys[index];
                        final group = groupedStocks[key]!;
                        return _buildBillGroupCard(context, group, t, farmitre, isTe, billSettings);
                      },
                      childCount: sortedKeys.length,
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations t) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🧾', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 24),
        Text(t.noRecordsYet, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(t.generateABill, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildBillGroupCard(BuildContext context, List<VegetableStock> group, AppLocalizations t, FarmitreProvider farmitre, bool isTe, BillSettingsProvider billSettings) {
    final firstStock = group.first;
    final farmer = farmitre.farmers.firstWhere((f) => f.id == firstStock.farmerId, orElse: () => Farmer(id: '', name: 'Unknown', createdAt: ''));

    DateTime dateObj;
    try {
      dateObj = DateTime.parse(firstStock.date);
    } catch (_) {
      dateObj = DateTime.now();
    }
    final String formattedDate = DateFormat('dd MMMM, yyyy').format(dateObj);

    double groupTotal = 0;
    for (var s in group) {
      groupTotal += farmitre.calculateStockTotal(s);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(farmer.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text(formattedDate, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '₹${groupTotal.round()}',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: group.map((s) => _buildItemRow(context, s, isTe, t, farmitre)).toList(),
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: PremiumGuard(
                    child: TextButton.icon(
                      onPressed: () => BillUtils.showShareOptions(
                        context, 
                        group, 
                        farmitre,
                        BillHeaderData(
                          businessName: billSettings.businessName,
                          proprietorName: billSettings.proprietorName,
                          phoneNumber: billSettings.phoneNumber,
                        ),
                      ),
                      icon: const Icon(LucideIcons.share2, size: 18),
                      label: Text(t.sendBill),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BillDetailsScreen(stocks: group),
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.eye, size: 18),
                    label: Text(t.viewBill),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildDeleteGroupButton(context, group, farmitre, t),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, VegetableStock s, bool isTe, AppLocalizations t, FarmitreProvider farmitre) {
    final veg = vegetables.firstWhere((v) => v.id == s.vegetableId, orElse: () => vegetables.first);
    final itmNet = farmitre.calculateStockTotal(s);
    final vegName = getVegetableName(s.vegetableId, isTe, isDemo: farmitre.isDemo);

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Text(veg.emoji, style: const TextStyle(fontSize: 22)),
      title: Text(vegName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text("${s.importedBags} ${t.bagsLabel} • ₹${itmNet.round()}", style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PremiumGuard(
            child: IconButton(
              icon: const Icon(LucideIcons.pencil, size: 16, color: Colors.blue),
              onPressed: () => Navigator.pushNamed(context, '/stock_entry', arguments: s),
            ),
          ),
          PremiumGuard(
            child: IconButton(
              icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.red),
              onPressed: () => _showDeleteItemDialog(context, s, farmitre, t),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteItemDialog(BuildContext context, VegetableStock s, FarmitreProvider farmitre, AppLocalizations t) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.confirmDelete, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Delete this item from the bill?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
          TextButton(
            onPressed: () {
              farmitre.deleteStock(s.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteGroupButton(BuildContext context, List<VegetableStock> group, FarmitreProvider farmitre, AppLocalizations t) {
    return PremiumGuard(
      child: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(LucideIcons.trash2, color: Colors.red, size: 18),
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(t.confirmDelete, style: const TextStyle(fontWeight: FontWeight.w900)),
              content: const Text('Delete the entire bill group? This cannot be undone.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
                TextButton(
                  onPressed: () {
                    farmitre.deleteStocks(group.map((s) => s.id).toList());
                    Navigator.pop(context);
                  },
                  child: const Text('Delete All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
