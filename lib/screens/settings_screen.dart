import 'package:farmitre_flutter/widgets/premium_guard.dart';
import 'package:farmitre_flutter/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:farmitre_flutter/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/bill_settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_logs_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isHeaderLocked = true;
  late TextEditingController _businessNameController;
  late TextEditingController _proprietorNameController;
  late TextEditingController _phoneNumberController;

  @override
  void initState() {
    super.initState();
    final billSettings = Provider.of<BillSettingsProvider>(context, listen: false);
    _businessNameController = TextEditingController(text: billSettings.businessName);
    _proprietorNameController = TextEditingController(text: billSettings.proprietorName);
    _phoneNumberController = TextEditingController(text: billSettings.phoneNumber);
    
    // Add listener to update controllers when Firebase data finishes loading
    billSettings.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (_isHeaderLocked && mounted) {
      final billSettings = Provider.of<BillSettingsProvider>(context, listen: false);
      setState(() {
        _businessNameController.text = billSettings.businessName;
        _proprietorNameController.text = billSettings.proprietorName;
        _phoneNumberController.text = billSettings.phoneNumber;
      });
    }
  }

  @override
  void dispose() {
    final billSettings = Provider.of<BillSettingsProvider>(context, listen: false);
    billSettings.removeListener(_onSettingsChanged);
    _businessNameController.dispose();
    _proprietorNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final billSettings = Provider.of<BillSettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(t.settings, style: const TextStyle(fontWeight: FontWeight.w800)),
              titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader("Bill Header Settings", LucideIcons.fileText),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, right: 8),
                      child: Icon(
                        _isHeaderLocked ? LucideIcons.lock : LucideIcons.lockOpen,
                        size: 18,
                        color: _isHeaderLocked ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
                PremiumGuard(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _businessNameController,
                            enabled: !_isHeaderLocked,
                            decoration: const InputDecoration(
                              labelText: "Business Name",
                              helperText: "Supports multiple lines",
                              prefixIcon: Icon(LucideIcons.building, size: 20),
                            ),
                            maxLines: null,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _proprietorNameController,
                            enabled: !_isHeaderLocked,
                            decoration: const InputDecoration(
                              labelText: "Proprietor Name",
                              prefixIcon: Icon(LucideIcons.user, size: 20),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneNumberController,
                            enabled: !_isHeaderLocked,
                            decoration: const InputDecoration(
                              labelText: "Mobile Number",
                              prefixIcon: Icon(LucideIcons.phone, size: 20),
                            ),
                            keyboardType: TextInputType.phone,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 24),
                          if (_isHeaderLocked)
                            billSettings.canEdit
                                ? _buildSlideToUnlock()
                                : _buildLimitReachedUI(billSettings)
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: billSettings.isLoading
                                      ? null
                                      : () => _showSaveConfirmation(context, billSettings),
                                  icon: billSettings.isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(LucideIcons.save),
                                  label: const Text("Save Bill Header"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => setState(() => _isHeaderLocked = true),
                                  child: const Text("Cancel"),
                                ),
                              ],
                            ),
                          const SizedBox(height: 24),
                          const Text(
                            "HEADER PREVIEW",
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF065F46).withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF065F46).withValues(alpha: 0.1)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _isHeaderLocked ? billSettings.businessName : _businessNameController.text,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF065F46)),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${_isHeaderLocked ? billSettings.proprietorName : _proprietorNameController.text}. ${_isHeaderLocked ? billSettings.phoneNumber : _phoneNumberController.text}",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B21A8)),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader(t.theme, LucideIcons.palette),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text(t.darkMode, style: const TextStyle(fontWeight: FontWeight.w600)),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.moon, size: 20, color: Colors.purple),
                        ),
                        value: themeProvider.isDarkMode,
                        onChanged: (value) {
                          themeProvider.toggleTheme();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader(t.language, LucideIcons.languages),
                Card(
                  child: Column(
                    children: [
                      _buildLanguageOption(
                        context,
                        t.english,
                        'en',
                        localeProvider.locale.languageCode,
                        '🇺🇸',
                        (val) => localeProvider.setLocale(Locale(val!)),
                      ),
                      const Divider(height: 1, indent: 64),
                      _buildLanguageOption(
                        context,
                        t.telugu,
                        'te',
                        localeProvider.locale.languageCode,
                        '🇮🇳',
                        (val) => localeProvider.setLocale(Locale(val!)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader("Security", LucideIcons.shield),
                Card(
                  child: Column(
                    children: [
                      FutureBuilder<bool>(
                        future: authProvider.canCheckBiometrics(),
                        builder: (context, snapshot) {
                          final canCheck = snapshot.data ?? false;
                          return SwitchListTile(
                            title: const Text('Fingerprint Login', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(canCheck 
                                ? 'Use biometrics to secure your app' 
                                : 'Biometrics not supported on this device'),
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(LucideIcons.fingerprint, size: 20, color: Colors.blue),
                            ),
                            value: authProvider.biometricsEnabled,
                            onChanged: canCheck ? (value) {
                              authProvider.setBiometricsEnabled(value);
                            } : null,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader(t.dataManagement, LucideIcons.database),
                Card(
                  child: Column(
                    children: [
                      PremiumGuard(
                        child: ListTile(
                          title: Text(t.clearAllData, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                          subtitle: Text(t.clearDataWarning, style: const TextStyle(fontSize: 12)),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(LucideIcons.trash2, color: Colors.red, size: 20),
                          ),
                          onTap: () => _showClearDataDialog(context, t),
                        ),
                      ),
                      const Divider(height: 1, indent: 64),
                      ListTile(
                        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(authProvider.user?.email ?? '', style: const TextStyle(fontSize: 12)),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.logOut, color: Colors.orange, size: 20),
                        ),
                        onTap: () => authProvider.signOut(),
                      ),
                      if (authProvider.isAdmin) ...[
                        const Divider(height: 1, indent: 64),
                        ListTile(
                          title: const Text('Admin Logs', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('View all user action logs', style: TextStyle(fontSize: 12)),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(LucideIcons.scrollText, color: Colors.blue, size: 20),
                          ),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminLogsScreen())),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 64),
                _buildFooter(colorScheme),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideToUnlock() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          const Center(
            child: Text(
              "Slide to unlock editing",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Dismissible(
            key: const Key("unlock-slider"),
            direction: DismissDirection.startToEnd,
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(LucideIcons.alertTriangle, color: Colors.orange),
                      SizedBox(width: 8),
                      Text("Important Notice"),
                    ],
                  ),
                  content: const Text(
                    "You can change Bill Header Settings only 2 times per month. Please verify carefully before saving.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Continue"),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (_) {
              setState(() => _isHeaderLocked = false);
            },
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(2, 0),
                    )
                  ],
                ),
                child: const Icon(LucideIcons.chevronRight, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitReachedUI(BillSettingsProvider billSettings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.lock, color: Colors.red, size: 32),
          const SizedBox(height: 12),
          const Text(
            "Bill Header Settings are locked for this month. You have used your 2 monthly changes.",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 16),
          PremiumGuard(
            child: ElevatedButton.icon(
              onPressed: billSettings.supportRequested ? null : () => _showSupportRequestDialog(billSettings),
              icon: Icon(billSettings.supportRequested ? LucideIcons.clock : LucideIcons.headphones),
              label: Text(billSettings.supportRequested ? "Support Request Pending" : "Contact Support"),
              style: ElevatedButton.styleFrom(
                backgroundColor: billSettings.supportRequested ? Colors.grey : Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSaveConfirmation(BuildContext context, BillSettingsProvider billSettings) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Changes"),
        content: const Text("Are you sure you want to save these details? This will count as one of your 2 monthly edits."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await billSettings.saveToFirebase(
        businessName: _businessNameController.text,
        proprietorName: _proprietorNameController.text,
        phoneNumber: _phoneNumberController.text,
      );
      if (success) {
        setState(() => _isHeaderLocked = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Bill header saved successfully."),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to save bill header. Please try again."),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showSupportRequestDialog(BillSettingsProvider billSettings) async {
    final reasonController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Request Extra Unlock"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please provide a reason for requesting an extra edit this month."),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: "Reason for edit...",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Submit Request"),
          ),
        ],
      ),
    );

    if (result == true && reasonController.text.isNotEmpty) {
      final success = await billSettings.requestSupport(reasonController.text);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Support request submitted successfully."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    String title,
    String value,
    String groupValue,
    String emoji,
    void Function(String?) onChanged
  ) {
    return RadioListTile<String>(
      title: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: Theme.of(context).colorScheme.primary,
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }

  Widget _buildFooter(ColorScheme colorScheme) {
    return Column(
      children: [
        InkWell(
          onTap: () async {
            final url = Uri.parse('https://axorynth.vercel.app/');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✨', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(
                  "BY AXORYTH LABS",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.primary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('✨', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        InkWell(
          onTap: () async {
            final url = Uri.parse('https://chakrigannabathulaportfolio-pi.vercel.app/');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              "CHAKRI GANNABATHULA",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.withValues(alpha: 0.6),
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showClearDataDialog(BuildContext context, AppLocalizations t) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(t.clearAllData, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(t.clearDataWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('farmitre_farmers');
              await prefs.remove('farmitre_stocks');
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.dataCleared), behavior: SnackBarBehavior.floating),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Clear Everything'),
          ),
        ],
      ),
    );
  }
}
