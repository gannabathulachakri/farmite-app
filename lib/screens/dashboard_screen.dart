import 'package:farmitre_flutter/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:farmitre_flutter/l10n/app_localizations.dart';
import '../providers/farmitre_provider.dart';
import 'auth/subscription_screen.dart';
import 'bill_details_screen.dart';
import '../models/types.dart';
import '../utils/constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isRefreshing = false;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    // Silent refresh on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData(isManual: false);
    });
  }

  Future<void> _refreshData({bool isManual = true}) async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final uid = context.read<AuthProvider>().user?.uid;
      await context.read<FarmitreProvider>().refreshData(uid: uid, force: isManual);
      
      if (mounted && isManual) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dashboard updated'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted && isManual) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Refresh failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _isFirstLoad = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final farmitre = Provider.of<FarmitreProvider>(context);

    if (_isFirstLoad && farmitre.stocks.isEmpty && farmitre.farmers.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }

    final int totalFarmers = farmitre.farmers.length;
    final int totalStockBags = farmitre.stocks.fold(0, (sum, stock) => sum + stock.importedBags);
    
    final today = DateTime.now().toIso8601String().substring(0, 10);
    double todayRevenue = 0;
    
    for (var stock in farmitre.stocks) {
      if (stock.date.startsWith(today)) {
        todayRevenue += farmitre.calculateStockTotal(stock);
      }
    }

    final recentStocks = List<VegetableStock>.from(farmitre.stocks)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentActivity = recentStocks.take(10).toList();
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => _refreshData(isManual: true),
          color: const Color(0xFF10B981),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              expandedHeight: 120,
              actions: [
                if (auth.isDemoMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(LucideIcons.crown, size: 14, color: Colors.amber),
                      label: const Text('UPGRADE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionScreen())),
                      backgroundColor: Colors.amber.withValues(alpha: 0.1),
                      side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                    ),
                  ),
                IconButton(
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: _isRefreshing ? null : () => _refreshData(isManual: true),
                  tooltip: 'Refresh Data',
                ),
              ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                t.appTitle,
                style: const TextStyle(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16, end: 100),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                if (auth.isDemoMode) _buildPremiumPromo(context),
                const SizedBox(height: 8),
                Text(t.dashboard, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        t.totalFarmers,
                        totalFarmers.toString(),
                        LucideIcons.users,
                        const Color(0xFF3B82F6),
                        '👨‍🌾',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        t.totalStock,
                        totalStockBags.toString(),
                        LucideIcons.package,
                        const Color(0xFFF59E0B),
                        '📦',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRevenueCard(context, t.todayRevenue, '₹${todayRevenue.round()}', LucideIcons.indianRupee, const Color(0xFF10B981)),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        t.recentActivity,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (recentActivity.isNotEmpty)
                      TextButton(
                        onPressed: () {}, // Navigate to history
                        child: const Text('View All'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (recentActivity.isEmpty)
                  _buildEmptyState(context, t)
                else
                  ...recentActivity.map((stock) => _buildActivityItem(context, stock, farmitre)),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    ),
    ),
    );
  }

  Widget _buildPremiumPromo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const Text('👑', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enjoying the app?',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Upgrade to unlock PDF sharing and cloud sync.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionScreen())),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('UPGRADE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color, String emoji) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: isDark ? 0.6 : 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color, letterSpacing: -1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(emoji, style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodySmall?.color)),
        ],
      ),
    );
  }

  Widget _buildRevenueCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)], // Premium gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A7BD5).withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(LucideIcons.trendingUp, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          const Text('📉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(t.noActivityYet, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(t.startByAddingFarmer, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, VegetableStock stock, FarmitreProvider farmitre) {
    final farmer = farmitre.farmers.firstWhere((f) => f.id == stock.farmerId, orElse: () => Farmer(id: '', name: 'Unknown', createdAt: ''));
    final veg = vegetables.firstWhere((v) => v.id == stock.vegetableId, orElse: () => VegetableInfo(id: '', nameEn: '', nameTe: '', emoji: '📦'));
    final t = AppLocalizations.of(context)!;
    final isTe = Localizations.localeOf(context).languageCode == 'te';
    final vegName = getVegetableName(stock.vegetableId, isTe, isDemo: farmitre.isDemo);
    
    // Extract a short ID or use date as a reference
    final shortId = stock.id.length > 5 ? stock.id.substring(stock.id.length - 5).toUpperCase() : stock.id;
    final String timeStr = stock.date.length >= 16 ? stock.date.substring(11, 16) : '';

    return InkWell(
      onTap: () {
        // Navigate to bill details if needed
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BillDetailsScreen(stocks: [stock]),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            // Icon Section
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(veg.emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 16),
            
            // Details Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          farmer.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        farmitre.isDemo ? 'Demo Bill' : '#$shortId',
                        style: TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.grey.withValues(alpha: 0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(LucideIcons.package, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$vegName • ${stock.importedBags} ${t.bagsLabel}',
                          style: TextStyle(
                            fontSize: 13, 
                            fontWeight: FontWeight.w500, 
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (timeStr.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        timeStr,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Amount Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${farmitre.calculateStockTotal(stock).round()}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900, 
                    fontSize: 18, 
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View',
                        style: TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold, 
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        LucideIcons.chevronRight, 
                        size: 10, 
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
