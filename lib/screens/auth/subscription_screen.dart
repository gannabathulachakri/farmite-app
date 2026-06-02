import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../providers/auth_provider.dart';
import 'premium_success_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isRefreshing = false;
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Show loading dialog while verifying
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await auth.verifyPaymentAndActivate(
        paymentId: response.paymentId!,
        orderId: response.orderId,
        signature: response.signature,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Premium activated successfully.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PremiumSuccessScreen()),
          );
        } else {
          _showVerificationError(response);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showVerificationError(response, error: e.toString());
      }
    }
  }

  void _showVerificationError(PaymentSuccessResponse response, {String? error}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Verification Pending'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your payment was successful, but we couldn\'t verify it with our server right now.',
              style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (error != null) 
              Text('Error: $error', style: const TextStyle(color: Colors.red, fontSize: 12)),
            const SizedBox(height: 12),
            const Text('Please don\'t worry. Your Payment ID is recorded. You can try verifying again now or contact support if the issue persists.'),
            const SizedBox(height: 8),
            SelectableText('Payment ID: ${response.paymentId}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _handlePaymentSuccess(response);
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry Verification'),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed: ${response.message}'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet: ${response.walletName}')),
    );
  }

  void _openCheckout() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = auth.user?.email ?? '';
    final phone = auth.userData?['phone'] ?? '';

    var options = {
      'key': 'rzp_test_Suh13otCJmEhzK',
      'amount': 25000, // Amount in paise (250.00)
      'name': 'Vegetable Billing App',
      'description': 'Monthly Subscription',
      'retry': {
        'enabled': true,
        'max_count': 3
      },
      'prefill': {
        'contact': phone,
        'email': email,
      },
      'theme': {
        'color': '#2E7D32',
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open payment gateway: $e')),
      );
    }
  }

  Future<void> _refreshStatus() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await context.read<AuthProvider>().refreshSubscriptionStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status refreshed successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            action: errorMessage.contains('Internet') ? SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _refreshStatus,
            ) : null,
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userData = auth.userData;
    final status = auth.subscriptionStatus;

    String statusText = 'Inactive';
    Color statusColor = Colors.grey;

    if (status == SubscriptionStatus.active) {
      statusText = 'Active';
      statusColor = Colors.green;
    } else if (status == SubscriptionStatus.pendingVerification) {
      statusText = 'Pending Verification';
      statusColor = Colors.orange;
    } else if (status == SubscriptionStatus.expired) {
      statusText = 'Expired';
      statusColor = Colors.red;
    } else if (status == SubscriptionStatus.failed) {
      statusText = 'Payment Failed';
      statusColor = Colors.red;
    }

    String expiryDateText = 'N/A';
    if (userData?['subscriptionExpiryDate'] != null) {
      final date = (userData!['subscriptionExpiryDate'] as dynamic).toDate();
      expiryDateText = DateFormat('dd/MM/yyyy').format(date);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshStatus,
            tooltip: 'Refresh Status',
          ),
          IconButton(
            icon: const Icon(LucideIcons.logOut),
            onPressed: () => auth.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: Text('💎', style: TextStyle(fontSize: 64))),
            const SizedBox(height: 24),
            const Text(
              'Upgrade to Standard',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Get full access to all features including billing, stock management and PDF reports.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Current Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(statusText, style: TextStyle(fontWeight: FontWeight.w900, color: statusColor)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Expires on:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(expiryDateText, style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isRefreshing ? null : _refreshStatus,
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh Subscription Status'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor.withValues(alpha: 0.2),
                      foregroundColor: statusColor,
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Standard Monthly',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹250 / month',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Divider(height: 40),
                  _buildFeatureRow(context, 'Unlimited Farmer Records'),
                  _buildFeatureRow(context, 'Real-time Stock Tracking'),
                  _buildFeatureRow(context, 'Professional PDF Reports'),
                  _buildFeatureRow(context, 'Multi-language Support'),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _openCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Subscribe Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 32),
            const Text(
              'Secure in-app payment via Razorpay. No browser required.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(LucideIcons.checkCircle2, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
