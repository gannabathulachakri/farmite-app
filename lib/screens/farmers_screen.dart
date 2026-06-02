import 'package:farmitre_flutter/widgets/premium_guard.dart';
import 'package:farmitre_flutter/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:farmitre_flutter/l10n/app_localizations.dart';
import '../providers/farmitre_provider.dart';

class FarmersScreen extends StatefulWidget {
  const FarmersScreen({super.key});

  @override
  State<FarmersScreen> createState() => _FarmersScreenState();
}

class _FarmersScreenState extends State<FarmersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isRefreshing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final uid = context.read<AuthProvider>().user?.uid;
      await context.read<FarmitreProvider>().refreshData(uid: uid);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Farmers list refreshed from server'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _showAddFarmerDialog(BuildContext context, AppLocalizations t, FarmitreProvider farmitre) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            left: 24,
            right: 24,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text('👨‍🌾', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Text(t.addFarmer, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 32),
              Focus(
                onFocusChange: (hasFocus) {
                  if (hasFocus) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Scrollable.ensureVisible(
                        context,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        alignment: 0.1,
                      );
                    });
                  }
                },
                child: TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: t.farmerName,
                    prefixIcon: const Icon(LucideIcons.user, size: 20),
                    hintText: 'Enter farmer name',
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                ),
              ),
              const SizedBox(height: 16),
              Focus(
                onFocusChange: (hasFocus) {
                  if (hasFocus) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Scrollable.ensureVisible(
                        context,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        alignment: 0.1,
                      );
                    });
                  }
                },
                child: TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: t.phoneNumber,
                    prefixIcon: const Icon(LucideIcons.phone, size: 20),
                    hintText: 'Enter 10-digit number',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    farmitre.addFarmer(nameController.text.trim(), phoneController.text.trim());
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added ${nameController.text.trim()} 👨‍🌾'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: Text(t.save, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final farmitre = Provider.of<FarmitreProvider>(context);

    final filteredFarmers = farmitre.farmers.where((f) {
      return f.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (f.phone?.contains(_searchQuery) ?? false);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 120,
            actions: [
              IconButton(
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: _isRefreshing ? null : _refreshData,
                tooltip: 'Refresh Farmers',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(t.farmers, style: const TextStyle(fontWeight: FontWeight.w800)),
              titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Focus(
                  onFocusChange: (hasFocus) {
                    if (hasFocus) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Scrollable.ensureVisible(
                          context,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          alignment: 0.1,
                        );
                      });
                    }
                  },
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: t.searchFarmers,
                      prefixIcon: const Icon(LucideIcons.search, size: 20),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(height: 24),
                if (filteredFarmers.isEmpty)
                  _buildEmptyState(context, t)
                else
                  ...filteredFarmers.map((farmer) => _buildFarmerCard(context, farmer, t, farmitre)),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: PremiumGuard(
        child: FloatingActionButton.extended(
          onPressed: () => _showAddFarmerDialog(context, t, farmitre),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          icon: const Icon(LucideIcons.userPlus, size: 20),
          label: Text(t.addFarmer, style: const TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Text('🔍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(t.noFarmersFound, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFarmerCard(BuildContext context, dynamic farmer, AppLocalizations t, FarmitreProvider farmitre) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: const Text(
            '👨‍🌾',
            style: TextStyle(fontSize: 24),
          ),
        ),
        title: Text(farmer.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        subtitle: farmer.phone != null && farmer.phone!.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(LucideIcons.phone, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(farmer.phone!, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              )
            : null,
        trailing: PremiumGuard(
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.trash2, color: Colors.red, size: 18),
            ),
            onPressed: () {
              _showDeleteDialog(context, farmer, t, farmitre);
            },
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, dynamic farmer, AppLocalizations t, FarmitreProvider farmitre) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(t.confirmDelete, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to delete ${farmer.name}? All their stock records will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () {
              farmitre.deleteFarmer(farmer.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t.deleteSuccess), behavior: SnackBarBehavior.floating),
              );
            },
            child: Text(t.delete, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
