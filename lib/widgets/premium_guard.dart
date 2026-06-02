import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/subscription_screen.dart';

class PremiumGuard extends StatelessWidget {
  final Widget child;

  const PremiumGuard({
    super.key, 
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isPremium = auth.isPremium;

    if (isPremium) {
      return child;
    }

    // In Demo Mode or Non-Premium, we show the UI normally but intercept taps
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscribe to premium to access this feature.'),
            backgroundColor: Colors.amber,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SubscriptionScreen()),
        );
      },
      child: IgnorePointer(
        ignoring: true, // This ensures the child doesn't handle the tap
        child: child,
      ),
    );
  }

  static void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const PremiumBenefitsDialog(),
    );
  }
}

class PremiumBenefitsDialog extends StatelessWidget {
  const PremiumBenefitsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👑', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Upgrade to Premium',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildComparisonRow('Unlimited Records', true, true),
            _buildComparisonRow('PDF Sharing', false, true),
            _buildComparisonRow('WhatsApp Export', false, true),
            _buildComparisonRow('Multi-device Sync', false, true),
            _buildComparisonRow('No Demo Limitations', false, true),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SubscriptionScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Upgrade Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String feature, bool inDemo, bool inPremium) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(feature, style: const TextStyle(fontWeight: FontWeight.w500))),
          Icon(inDemo ? LucideIcons.checkCircle2 : LucideIcons.xCircle, 
               color: inDemo ? Colors.green : Colors.red, size: 18),
          const SizedBox(width: 16),
          Icon(inPremium ? LucideIcons.checkCircle2 : LucideIcons.xCircle, 
               color: inPremium ? Colors.green : Colors.red, size: 18),
        ],
      ),
    );
  }
}
