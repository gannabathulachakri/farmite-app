import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:farmitre_flutter/l10n/app_localizations.dart';
import 'package:farmitre_flutter/providers/auth_provider.dart';
import 'package:farmitre_flutter/screens/auth/login_screen.dart';
import 'package:farmitre_flutter/screens/auth/pending_verification_screen.dart';
import 'package:farmitre_flutter/screens/auth/subscription_screen.dart';
import 'providers/farmitre_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/bill_settings_provider.dart';
import 'widgets/bottom_nav.dart';
import 'screens/stock_entry_screen.dart';
import 'screens/bill_details_screen.dart';
import 'models/types.dart';

class FarmitreApp extends StatelessWidget {
  final bool firebaseInitialized;
  const FarmitreApp({super.key, this.firebaseInitialized = true});

  @override
  Widget build(BuildContext context) {
    if (!firebaseInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 24),
                  const Text(
                    'Firebase Initialization Failed',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please check your internet connection and ensure google-services.json is correctly configured.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FarmitreProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => BillSettingsProvider()),
      ],
      child: Consumer3<ThemeProvider, LocaleProvider, AuthProvider>(
        builder: (context, themeProvider, localeProvider, authProvider, _) {
          return MaterialApp(
            key: const ValueKey('MainMaterialApp'),
            title: 'Farmite Vegetables',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            locale: localeProvider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('te'),
            ],
            home: _getHome(authProvider),
            routes: {
              '/stock_entry': (context) => const StockEntryScreen(),
              '/bill_details': (context) {
                final args = ModalRoute.of(context)!.settings.arguments;
                if (args is List<VegetableStock>) {
                  return BillDetailsScreen(stocks: args);
                }
                return const Scaffold(body: Center(child: Text("Invalid arguments")));
              },
            },
          );
        },
      ),
    );
  }

  Widget _getHome(AuthProvider auth) {
    if (!auth.isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🧺', style: TextStyle(fontSize: 64)),
              SizedBox(height: 24),
              CircularProgressIndicator(color: Color(0xFF10B981)),
            ],
          ),
        ),
      );
    }

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    switch (auth.subscriptionStatus) {
      case SubscriptionStatus.active:
        return const AppNavigation();
      case SubscriptionStatus.pendingVerification:
        return const PendingVerificationScreen();
      case SubscriptionStatus.failed:
      case SubscriptionStatus.expired:
      default:
        return SubscriptionScreen();
    }
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    
    // Premium Agriculture color palette
    final primaryColor = const Color(0xFF10B981); // Emerald Green
    final secondaryColor = const Color(0xFF059669); // Deeper Green
    final accentColor = const Color(0xFFF59E0B); // Amber for alerts/notifications
    
    // Backgrounds
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: surfaceColor,
      ),
      fontFamily: 'NotoSans',
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 2,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1E293B),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'NotoSans',
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : const Color(0xFF1E293B)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        color: surfaceColor,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF334155) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: primaryColor, width: 1.5),
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

}
