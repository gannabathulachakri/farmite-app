import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

class AuditLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  static String? _cachedDeviceInfo;
  static String? _cachedAppVersion;

  static Future<void> _initInfo() async {
    if (_cachedDeviceInfo == null) {
      try {
        if (kIsWeb) {
          _cachedDeviceInfo = "Web Browser";
        } else if (Platform.isAndroid) {
          AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
          _cachedDeviceInfo = "${androidInfo.manufacturer} ${androidInfo.model} (Android ${androidInfo.version.release})";
        } else if (Platform.isIOS) {
          IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
          _cachedDeviceInfo = "${iosInfo.name} ${iosInfo.model} (iOS ${iosInfo.systemVersion})";
        } else {
          _cachedDeviceInfo = Platform.operatingSystem;
        }
      } catch (e) {
        _cachedDeviceInfo = "Unknown Device";
      }
    }

    if (_cachedAppVersion == null) {
      try {
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        _cachedAppVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
      } catch (e) {
        _cachedAppVersion = "Unknown Version";
      }
    }
  }

  static Future<void> logAction({
    required String action,
    required String screen,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
    String status = "success",
    String? errorMessage,
  }) async {
    try {
      await _initInfo();
      
      final User? user = _auth.currentUser;
      final String userId = user?.uid ?? "anonymous";
      final String userEmail = user?.email ?? "N/A";
      final String userName = user?.displayName ?? "N/A";

      await _firestore.collection('audit_logs').add({
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'action': action,
        'screen': screen,
        'oldData': oldData,
        'newData': newData,
        'status': status,
        'errorMessage': errorMessage ?? "",
        'deviceInfo': _cachedDeviceInfo,
        'appVersion': _cachedAppVersion,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error logging action: $e");
      // Fail silently as per requirement
    }
  }
}
