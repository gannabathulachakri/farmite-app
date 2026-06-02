import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/auth_provider.dart';
import '../../providers/farmitre_provider.dart';
import '../../providers/bill_settings_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometrics();
    });
  }

  Future<void> _checkBiometrics() async {
    final auth = context.read<AuthProvider>();
    if (auth.user != null && auth.biometricsEnabled && !auth.isBiometricallyAuthenticated) {
      _handleBiometricLogin();
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    final error = await context.read<AuthProvider>().signInWithGoogle();
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        if (error != 'Google sign in cancelled') {
          setState(() => _errorMessage = 'Google sign-in failed. Please try again.');
        }
      } else {
        _promptBiometrics();
      }
    }
  }

  Future<void> _promptBiometrics() async {
    final auth = context.read<AuthProvider>();
    if (!auth.biometricsEnabled) {
      final canCheck = await auth.canCheckBiometrics();
      if (canCheck && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Enable Fingerprint?'),
            content: const Text('Would you like to enable fingerprint login for faster access?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('Maybe Later')
              ),
              TextButton(
                onPressed: () async {
                  await auth.setBiometricsEnabled(true);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Enable'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    final auth = context.read<AuthProvider>();
    final authenticated = await auth.authenticateWithBiometrics();
    if (!authenticated && mounted) {
      setState(() => _errorMessage = 'Biometric authentication failed. Please use Google Login.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isBiometricRequired = auth.user != null && auth.biometricsEnabled && !auth.isBiometricallyAuthenticated;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Text('🧺', style: TextStyle(fontSize: 80), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                const Text(
                  'Farmite',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  'Vegetable Management',
                  style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),
                
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade900, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _errorMessage = null),
                          child: Icon(Icons.close, size: 18, color: Colors.red.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                if (isBiometricRequired) ...[
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleBiometricLogin,
                    icon: const Icon(LucideIcons.fingerprint, size: 24),
                    label: const Text('Unlock with Fingerprint', 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => auth.signOut(),
                    child: const Text('Switch Account'),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleGoogleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                                height: 24,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_circle, size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Continue with Google',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ],
                
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<AuthProvider>().toggleDemoMode(true);
                    context.read<FarmitreProvider>().setDemoMode(true);
                    context.read<BillSettingsProvider>().setDemoMode(true);
                  },
                  icon: const Icon(LucideIcons.playCircle, size: 18),
                  label: const Text('EXPLORE DEMO MODE'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade200),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
