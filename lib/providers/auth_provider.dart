import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/config.dart';
import '../services/audit_log_service.dart';

enum SubscriptionStatus { none, pendingVerification, active, expired, failed }

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  User? _user;
  SubscriptionStatus _subscriptionStatus = SubscriptionStatus.none;
  Map<String, dynamic>? _userData;
  bool _isInitialized = false;
  bool _isDemoMode = false;
  bool _biometricsEnabled = false;
  bool _isBiometricallyAuthenticated = false;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  User? get user => _user;
  SubscriptionStatus get subscriptionStatus => _isDemoMode ? SubscriptionStatus.active : _subscriptionStatus;
  Map<String, dynamic>? get userData => _userData;
  bool get isAuthenticated => _isDemoMode || (_user != null && (!_biometricsEnabled || _isBiometricallyAuthenticated));
  bool get isInitialized => _isInitialized;
  bool get isDemoMode => _isDemoMode;
  
  bool get isPremium {
    if (_isDemoMode) return false;
    
    // Safety check: Check raw data directly from Firebase for any manual overrides
    if (_userData != null) {
      final bool premium = _userData?['premium'] == true;
      final bool isPremiumField = _userData?['isPremium'] == true;
      final String? status = _userData?['subscriptionStatus']?.toString().toLowerCase();
      final String? planStatus = _userData?['planStatus']?.toString().toLowerCase();
      
      final bool hasActiveStatus = status == 'active' || planStatus == 'active' || premium || isPremiumField;
      
      if (hasActiveStatus) {
        // Double check expiry if it exists
        final Timestamp? expiry = _userData?['subscriptionExpiryDate'] ?? _userData?['subscriptionExpiry'];
        if (expiry == null || expiry.toDate().isAfter(DateTime.now())) {
          return true;
        }
      }
    }
    
    return _subscriptionStatus == SubscriptionStatus.active;
  }

  bool get biometricsEnabled => _biometricsEnabled;
  bool get isBiometricallyAuthenticated => _isBiometricallyAuthenticated;
  bool get isAdmin => _userData?['role'] == 'admin';

  Future<void> setBiometricsEnabled(bool value) async {
    _biometricsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometrics_enabled', value);
    if (value) {
      _isBiometricallyAuthenticated = true;
    }
    notifyListeners();
  }

  Future<bool> canCheckBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access your account',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated) {
        _isBiometricallyAuthenticated = true;
        notifyListeners();
      }
      return authenticated;
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }

  void toggleDemoMode(bool val) async {
    _isDemoMode = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_demo_mode', val);
    _isInitialized = true;
    notifyListeners();
  }

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDemoMode = prefs.getBool('is_demo_mode') ?? false;
    _biometricsEnabled = prefs.getBool('biometrics_enabled') ?? false;

    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;
    debugPrint("AuthProvider: Auth state changed. User: ${_user?.uid}");
    _userDocSubscription?.cancel();
    
    if (_user != null) {
      if (_isDemoMode) {
        _isInitialized = true;
        notifyListeners();
        return;
      }
      
      _userDocSubscription = _firestore
          .collection('users')
          .doc(_user!.uid)
          .snapshots()
          .listen((snapshot) {
        debugPrint("AuthProvider: Received real-time snapshot for ${_user!.uid}");
        _processUserDoc(snapshot);
      }, onError: (error) {
        debugPrint("AuthProvider: Firestore snapshot error: $error");
      });
    } else {
      _subscriptionStatus = SubscriptionStatus.none;
      _userData = null;
      _isInitialized = true;
      _isBiometricallyAuthenticated = false;
      notifyListeners();
    }
  }

  void _processUserDoc(DocumentSnapshot doc) {
    if (doc.exists) {
      _userData = doc.data() as Map<String, dynamic>?;
      
      // Update last login if needed
      if (_user != null && (_userData?['lastLogin'] == null || 
          (DateTime.now().difference((_userData?['lastLogin'] as Timestamp).toDate()).inMinutes > 15))) {
        _firestore.collection('users').doc(_user!.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }

      final dynamic premiumVal = _userData?['premium'];
      final dynamic subStatusVal = _userData?['subscriptionStatus'];
      final dynamic isPremiumVal = _userData?['isPremium'];
      final dynamic planStatusVal = _userData?['planStatus'];
      
      final String? status = subStatusVal?.toString().toLowerCase();
      final String? planStatus = planStatusVal?.toString().toLowerCase();
      
      final Timestamp? expiry = _userData?['subscriptionExpiryDate'] ?? _userData?['subscriptionExpiry'];

      bool isActive = status == 'active' || planStatus == 'active' || premiumVal == true || isPremiumVal == true;

      if (isActive) {
        if (expiry != null && expiry.toDate().isAfter(DateTime.now())) {
          _subscriptionStatus = SubscriptionStatus.active;
        } else if (expiry == null) {
          _subscriptionStatus = SubscriptionStatus.active;
        } else {
          _subscriptionStatus = SubscriptionStatus.expired;
          if (_userData?['subscriptionStatus'] != 'expired') {
            _firestore.collection('users').doc(_user!.uid).update({
              'subscriptionStatus': 'expired',
              'premium': false,
              'isPremium': false,
            });
          }
        }
        
        if (_subscriptionStatus == SubscriptionStatus.active && _isDemoMode) {
          _isDemoMode = false;
          SharedPreferences.getInstance().then((p) => p.setBool('is_demo_mode', false));
        }
      } else if (status == 'pending_verification') {
        _subscriptionStatus = SubscriptionStatus.pendingVerification;
      } else if (status == 'expired') {
        _subscriptionStatus = SubscriptionStatus.expired;
      } else if (status == 'failed') {
        _subscriptionStatus = SubscriptionStatus.failed;
      } else {
        _subscriptionStatus = SubscriptionStatus.none;
      }
    } else {
      if (_user != null) {
        _firestore.collection('users').doc(_user!.uid).set({
          'uid': _user!.uid,
          'email': _user!.email?.toLowerCase(),
          'displayName': _user!.displayName,
          'photoUrl': _user!.photoURL,
          'premium': false,
          'isPremium': false,
          'subscriptionStatus': 'free',
          'planName': 'Free',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      _subscriptionStatus = SubscriptionStatus.none;
    }
    _isInitialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    super.dispose();
  }

  Future<void> refreshSubscriptionStatus() async {
    if (_user == null) return;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(_user!.uid)
          .get(const GetOptions(source: Source.server));
      _processUserDoc(doc);
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Google sign in cancelled';

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          await _firestore.collection('users').doc(user.uid).update({
            'displayName': user.displayName,
            'photoUrl': user.photoURL,
            'lastLogin': FieldValue.serverTimestamp(),
          });
        } else {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email?.toLowerCase(),
            'displayName': user.displayName,
            'photoUrl': user.photoURL,
            'premium': false,
            'isPremium': false,
            'subscriptionStatus': 'free',
            'planName': 'Free',
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          });
        }
        
        _isBiometricallyAuthenticated = true;
        
        AuditLogService.logAction(
          action: "GOOGLE_LOGIN",
          screen: "LoginPage",
          status: "success",
        );
      }
      return null;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      AuditLogService.logAction(
        action: "GOOGLE_LOGIN",
        screen: "LoginPage",
        status: "failed",
        errorMessage: e.toString(),
      );
      return 'Google sign-in failed. Please try again.';
    }
  }

  Future<void> signOut() async {
    AuditLogService.logAction(
      action: "LOGOUT",
      screen: "ProfilePage",
      status: "success",
    );
    await _googleSignIn.signOut();
    await _auth.signOut();
    _isDemoMode = false;
    _isBiometricallyAuthenticated = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_demo_mode', false);
    notifyListeners();
  }

  Future<void> _recordPaymentRecord({
    required String paymentId,
    required String? orderId,
    required String? signature,
    required String status,
    String? verificationStatus,
    String? error,
  }) async {
    if (_user == null) return;
    
    final paymentData = {
      'paymentId': paymentId,
      'razorpayPaymentId': paymentId,
      'razorpayOrderId': orderId,
      'razorpaySignature': signature,
      'uid': _user!.uid,
      'userEmail': _user!.email,
      'userName': _user!.displayName,
      'planName': 'Standard Monthly',
      'amount': 25000,
      'currency': 'INR',
      'paymentStatus': status,
      'verificationStatus': verificationStatus ?? 'pending',
      'verifyError': error,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('payments').doc(paymentId).set(paymentData, SetOptions(merge: true));
  }

  Future<bool> activateSubscription({
    required String paymentId,
    required String? orderId,
  }) async {
    if (_user == null) return false;

    try {
      final expiryDate = DateTime.now().add(const Duration(days: 30));
      
      final subscriptionData = {
        'subscriptionStatus': 'active',
        'planStatus': 'active',
        'subscriptionExpiryDate': Timestamp.fromDate(expiryDate),
        'subscriptionExpiry': Timestamp.fromDate(expiryDate),
        'premium': true,
        'isPremium': true,
        'planName': 'Standard Monthly',
        'subscriptionStartDate': FieldValue.serverTimestamp(),
        'activatedAt': FieldValue.serverTimestamp(),
        'razorpayPaymentId': paymentId,
        'lastPaymentId': paymentId,
        'lastOrderId': orderId,
        'paymentStatus': 'success',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(_user!.uid).update(subscriptionData);

      await _recordPaymentRecord(
        paymentId: paymentId,
        orderId: orderId,
        signature: null, // signature might not be available here, but was recorded in verify call
        status: 'success',
        verificationStatus: 'verified',
      );

      AuditLogService.logAction(
        action: "PAYMENT_ADDED",
        screen: "SubscriptionPage",
        newData: subscriptionData,
      );

      if (_isDemoMode) {
        _isDemoMode = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_demo_mode', false);
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Activation error: $e");
      return false;
    }
  }

  Future<bool> verifyPaymentAndActivate({
    required String paymentId,
    required String? orderId,
    required String? signature,
  }) async {
    if (_user == null) return false;
    
    // Record initial success from Razorpay immediately
    await _recordPaymentRecord(
      paymentId: paymentId,
      orderId: orderId,
      signature: signature,
      status: 'success_from_razorpay',
      verificationStatus: 'pending',
    );

    try {
      debugPrint("Payment verification started: $paymentId");
      debugPrint("Calling verify URL: ${AppConfig.verifyPaymentUrl}");

      final response = await http.post(
        Uri.parse(AppConfig.verifyPaymentUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'paymentId': paymentId,
          'orderId': orderId,
          'signature': signature,
        }),
      ).timeout(const Duration(seconds: 20));

      debugPrint("Payment verification response: ${response.statusCode}");
      debugPrint("Payment verification body: ${response.body}");

      if (response.statusCode == 200) {
        return await activateSubscription(paymentId: paymentId, orderId: orderId);
      } else {
        await _recordPaymentRecord(
          paymentId: paymentId,
          orderId: orderId,
          signature: signature,
          status: 'success_from_razorpay',
          verificationStatus: 'failed',
          error: 'HTTP ${response.statusCode}: ${response.body}',
        );
        throw 'Payment received. Verification pending (Server returned ${response.statusCode}).';
      }
    } on TimeoutException {
      await _recordPaymentRecord(
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
        status: 'success_from_razorpay',
        verificationStatus: 'timeout',
        error: 'Verification timed out',
      );
      throw 'Payment received. Verification pending (Timeout).';
    } catch (e) {
      await _recordPaymentRecord(
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
        status: 'success_from_razorpay',
        verificationStatus: 'failed',
        error: e.toString(),
      );
      rethrow;
    } finally {
      debugPrint("Payment verification process completed");
    }
  }
}
