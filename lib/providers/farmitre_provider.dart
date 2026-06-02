import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/types.dart';
import '../services/audit_log_service.dart';

class FarmitreProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Farmer> _farmers = [];
  List<VegetableStock> _stocks = [];
  bool _isDemo = false;
  final Uuid _uuid = const Uuid();
  DateTime? _lastRefresh;

  List<Farmer> get farmers => _farmers;
  List<VegetableStock> get stocks => _stocks;
  bool get isDemo => _isDemo;

  String? get _uid => _auth.currentUser?.uid;

  FarmitreProvider() {
    _loadData();
    _auth.authStateChanges().listen((user) {
      if (user != null && !_isDemo) {
        refreshDataFromFirestore(user.uid);
      } else if (user == null) {
        _farmers = [];
        _stocks = [];
        notifyListeners();
      }
    });
  }

  void setDemoMode(bool val) {
    _isDemo = val;
    if (_isDemo) {
      _loadDemoData();
    } else {
      _loadData();
    }
  }

  void _loadDemoData() {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final yesterdayIso = now.subtract(const Duration(days: 1)).toIso8601String();
    
    _farmers = [
      Farmer(id: 'demo-f1', name: 'Ramesh Demo Farmer', phone: '9876543210', createdAt: yesterdayIso),
      Farmer(id: 'demo-f2', name: 'Suresh Demo Farmer', phone: '8765432109', createdAt: yesterdayIso),
      Farmer(id: 'demo-f3', name: 'Kumar Demo Farmer', phone: '7654321098', createdAt: yesterdayIso),
    ];

    _stocks = [
      // Ramesh - Tomato (Completed)
      VegetableStock(
        id: 'demo-s1',
        farmerId: 'demo-f1',
        vegetableId: 'tomatos',
        date: yesterdayIso,
        importedBags: 10,
        totalKgs: 250,
        pricingRows: [
          PricingRow(id: 'r1', quantity: 250, price: 25, type: 'kgs'),
        ],
        soldBags: 10,
        soldKgs: 250,
        koliRate: 15,
        commissionRate: 10,
        expenses: [
          Expense(id: 'e1', name: 'Transport', amount: 500),
          Expense(id: 'e2', name: 'Other Charges', amount: 100),
        ],
        createdAt: yesterdayIso,
      ),
      // Suresh - Onion (Partially Sold / Pending)
      VegetableStock(
        id: 'demo-s2',
        farmerId: 'demo-f2',
        vegetableId: 'ulli_payalu',
        date: nowIso,
        importedBags: 20,
        totalKgs: 500,
        pricingRows: [
          PricingRow(id: 'r3', quantity: 300, price: 30, type: 'kgs'),
        ],
        soldBags: 12,
        soldKgs: 300,
        koliRate: 15,
        commissionRate: 10,
        expenses: [
          Expense(id: 'e3', name: 'Transport', amount: 800),
        ],
        createdAt: nowIso,
      ),
      // Kumar - Potato (Completed)
      VegetableStock(
        id: 'demo-s3',
        farmerId: 'demo-f3',
        vegetableId: 'bangala_dumpalu',
        date: yesterdayIso,
        importedBags: 15,
        totalKgs: 300,
        pricingRows: [
          PricingRow(id: 'r4', quantity: 300, price: 20, type: 'kgs'),
        ],
        soldBags: 15,
        soldKgs: 300,
        koliRate: 15,
        commissionRate: 10,
        expenses: [
          Expense(id: 'e4', name: 'Hire', amount: 400),
        ],
        createdAt: yesterdayIso,
      ),
      // Ramesh - Green Chilli (New arrival)
      VegetableStock(
        id: 'demo-s4',
        farmerId: 'demo-f1',
        vegetableId: 'pachi_mirapa',
        date: nowIso,
        importedBags: 5,
        totalKgs: 100,
        pricingRows: [
          PricingRow(id: 'r5', quantity: 100, price: 45, type: 'kgs'),
        ],
        soldBags: 5,
        soldKgs: 100,
        koliRate: 15,
        commissionRate: 10,
        expenses: [],
        createdAt: nowIso,
      ),
    ];
    notifyListeners();
  }

  Future<void> refreshData({String? uid, bool force = false}) async {
    if (!force && _lastRefresh != null) {
      if (DateTime.now().difference(_lastRefresh!) < const Duration(seconds: 30)) {
        return;
      }
    }
    
    final targetUid = uid ?? _uid;
    if (targetUid != null && !_isDemo) {
      AuditLogService.logAction(
        action: "DASHBOARD_REFRESH",
        screen: "DashboardPage",
        status: "success",
      );
      await refreshDataFromFirestore(targetUid);
      _lastRefresh = DateTime.now();
    } else {
      await _loadData();
    }
  }

  Future<void> refreshDataFromFirestore(String uid) async {
    debugPrint("Calling database for farmers and stocks...");
    try {
      final farmersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('farmers')
          .get(const GetOptions(source: Source.server));

      _farmers = farmersSnapshot.docs
          .map((doc) => Farmer.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
      debugPrint("Database refreshed: ${_farmers.length} farmers records");

      final stocksSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('bills')
          .get(const GetOptions(source: Source.server));

      _stocks = stocksSnapshot.docs
          .map((doc) => VegetableStock.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
      debugPrint("Database refreshed: ${_stocks.length} bills records");

      notifyListeners();
      await _saveFarmers();
      await _saveStocks();
    } on FirebaseException catch (e) {
      debugPrint("Firestore error: ${e.code} - ${e.message}");
      if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        throw 'Internet connection problem. Please check your network and try again.';
      }
      rethrow;
    } catch (e) {
      debugPrint("Database refresh error: $e");
      if (e.toString().contains('UnknownHostException') || e.toString().contains('Unable to resolve host')) {
        throw 'Internet connection problem. Please check your network and try again.';
      }
      rethrow;
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final farmersJson = prefs.getString('farmitre_farmers');
    if (farmersJson != null) {
      final List decoded = json.decode(farmersJson);
      _farmers = decoded.map((e) => Farmer.fromJson(e)).toList();
    } else {
      _farmers = [];
    }

    final stocksJson = prefs.getString('farmitre_stocks');
    if (stocksJson != null) {
      final List decoded = json.decode(stocksJson);
      _stocks = decoded.map((e) => VegetableStock.fromJson(e)).toList();
    } else {
      _stocks = [];
    }
    
    _cleanOldData();
    notifyListeners();
  }

  Future<void> _saveFarmers() async {
    if (_isDemo) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('farmitre_farmers', json.encode(_farmers.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> _saveStocks() async {
    if (_isDemo) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('farmitre_stocks', json.encode(_stocks.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  void _cleanOldData() {
    final fortyEightHoursAgo = DateTime.now().subtract(const Duration(hours: 48));
    
    bool changed = false;
    
    final oldStockIds = _stocks.where((s) {
      if (s.createdAt.isEmpty) return true;
      try {
        final date = DateTime.parse(s.createdAt);
        return date.isBefore(fortyEightHoursAgo);
      } catch (e) {
        return true;
      }
    }).map((s) => s.id).toList();

    if (oldStockIds.isNotEmpty) {
      _stocks.removeWhere((s) => oldStockIds.contains(s.id));
      changed = true;
    }

    final oldFarmerIds = _farmers.where((f) {
      if (f.createdAt.isEmpty) return true;
      try {
        final date = DateTime.parse(f.createdAt);
        return date.isBefore(fortyEightHoursAgo);
      } catch (e) {
        return true;
      }
    }).map((f) => f.id).toList();

    if (oldFarmerIds.isNotEmpty) {
      _farmers.removeWhere((f) => oldFarmerIds.contains(f.id));
      changed = true;
    }

    if (changed) {
      _saveFarmers();
      _saveStocks();
    }
  }

  Farmer addFarmer(String name, [String? phone]) {
    final newFarmer = Farmer(
      id: _uuid.v4(),
      name: name,
      phone: phone,
      createdAt: DateTime.now().toIso8601String(),
    );
    _farmers.add(newFarmer);
    _saveFarmers();

    if (_uid != null && !_isDemo) {
      _firestore
          .collection('users')
          .doc(_uid)
          .collection('farmers')
          .doc(newFarmer.id)
          .set(newFarmer.toJson())
          .then((_) {
        AuditLogService.logAction(
          action: "ADD_FARMER",
          screen: "FarmersPage",
          newData: newFarmer.toJson(),
        );
      }).catchError((e) {
        AuditLogService.logAction(
          action: "ADD_FARMER",
          screen: "FarmersPage",
          status: "failed",
          errorMessage: e.toString(),
        );
      });
    }

    return newFarmer;
  }

  void updateFarmer(String id, {String? name, String? phone}) {
    final index = _farmers.indexWhere((f) => f.id == id);
    if (index != -1) {
      final oldFarmer = _farmers[index].toJson();
      if (name != null) _farmers[index].name = name;
      if (phone != null) _farmers[index].phone = phone;
      final newFarmer = _farmers[index].toJson();
      _saveFarmers();

      if (_uid != null && !_isDemo) {
        _firestore
            .collection('users')
            .doc(_uid)
            .collection('farmers')
            .doc(id)
            .update({
          if (name != null) 'name': name,
          if (phone != null) 'phone': phone,
        }).then((_) {
          AuditLogService.logAction(
            action: "EDIT_FARMER",
            screen: "FarmersPage",
            oldData: oldFarmer,
            newData: newFarmer,
          );
        }).catchError((e) {
          AuditLogService.logAction(
            action: "EDIT_FARMER",
            screen: "FarmersPage",
            status: "failed",
            errorMessage: e.toString(),
          );
        });
      }
    }
  }

  void deleteFarmer(String id) {
    final farmer = _farmers.firstWhere((f) => f.id == id, orElse: () => Farmer(id: '', name: '', createdAt: ''));
    _farmers.removeWhere((f) => f.id == id);
    _stocks.removeWhere((s) => s.farmerId == id);
    _saveFarmers();
    _saveStocks();

    if (_uid != null && !_isDemo) {
      AuditLogService.logAction(
        action: "DELETE_FARMER",
        screen: "FarmersPage",
        oldData: farmer.toJson(),
      );
      _firestore
          .collection('users')
          .doc(_uid)
          .collection('farmers')
          .doc(id)
          .delete();
      
      // Also delete related bills in firestore
      _firestore
          .collection('users')
          .doc(_uid)
          .collection('bills')
          .where('farmerId', isEqualTo: id)
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.delete();
        }
      });
    }
  }

  VegetableStock addStock({
    required String farmerId,
    required String vegetableId,
    required String date,
    required int importedBags,
    int? oldBags,
    int? cages,
    required double totalKgs,
    double? oldKgs,
    double? damages,
    required List<PricingRow> pricingRows,
    List<PricingRow>? originalPricingRows,
    required int soldBags,
    required double soldKgs,
    required double koliRate,
    required double commissionRate,
    required List<Expense> expenses,
  }) {
    final newStock = VegetableStock(
      id: _uuid.v4(),
      farmerId: farmerId,
      vegetableId: vegetableId,
      date: date,
      importedBags: importedBags,
      oldBags: oldBags,
      cages: cages,
      totalKgs: totalKgs,
      oldKgs: oldKgs,
      damages: damages,
      pricingRows: pricingRows,
      originalPricingRows: originalPricingRows,
      soldBags: soldBags,
      soldKgs: soldKgs,
      koliRate: koliRate,
      commissionRate: commissionRate,
      expenses: expenses,
      createdAt: DateTime.now().toIso8601String(),
    );
    _stocks.add(newStock);
    _saveStocks();

    if (_uid != null && !_isDemo) {
      _firestore
          .collection('users')
          .doc(_uid)
          .collection('bills')
          .doc(newStock.id)
          .set(newStock.toJson())
          .then((_) {
        AuditLogService.logAction(
          action: "CREATE_BILL",
          screen: "StockEntryPage",
          newData: newStock.toJson(),
        );
      }).catchError((e) {
        AuditLogService.logAction(
          action: "CREATE_BILL",
          screen: "StockEntryPage",
          status: "failed",
          errorMessage: e.toString(),
        );
      });
    }

    return newStock;
  }

  void updateStock(String id, {
    String? farmerId,
    String? vegetableId,
    String? date,
    int? importedBags,
    int? oldBags,
    int? cages,
    double? totalKgs,
    double? oldKgs,
    double? damages,
    List<PricingRow>? pricingRows,
    List<PricingRow>? originalPricingRows,
    int? soldBags,
    double? soldKgs,
    double? koliRate,
    double? commissionRate,
    List<Expense>? expenses,
  }) {
    final index = _stocks.indexWhere((s) => s.id == id);
    if (index != -1) {
      final stock = _stocks[index];
      final oldStock = stock.toJson();
      final updatedStock = VegetableStock(
        id: stock.id,
        farmerId: farmerId ?? stock.farmerId,
        vegetableId: vegetableId ?? stock.vegetableId,
        date: date ?? stock.date,
        importedBags: importedBags ?? stock.importedBags,
        oldBags: oldBags ?? stock.oldBags,
        cages: cages ?? stock.cages,
        totalKgs: totalKgs ?? stock.totalKgs,
        oldKgs: oldKgs ?? stock.oldKgs,
        damages: damages ?? stock.damages,
        pricingRows: pricingRows ?? stock.pricingRows,
        originalPricingRows: originalPricingRows ?? stock.originalPricingRows,
        soldBags: soldBags ?? stock.soldBags,
        soldKgs: soldKgs ?? stock.soldKgs,
        koliRate: koliRate ?? stock.koliRate,
        commissionRate: commissionRate ?? stock.commissionRate,
        expenses: expenses ?? stock.expenses,
        createdAt: stock.createdAt,
      );
      _stocks[index] = updatedStock;
      _saveStocks();

      if (_uid != null && !_isDemo) {
        _firestore
            .collection('users')
            .doc(_uid)
            .collection('bills')
            .doc(id)
            .set(updatedStock.toJson())
            .then((_) {
          AuditLogService.logAction(
            action: "EDIT_BILL",
            screen: "StockEntryPage",
            oldData: oldStock,
            newData: updatedStock.toJson(),
          );
        }).catchError((e) {
          AuditLogService.logAction(
            action: "EDIT_BILL",
            screen: "StockEntryPage",
            status: "failed",
            errorMessage: e.toString(),
          );
        });
      }
    }
  }

  void deleteStock(String id) {
    final stock = _stocks.firstWhere((s) => s.id == id, orElse: () => VegetableStock(id: '', farmerId: '', vegetableId: '', date: '', importedBags: 0, totalKgs: 0, pricingRows: [], soldBags: 0, soldKgs: 0, expenses: [], createdAt: ''));
    _stocks.removeWhere((s) => s.id == id);
    _saveStocks();

    if (_uid != null && !_isDemo) {
      AuditLogService.logAction(
        action: "DELETE_BILL",
        screen: "BillsPage",
        oldData: stock.id.isEmpty ? null : stock.toJson(),
      );
      _firestore
          .collection('users')
          .doc(_uid)
          .collection('bills')
          .doc(id)
          .delete();
    }
  }

  void deleteStocks(List<String> ids) {
    _stocks.removeWhere((s) => ids.contains(s.id));
    _saveStocks();

    if (_uid != null && !_isDemo) {
      for (var id in ids) {
        _firestore
            .collection('users')
            .doc(_uid)
            .collection('bills')
            .doc(id)
            .delete();
      }
    }
  }

  List<VegetableStock> getFarmerStocks(String farmerId) {
    return _stocks.where((s) => s.farmerId == farmerId).toList();
  }

  double calculateStockTotal(VegetableStock stock) {
    double salesTotal = stock.pricingRows.fold(0, (acc, row) => acc + (row.quantity * row.price));
    double commissionTotal = (salesTotal * (stock.commissionRate / 100)).roundToDouble();
    double importChargeTotal = (stock.importedBags - (stock.oldBags ?? 0)) * stock.koliRate;
    double totalExpenses = stock.expenses.fold(0.0, (acc, exp) => acc + exp.amount) + commissionTotal + importChargeTotal;
    return salesTotal - totalExpenses;
  }
}
