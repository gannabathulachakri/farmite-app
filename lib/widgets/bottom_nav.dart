import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:farmitre_flutter/l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/farmitre_provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/farmers_screen.dart';
import '../screens/stock_entry_screen.dart';
import '../screens/bills_screen.dart';
import '../screens/settings_screen.dart';

class AppNavigation extends StatefulWidget {
  const AppNavigation({super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const FarmersScreen(),
    const StockEntryScreen(),
    const BillsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: auth.isDemoMode ? AppBar(
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        toolbarHeight: 44,
        centerTitle: true,
        elevation: 4,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.crown, size: 14, color: Colors.amber),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'DEMO MODE ACTIVE',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: () {
                context.read<AuthProvider>().toggleDemoMode(false);
                context.read<FarmitreProvider>().setDemoMode(false);
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white24,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('EXIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
            ),
          ),
        ],
      ) : null,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
            // Auto-refresh dashboard when selected
            if (index == 0) {
              final uid = context.read<AuthProvider>().user?.uid;
              context.read<FarmitreProvider>().refreshData(uid: uid);
            }
          },
          height: 80,
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          indicatorColor: colorScheme.primary.withValues(alpha: 0.1),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(LucideIcons.layoutDashboard, size: 22),
              selectedIcon: Icon(LucideIcons.layoutDashboard, size: 22, color: colorScheme.primary),
              label: t.dashboard,
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.users, size: 22),
              selectedIcon: Icon(LucideIcons.users, size: 22, color: colorScheme.primary),
              label: t.farmers,
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.plusCircle, size: 22),
              selectedIcon: Icon(LucideIcons.plusCircle, size: 22, color: colorScheme.primary),
              label: t.stockEntry,
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.fileText, size: 22),
              selectedIcon: Icon(LucideIcons.fileText, size: 22, color: colorScheme.primary),
              label: t.bills,
            ),
            NavigationDestination(
              icon: const Icon(LucideIcons.settings, size: 22),
              selectedIcon: Icon(LucideIcons.settings, size: 22, color: colorScheme.primary),
              label: t.settings,
            ),
          ],
        ),
      ),
    );
  }
}
