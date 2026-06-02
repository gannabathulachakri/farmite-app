import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BillSettingsProvider with ChangeNotifier {
  String _businessName = "Farmite VEGETABLES & ONIONS\n- BHIMAVARAM";
  String _proprietorName = "Prop. Satyababu";
  String _phoneNumber = "9989072773";
  int _monthlyEditCount = 0;
  String _monthKey = "";
  bool _supportRequested = false;
  bool _extraEditGranted = false;
  bool _isLoading = false;
  bool _isDemo = false;

  String get businessName => _isDemo ? "XXXXX Vegetables" : _businessName;
  String get proprietorName => _isDemo ? "Ramesh Demo\nXXXXX Market Road" : _proprietorName;
  String get phoneNumber => _isDemo ? "XXXXXXXX" : _phoneNumber;
  int get monthlyEditCount => _monthlyEditCount;
  bool get supportRequested => _supportRequested;
  bool get extraEditGranted => _extraEditGranted;
  bool get isLoading => _isLoading;

  void setDemoMode(bool val) {
    _isDemo = val;
    notifyListeners();
  }

  String get _currentMonthKey {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  bool get canEdit {
    if (_monthKey != _currentMonthKey) return true;
    return _monthlyEditCount < 2 || _extraEditGranted;
  }

  BillSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _businessName = prefs.getString('bill_business_name') ?? "Farmite VEGETABLES & ONIONS\n- BHIMAVARAM";
    _proprietorName = prefs.getString('bill_proprietor_name') ?? "Prop. Satyababu";
    _phoneNumber = prefs.getString('bill_phone_number') ?? "9989072773";
    notifyListeners();

    if (_isDemo) return;

    // Also load from Firebase if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('bill_header')
            .get();
            
        if (doc.exists) {
          final data = doc.data()!;
          _businessName = data['businessName'] ?? _businessName;
          _proprietorName = data['proprietorName'] ?? _proprietorName;
          _phoneNumber = data['mobileNumber'] ?? _phoneNumber;
          _monthlyEditCount = data['monthlyEditCount'] ?? 0;
          _monthKey = data['monthKey'] ?? "";
          _supportRequested = data['supportRequested'] ?? false;
          _extraEditGranted = data['extraEditGranted'] ?? false;

          // Reset count if it's a new month
          if (_monthKey != _currentMonthKey) {
            _monthlyEditCount = 0;
            _monthKey = _currentMonthKey;
            _extraEditGranted = false;
            _supportRequested = false;
          }
          
          await prefs.setString('bill_business_name', _businessName);
          await prefs.setString('bill_proprietor_name', _proprietorName);
          await prefs.setString('bill_phone_number', _phoneNumber);
          notifyListeners();
        } else {
          // Check global settings as fallback for migration
          final globalDoc = await FirebaseFirestore.instance.collection('settings').doc('bill_header').get();
          if (globalDoc.exists) {
             final data = globalDoc.data()!;
             _businessName = data['businessName'] ?? _businessName;
             _proprietorName = data['proprietorName'] ?? _proprietorName;
             _phoneNumber = data['mobileNumber'] ?? _phoneNumber;
             notifyListeners();
          }
        }
      } catch (e) {
        debugPrint("Error loading bill settings from Firebase: $e");
      }
    }
  }

  Future<bool> saveToFirebase({
    required String businessName,
    required String proprietorName,
    required String phoneNumber,
  }) async {
    if (!canEdit || _isDemo) return false;

    _isLoading = true;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final currentMonth = _currentMonthKey;
      
      int newCount = _monthlyEditCount;
      if (_monthKey != currentMonth) {
        newCount = 1;
      } else {
        newCount++;
      }

      final settingsData = {
        'businessName': businessName,
        'proprietorName': proprietorName,
        'mobileNumber': phoneNumber,
        'monthKey': currentMonth,
        'monthlyEditCount': newCount,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'companyId': user.uid,
        'supportRequested': false,
        'extraEditGranted': false, // Consume the extra edit if it was granted
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('bill_header')
          .set(settingsData, SetOptions(merge: true));

      _businessName = businessName;
      _proprietorName = proprietorName;
      _phoneNumber = phoneNumber;
      _monthlyEditCount = newCount;
      _monthKey = currentMonth;
      _supportRequested = false;
      _extraEditGranted = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bill_business_name', businessName);
      await prefs.setString('bill_proprietor_name', proprietorName);
      await prefs.setString('bill_phone_number', phoneNumber);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error saving bill settings to Firebase: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> requestSupport(String reason) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      await FirebaseFirestore.instance.collection('support_requests').add({
        'userId': user.uid,
        'reason': reason,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'type': 'bill_header_unlock',
      });

      // Also mark in user settings that support was requested
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('bill_header')
          .set({'supportRequested': true}, SetOptions(merge: true));

      _supportRequested = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error requesting support: $e");
      return false;
    }
  }

  Future<void> updateSettings({
    String? businessName,
    String? proprietorName,
    String? phoneNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (businessName != null) {
      _businessName = businessName;
      await prefs.setString('bill_business_name', businessName);
    }
    if (proprietorName != null) {
      _proprietorName = proprietorName;
      await prefs.setString('bill_proprietor_name', proprietorName);
    }
    if (phoneNumber != null) {
      _phoneNumber = phoneNumber;
      await prefs.setString('bill_phone_number', phoneNumber);
    }
    notifyListeners();
  }
}
