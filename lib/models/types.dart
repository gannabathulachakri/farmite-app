class PricingRow {
  final String id;
  double quantity;
  double price;
  String type; // 'kgs' or 'bags'

  PricingRow({
    required this.id, 
    required this.quantity, 
    required this.price, 
    this.type = 'kgs'
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'quantity': quantity,
        'price': price,
        'type': type,
      };

  factory PricingRow.fromJson(Map<String, dynamic> json) => PricingRow(
        id: json['id'],
        quantity: (json['quantity'] ?? json['kgs'] ?? 0).toDouble(),
        price: (json['price'] ?? 0).toDouble(),
        type: json['type'] ?? 'kgs',
      );
}

class Expense {
  final String id;
  String name;
  double amount;

  Expense({required this.id, required this.name, required this.amount});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        name: json['name'],
        amount: (json['amount'] ?? 0).toDouble(),
      );
}

class VegetableStock {
  final String id;
  final String farmerId;
  final String vegetableId;
  final String date;
  int importedBags;
  int? oldBags;
  int? cages;
  double totalKgs;
  double? oldKgs;
  double? damages;
  List<PricingRow> pricingRows;
  List<PricingRow>? originalPricingRows;
  int soldBags;
  double soldKgs;
  double koliRate;
  double commissionRate;
  List<Expense> expenses;
  final String createdAt;
  String? pdfUrl;

  VegetableStock({
    required this.id,
    required this.farmerId,
    required this.vegetableId,
    required this.date,
    required this.importedBags,
    this.oldBags,
    this.cages,
    required this.totalKgs,
    this.oldKgs,
    this.damages,
    required this.pricingRows,
    this.originalPricingRows,
    required this.soldBags,
    required this.soldKgs,
    this.koliRate = 15.0,
    this.commissionRate = 10.0,
    required this.expenses,
    required this.createdAt,
    this.pdfUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'farmerId': farmerId,
        'vegetableId': vegetableId,
        'date': date,
        'importedBags': importedBags,
        'oldBags': oldBags,
        'cages': cages,
        'totalKgs': totalKgs,
        'oldKgs': oldKgs,
        'damages': damages,
        'pricingRows': pricingRows.map((e) => e.toJson()).toList(),
        'originalPricingRows': originalPricingRows?.map((e) => e.toJson()).toList(),
        'soldBags': soldBags,
        'soldKgs': soldKgs,
        'koliRate': koliRate,
        'commissionRate': commissionRate,
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'createdAt': createdAt,
        'pdfUrl': pdfUrl,
      };

  factory VegetableStock.fromJson(Map<String, dynamic> json) => VegetableStock(
        id: json['id'],
        farmerId: json['farmerId'],
        vegetableId: json['vegetableId'],
        date: json['date'],
        importedBags: json['importedBags'] ?? 0,
        oldBags: json['oldBags'],
        cages: json['cages'],
        totalKgs: (json['totalKgs'] ?? 0).toDouble(),
        oldKgs: json['oldKgs']?.toDouble(),
        damages: json['damages']?.toDouble(),
        pricingRows: (json['pricingRows'] as List<dynamic>?)
                ?.map((e) => PricingRow.fromJson(e))
                .toList() ??
            [],
        originalPricingRows: (json['originalPricingRows'] as List<dynamic>?)
            ?.map((e) => PricingRow.fromJson(e))
            .toList(),
        soldBags: json['soldBags'] ?? 0,
        soldKgs: (json['soldKgs'] ?? 0).toDouble(),
        koliRate: (json['koliRate'] ?? 15.0).toDouble(),
        commissionRate: (json['commissionRate'] ?? 10.0).toDouble(),
        expenses: (json['expenses'] as List<dynamic>?)
                ?.map((e) => Expense.fromJson(e))
                .toList() ??
            [],
        createdAt: json['createdAt'] ?? '',
        pdfUrl: json['pdfUrl'],
      );
}

class Farmer {
  final String id;
  String name;
  String? phone;
  final String createdAt;

  Farmer({
    required this.id,
    required this.name,
    this.phone,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'createdAt': createdAt,
      };

  factory Farmer.fromJson(Map<String, dynamic> json) => Farmer(
        id: json['id'],
        name: json['name'],
        phone: json['phone'],
        createdAt: json['createdAt'] ?? '',
      );
}

class VegetableInfo {
  final String id;
  final String nameEn;
  final String nameTe;
  final String emoji;

  VegetableInfo({
    required this.id,
    required this.nameEn,
    required this.nameTe,
    required this.emoji,
  });
}
