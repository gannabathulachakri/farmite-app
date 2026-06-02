import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:farmitre_flutter/l10n/app_localizations.dart';
import 'package:farmitre_flutter/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/farmitre_provider.dart';
import '../models/types.dart';
import '../utils/constants.dart';
import '../widgets/premium_guard.dart';

class StockEntryScreen extends StatefulWidget {
  const StockEntryScreen({super.key});

  @override
  State<StockEntryScreen> createState() => _StockEntryScreenState();
}

class _StockEntryScreenState extends State<StockEntryScreen> {
  VegetableStock? _editingStock;
  bool _isInitialized = false;

  String? _selectedFarmerId;
  String? _selectedVegetableId;
  String _vegetableSearch = '';
  DateTime _selectedDate = DateTime.now();
  double _lastRate = 0;

  final _oldBagsController = TextEditingController();
  final _newBagsController = TextEditingController();
  final _cagesController = TextEditingController();
  final _oldKgsController = TextEditingController();
  final _newKgsController = TextEditingController();
  final _damagesController = TextEditingController();
  final _soldBagsController = TextEditingController();

  final _koliRateController = TextEditingController();
  final _commissionRateController = TextEditingController();
  final _transportController = TextEditingController();

  List<PricingRow> _pricingRows = [];
  List<Expense> _expenses = [];
  final Map<String, TextEditingController> _expenseControllers = {};
  final Map<String, FocusNode> _quantityFocusNodes = {};
  final Map<String, FocusNode> _priceFocusNodes = {};
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};
  
  final FocusNode _oldBagsFocus = FocusNode();
  final FocusNode _newBagsFocus = FocusNode();
  final FocusNode _cagesFocus = FocusNode();
  final FocusNode _oldKgsFocus = FocusNode();
  final FocusNode _newKgsFocus = FocusNode();
  final FocusNode _damagesFocus = FocusNode();
  final FocusNode _soldBagsFocus = FocusNode();

  List<PricingRow>? _editedPricingRows;

  List<PricingRow>? _originalPricingRows;
  final ScrollController _scrollController = ScrollController();

  final _uuid = const Uuid();
  int _currentStep = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is VegetableStock) {
        _editingStock = args;
        _populateFields(args);
      } else {
        _addPricingRow();
      }
      _isInitialized = true;
    }
  }

  void _populateFields(VegetableStock stock) {
    _selectedFarmerId = stock.farmerId;
    _selectedVegetableId = stock.vegetableId;
    try {
      final parsedDate = DateTime.parse(stock.date);
      _selectedDate = parsedDate.isAfter(DateTime.now()) ? DateTime.now() : parsedDate;
    } catch (_) {
      _selectedDate = DateTime.now();
    }
    
    _oldBagsController.text = (stock.oldBags ?? 0).toString();
    _newBagsController.text = (stock.importedBags - (stock.oldBags ?? 0)).toString();
    _cagesController.text = stock.cages == null ? '' : stock.cages.toString();
    _oldKgsController.text = (stock.oldKgs ?? 0).toString();
    _newKgsController.text = (stock.totalKgs - (stock.oldKgs ?? 0)).toString();
    _damagesController.text = stock.damages == null ? '' : stock.damages.toString();
    _soldBagsController.text = stock.soldBags.toString();
    
    _commissionRateController.text = stock.commissionRate == 0 ? '' : stock.commissionRate.round().toString();
    _koliRateController.text = stock.koliRate == 0 ? '' : stock.koliRate.toInt().toString();

    _pricingRows = List.from(stock.pricingRows);
    _originalPricingRows = stock.originalPricingRows != null ? List.from(stock.originalPricingRows!) : null;
    _expenses = List.from(stock.expenses);

    // Populate Transport and remove from general expenses list
    final transportIdx = _expenses.indexWhere((e) => e.name == "Transport" || e.name == "Hire");
    if (transportIdx != -1) {
      final transportExp = _expenses.removeAt(transportIdx);
      _transportController.text = transportExp.amount == 0 ? '' : transportExp.amount.toInt().toString();
    } else {
      _transportController.clear();
    }

    for (var exp in _expenses) {
      _expenseControllers[exp.id] = TextEditingController(text: exp.amount == 0 ? '' : exp.amount.toInt().toString());
    }

    for (var row in _pricingRows) {
      _quantityFocusNodes[row.id] = FocusNode();
      _priceFocusNodes[row.id] = FocusNode();
      _quantityControllers[row.id] = TextEditingController(text: row.quantity == 0 ? '' : row.quantity.toString());
      _priceControllers[row.id] = TextEditingController(text: row.price == 0 ? '' : row.price.toString());
      if (row.price > 0) _lastRate = row.price;
    }
  }

  @override
  void dispose() {
    _oldBagsController.dispose();
    _newBagsController.dispose();
    _cagesController.dispose();
    _oldKgsController.dispose();
    _newKgsController.dispose();
    _damagesController.dispose();
    _soldBagsController.dispose();
    _koliRateController.dispose();
    _commissionRateController.dispose();
    _transportController.dispose();
    for (var node in _quantityFocusNodes.values) {
      node.dispose();
    }
    for (var node in _priceFocusNodes.values) {
      node.dispose();
    }
    for (var c in _quantityControllers.values) {
      c.dispose();
    }
    for (var c in _priceControllers.values) {
      c.dispose();
    }
    for (var c in _expenseControllers.values) {
      c.dispose();
    }
    _oldBagsFocus.dispose();
    _newBagsFocus.dispose();
    _cagesFocus.dispose();
    _oldKgsFocus.dispose();
    _newKgsFocus.dispose();
    _damagesFocus.dispose();
    _soldBagsFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addPricingRow({bool skipIfLastEmpty = false}) {
    _originalPricingRows = null; // Reset original if form changed
    if (skipIfLastEmpty && _pricingRows.isNotEmpty) {
      final last = _pricingRows.last;
      if (last.quantity == 0 && last.price == 0) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _quantityFocusNodes[last.id]?.requestFocus();
        });
        return;
      }
    }

    final id = _uuid.v4();
    final quantityNode = FocusNode();
    final priceNode = FocusNode();
    final quantityCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    setState(() {
      _pricingRows.add(PricingRow(id: id, quantity: 0, price: 0, type: 'kgs'));
      _quantityFocusNodes[id] = quantityNode;
      _priceFocusNodes[id] = priceNode;
      _quantityControllers[id] = quantityCtrl;
      _priceControllers[id] = priceCtrl;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        quantityNode.requestFocus();
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addExpense(String name) {
    final id = _uuid.v4();
    final controller = TextEditingController();
    setState(() {
      _expenses.add(Expense(id: id, name: name, amount: 0));
      _expenseControllers[id] = controller;
    });
  }

  void _resetForm() {
    for (var node in _quantityFocusNodes.values) {
      node.dispose();
    }
    for (var node in _priceFocusNodes.values) {
      node.dispose();
    }
    for (var c in _quantityControllers.values) {
      c.dispose();
    }
    for (var c in _priceControllers.values) {
      c.dispose();
    }
    for (var c in _expenseControllers.values) {
      c.dispose();
    }
    _quantityFocusNodes.clear();
    _priceFocusNodes.clear();
    _quantityControllers.clear();
    _priceControllers.clear();
    _expenseControllers.clear();

    setState(() {
      _editingStock = null;
      _selectedFarmerId = null;
      _selectedVegetableId = null;
      _vegetableSearch = '';
      _selectedDate = DateTime.now();
      _oldBagsController.clear();
      _newBagsController.clear();
      _cagesController.clear();
      _oldKgsController.clear();
      _newKgsController.clear();
      _damagesController.clear();
      _soldBagsController.clear();
      _koliRateController.clear();
      _commissionRateController.clear();
      _transportController.clear();
      _editedPricingRows = null;
      _pricingRows = [];
      _expenses = [];
      _currentStep = 0;
    });
    _addPricingRow();
  }

  void _nextStep() {
    final t = AppLocalizations.of(context)!;
    if (_currentStep == 0 && (_selectedFarmerId == null || _selectedVegetableId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.selectFarmer), behavior: SnackBarBehavior.floating));
      return;
    }
    if (_currentStep < 5) {
      setState(() {
        _currentStep++;
      });
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });
    }
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Row(
        children: List.generate(6, (index) {
          bool isActive = index <= _currentStep;
          bool isCurrent = index == _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCurrent 
                      ? Theme.of(context).colorScheme.primary 
                      : (isActive ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5) : Colors.grey[300]),
                    shape: BoxShape.circle,
                    boxShadow: isCurrent ? [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ] : null,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (index < 5)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: index < _currentStep 
                        ? Theme.of(context).colorScheme.primary 
                        : Colors.grey[300],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  int get _oldBags => int.tryParse(_oldBagsController.text) ?? 0;
  int get _newBags => int.tryParse(_newBagsController.text) ?? 0;
  int get _cages => int.tryParse(_cagesController.text) ?? 0;
  int get _oldKgs => int.tryParse(_oldKgsController.text) ?? 0;
  int get _newKgs => int.tryParse(_newKgsController.text) ?? 0;
  double get _damages => double.tryParse(_damagesController.text) ?? 0;
  int get _soldBags => int.tryParse(_soldBagsController.text) ?? 0;
  int get _koliRate => int.tryParse(_koliRateController.text) ?? 0;
  int get _commissionRate => int.tryParse(_commissionRateController.text) ?? 0;
  int get _transportAmount => int.tryParse(_transportController.text) ?? 0;

  int get _totalImportedBags => _oldBags + _newBags;
  int get _totalImportedKgs => _oldKgs + _newKgs;

  double get _totalSoldKgs => (_editedPricingRows ?? _pricingRows).where((r) => r.type == 'kgs').fold(0.0, (sum, row) => sum + row.quantity);

  int get _remainingBags => _totalImportedBags - _soldBags;
  double get _remainingKgs => _totalImportedKgs.toDouble() - _totalSoldKgs;

  double get _totalSalesAmount {
    final rows = _editedPricingRows ?? _pricingRows;
    double total = 0;
    for (var row in rows) {
      double price = row.price;
      if (price == 0 && _priceControllers[row.id]?.text.isEmpty == true) {
        price = _lastRate;
      }
      total += row.quantity * price;
    }
    return total;
  }
  
  int get _totalCommission => ((_totalSalesAmount * (_commissionRate / 100))).round();
  int get _totalKoli => (_totalImportedBags - _oldBags) * _koliRate;
  int get _totalExpensesAmount => _expenses.fold(0, (sum, exp) => sum + exp.amount.toInt()) + _totalCommission + _totalKoli + _transportAmount;
  int get _grandTotal => _totalSalesAmount.round() - _totalExpensesAmount;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _handleSubmit() {
    final t = AppLocalizations.of(context)!;

    if (_selectedFarmerId == null || _selectedVegetableId == null) return;

    if (_soldBags > _totalImportedBags || _totalSoldKgs > _totalImportedKgs) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.stockLimitError), behavior: SnackBarBehavior.floating));
      return;
    }

    if (_pricingRows.isEmpty || (_totalSoldKgs <= 0 && _soldBags <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.pricingError), behavior: SnackBarBehavior.floating));
      return;
    }

    final farmitre = Provider.of<FarmitreProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final billSaleSummary = (_editedPricingRows ?? _pricingRows).map((row) {
      double price = row.price;
      if (price == 0 && _priceControllers[row.id]?.text.isEmpty == true) {
        price = _lastRate;
      }
      return PricingRow(
        id: row.id,
        quantity: row.quantity,
        price: price,
        type: row.type,
      );
    }).toList();

    if (_editingStock != null) {
      farmitre.updateStock(
        _editingStock!.id,
        farmerId: _selectedFarmerId!,
        vegetableId: _selectedVegetableId!,
        date: _selectedDate.toIso8601String(),
        importedBags: _totalImportedBags,
        oldBags: _oldBags,
        cages: _cages,
        totalKgs: _totalImportedKgs.toDouble(),
        oldKgs: _oldKgs.toDouble(),
        damages: _damages,
        pricingRows: List.from(billSaleSummary),
        originalPricingRows: _originalPricingRows,
        soldBags: _soldBags,
        soldKgs: _totalSoldKgs.toDouble(),
        koliRate: _koliRate.toDouble(),
        commissionRate: _commissionRate.toDouble(),
        expenses: [
          ..._expenses,
          if (_transportAmount > 0) Expense(id: _uuid.v4(), name: "Transport", amount: _transportAmount.toDouble()),
        ],
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.updateSuccess), behavior: SnackBarBehavior.floating));
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        _resetForm();
      }
    } else {
      farmitre.addStock(
        farmerId: _selectedFarmerId!,
        vegetableId: _selectedVegetableId!,
        date: _selectedDate.toIso8601String(),
        importedBags: _totalImportedBags,
        oldBags: _oldBags,
        cages: _cages,
        totalKgs: _totalImportedKgs.toDouble(),
        oldKgs: _oldKgs.toDouble(),
        damages: _damages,
        pricingRows: List.from(billSaleSummary),
        originalPricingRows: _originalPricingRows,
        soldBags: _soldBags,
        soldKgs: _totalSoldKgs.toDouble(),
        koliRate: _koliRate.toDouble(),
        commissionRate: _commissionRate.toDouble(),
        expenses: [
          ..._expenses,
          if (_transportAmount > 0) Expense(id: _uuid.v4(), name: "Transport", amount: _transportAmount.toDouble()),
        ],
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.saveSuccess), behavior: SnackBarBehavior.floating));
      _resetForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final farmitre = Provider.of<FarmitreProvider>(context);
    final isTe = Localizations.localeOf(context).languageCode == 'te';

    if (farmitre.farmers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(t.stockEntry, style: const TextStyle(fontWeight: FontWeight.bold))),
        body: _buildEmptyFarmersState(context, t),
      );
    }

    final filteredVegetables = vegetables.where((v) => 
      v.nameEn.toLowerCase().contains(_vegetableSearch.toLowerCase()) || 
      v.nameTe.toLowerCase().contains(_vegetableSearch.toLowerCase())
    ).toList();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(_editingStock != null ? t.editRecord : t.stockEntry, style: const TextStyle(fontWeight: FontWeight.w800)),
              titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
            ),
          ),
          SliverToBoxAdapter(child: _buildStepIndicator()),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                _buildCurrentStep(t, filteredVegetables, isTe),
                const SizedBox(height: 140),
              ]),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomNavigation(t, isTe),
    );
  }

  Widget _buildCurrentStep(AppLocalizations t, List<VegetableInfo> filteredVegetables, bool isTe) {
    switch (_currentStep) {
      case 0: return _buildStep1(t, filteredVegetables, isTe);
      case 1: return _buildStep2(t);
      case 2: return _buildStep3(t);
      case 3: return _buildStep4(t);
      case 4: return _buildStep5(t, isTe);
      case 5: return _buildStep6(t, isTe);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildStep1(AppLocalizations t, List<VegetableInfo> filteredVegetables, bool isTe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(t.step1, '👨‍🌾'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLabel(t.selectFarmer),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(LucideIcons.user, size: 20),
                  ),
                  initialValue: _selectedFarmerId,
                  isExpanded: true,
                  items: Provider.of<FarmitreProvider>(context, listen: false).farmers.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))).toList(),
                  onChanged: (val) => setState(() => _selectedFarmerId = val),
                ),
                const SizedBox(height: 20),
                _buildLabel(t.date),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.calendar, size: 20, color: Colors.grey),
                        const SizedBox(width: 12),
                        Text(
                          "${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildLabel(t.selectVegetable),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: t.searchHint,
                    prefixIcon: const Icon(LucideIcons.search, size: 20),
                  ),
                  onChanged: (val) => setState(() => _vegetableSearch = val),
                ),
                const SizedBox(height: 16),
                _buildVegetableGrid(filteredVegetables, isTe),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(t.step2, '📦'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildInventoryCard(
                      label: t.oldBags,
                      icon: "📦",
                      controller: _oldBagsController,
                      focusNode: _oldBagsFocus,
                      onSubmitted: () => _oldKgsFocus.requestFocus(),
                    ),
                    const SizedBox(width: 12),
                    _buildInventoryCard(
                      label: t.oldKgs,
                      icon: "⚖️",
                      controller: _oldKgsController,
                      focusNode: _oldKgsFocus,
                      onSubmitted: () => _newBagsFocus.requestFocus(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInventoryCard(
                      label: t.newBags,
                      icon: "🆕📦",
                      controller: _newBagsController,
                      focusNode: _newBagsFocus,
                      onSubmitted: () => _newKgsFocus.requestFocus(),
                      isNew: true,
                    ),
                    const SizedBox(width: 12),
                    _buildInventoryCard(
                      label: t.newKgs,
                      icon: "🆕⚖️",
                      controller: _newKgsController,
                      focusNode: _newKgsFocus,
                      onSubmitted: () => _cagesFocus.requestFocus(),
                      isNew: true,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField(
                        t.newCages,
                        _cagesController,
                        focusNode: _cagesFocus,
                        onSubmitted: () => _damagesFocus.requestFocus(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNumberField(
                        t.damages,
                        _damagesController,
                        focusNode: _damagesFocus,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSummaryRow(context, t),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryCard({
    required String label,
    required String icon,
    required TextEditingController controller,
    required FocusNode focusNode,
    required VoidCallback onSubmitted,
    bool isNew = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: () => focusNode.requestFocus(),
        child: Container(
          height: 110,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isNew
                ? colorScheme.primary.withValues(alpha: 0.05)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isNew
                  ? colorScheme.primary.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isNew ? colorScheme.primary : Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              TextField(
                controller: controller,
                focusNode: focusNode,
                onSubmitted: (_) => onSubmitted(),
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isNew ? colorScheme.primary : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: '0',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep3(AppLocalizations t) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(t.step3, '📈'),
            PremiumGuard(
              child: TextButton.icon(
                onPressed: _addPricingRow,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(t.addPriceRow, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        if (_pricingRows.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(t.pricingError, style: const TextStyle(color: Colors.grey)),
          ))
        else
          ..._pricingRows.asMap().entries.map((entry) => _buildPricingCard(context, entry.key, entry.value, t)),
      ],
    );
  }

  Widget _buildStep4(AppLocalizations t) {
    return Column(
      children: [
        _buildSectionHeader(t.step4, '🛒'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildNumberField(t.soldBags, _soldBagsController, focusNode: _soldBagsFocus),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildInventoryIndicator(context, t.remainingBags, '$_remainingBags', _remainingBags < 0),
                    const SizedBox(width: 12),
                    _buildInventoryIndicator(context, t.remainingKgsLabel, '$_remainingKgs', _remainingKgs < 0),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total Sold KGs", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("${_totalSoldKgs.toStringAsFixed(1)} KGs", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep5(AppLocalizations t, bool isTe) {
    return Column(
      children: [
        _buildSectionHeader(t.expenses, '💰'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildNumberField(t.cooliePerBag, _koliRateController, prefix: "₹"),
                const SizedBox(height: 16),
                _buildNumberField(t.commission, _commissionRateController, suffix: "%"),
                const SizedBox(height: 16),
                _buildNumberField(t.transport, _transportController, prefix: "₹"),
                const Divider(height: 40),
                _buildSmallLabel("ADDITIONAL EXPENSES"),
                const SizedBox(height: 12),
                _buildExpenseSelector(t),
                if (_expenses.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  ..._expenses.asMap().entries.map((entry) => _buildExpenseItem(entry.key, entry.value, isTe, t)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep6(AppLocalizations t, bool isTe) {
    return Column(
      children: [
        _buildSectionHeader("Final Review", '🧾'),
        Card(
          elevation: 4,
          shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(t.grandTotal.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                FittedBox(
                  child: Text(
                    '₹${_grandTotal.round()}',
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary, letterSpacing: -1)
                  )
                ),
                const Divider(height: 40),
                InkWell(
                  onTap: () async {
                    final selectedVeg = vegetables.firstWhere((v) => v.id == _selectedVegetableId, orElse: () => vegetables.first);

                    _originalPricingRows ??= _pricingRows.map((r) => PricingRow(
                      id: r.id,
                      quantity: r.quantity,
                      price: r.price,
                      type: r.type,
                    )).toList();

                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SaleSummaryPage(
                          vegetableName: isTe ? selectedVeg.nameTe : selectedVeg.nameEn,
                          vegetableEmoji: selectedVeg.emoji,
                          totalImportedKgs: _totalImportedKgs,
                          pricingRows: _pricingRows,
                          originalPricingRows: _originalPricingRows ?? _pricingRows,
                          isTe: isTe,
                        ),
                      ),
                    );

                    if (result != null && result is List<PricingRow>) {
                      setState(() {
                        _editedPricingRows = result;
                        _pricingRows = List.from(result);
                        for (var row in _pricingRows) {
                          if (!_quantityControllers.containsKey(row.id)) {
                            _quantityControllers[row.id] = TextEditingController();
                            _priceControllers[row.id] = TextEditingController();
                            _quantityFocusNodes[row.id] = FocusNode();
                            _priceFocusNodes[row.id] = FocusNode();
                          }
                          _quantityControllers[row.id]?.text = row.quantity.round().toString();
                          _priceControllers[row.id]?.text = row.price.round().toString();
                        }
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.list, size: 20, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 12),
                        Text(
                          "View Sale Summary",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation(AppLocalizations t, bool isTe) {
    if (_selectedFarmerId == null || _selectedVegetableId == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 30, offset: const Offset(0, -10)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                  ),
                  child: Text(t.back, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _currentStep < 5
                ? ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.next, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.arrowRight, size: 20),
                      ],
                    ),
                  )
                : PremiumGuard(
                    child: ElevatedButton(
                      onPressed: (_totalSoldKgs > 0 || _soldBags > 0) ? _handleSubmit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: Colors.green.withValues(alpha: 0.3),
                      ),
                      child: Text(t.generateBill, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFarmersState(BuildContext context, AppLocalizations t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👩‍🌾', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          Text(t.noFarmersFound, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(t.startByAddingFarmer, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String emoji) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700));
  }

  Widget _buildSmallLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1));
  }

  Widget _buildVegetableGrid(List<VegetableInfo> filteredVegetables, bool isTe) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filteredVegetables.length,
        itemBuilder: (context, index) {
          final v = filteredVegetables[index];
          final isSelected = _selectedVegetableId == v.id;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedVegetableId = v.id);
            },
            child: Container(
              width: 90,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(v.emoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      isTe ? v.nameTe : v.nameEn,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : null,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(t.totalBags, '$_totalImportedBags', LucideIcons.package),
          Container(width: 1, height: 40, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
          _buildSummaryItem(t.totalKgs, '$_totalImportedKgs', LucideIcons.scale),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildPricingCard(BuildContext context, int index, PricingRow row, AppLocalizations t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 'kgs', label: Text(t.kgs, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    ButtonSegment(value: 'bags', label: Text(t.bags, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                  selected: {row.type},
                  onSelectionChanged: (val) => setState(() => row.type = val.first),
                ),
              ),
              const SizedBox(width: 12),
              if (_pricingRows.length > 1)
                PremiumGuard(
                  child: IconButton(
                    icon: const Icon(LucideIcons.x, size: 20, color: Colors.red),
                    onPressed: () => _removePricingRow(index, row.id),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildNumberField(
                  row.type == 'kgs' ? t.kgs : t.bags,
                  _quantityControllers[row.id]!,
                  focusNode: _quantityFocusNodes[row.id],
                  onChanged: (val) {
                    setState(() {
                      row.quantity = double.tryParse(val) ?? 0;
                    });
                  },
                  onSubmitted: () => _priceFocusNodes[row.id]?.requestFocus(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: _buildNumberField(
                  t.rate,
                  _priceControllers[row.id]!,
                  focusNode: _priceFocusNodes[row.id],
                  prefix: "₹",
                  hintText: _lastRate > 0 ? _lastRate.toStringAsFixed(0) : null,
                  onChanged: (val) {
                    setState(() {
                      row.price = double.tryParse(val) ?? 0;
                      if (row.price > 0) _lastRate = row.price;
                    });
                  },
                  onSubmitted: () {
                    if (index < _pricingRows.length - 1) {
                      _quantityFocusNodes[_pricingRows[index + 1].id]?.requestFocus();
                    } else {
                      double effectivePrice = row.price;
                      if (effectivePrice == 0 && _priceControllers[row.id]?.text.isEmpty == true) {
                        effectivePrice = _lastRate;
                      }
                      if (row.quantity > 0 && effectivePrice > 0) {
                        _addPricingRow();
                      } else {
                        // In step-by-step, we might not want to auto-scroll to next section
                        // but maybe just hide keyboard or something.
                        FocusScope.of(context).unfocus();
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('TOTAL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey)),
                      FittedBox(
                        child: Text(
                          '₹${(row.quantity * row.price).round()}',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _removePricingRow(int index, String id) {
    setState(() {
      _quantityFocusNodes[id]?.dispose();
      _priceFocusNodes[id]?.dispose();
      _quantityControllers[id]?.dispose();
      _priceControllers[id]?.dispose();
      _quantityFocusNodes.remove(id);
      _priceFocusNodes.remove(id);
      _quantityControllers.remove(id);
      _priceControllers.remove(id);
      _pricingRows.removeAt(index);
    });
  }

  Widget _buildInventoryIndicator(BuildContext context, String label, String value, bool isNegative) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isNegative ? Colors.red.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isNegative ? Colors.red.withValues(alpha: 0.1) : Colors.transparent),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isNegative ? Colors.red : null,
                )
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseSelector(AppLocalizations t) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        PremiumGuard(
          child: _buildExpenseChip(t.otherCharges, () => _addExpense(t.otherCharges), LucideIcons.moreHorizontal),
        ),
      ],
    );
  }

  Widget _buildExpenseChip(String label, VoidCallback onTap, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      backgroundColor: Theme.of(context).colorScheme.surface,
      side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _buildExpenseItem(int index, Expense exp, bool isTe, AppLocalizations t) {
    if (!_expenseControllers.containsKey(exp.id)) {
      _expenseControllers[exp.id] = TextEditingController(text: exp.amount == 0 ? '' : exp.amount.toInt().toString());
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildNumberField(
              isTe && (exp.name == "Transport" || exp.name == "Hire") ? t.kirayee : exp.name, 
              _expenseControllers[exp.id]!,
              prefix: "₹",
              onChanged: (val) {
                setState(() {
                  exp.amount = int.tryParse(val)?.toDouble() ?? 0;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          PremiumGuard(
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.trash2, color: Colors.red, size: 18),
              ),
              onPressed: () {
                setState(() {
                  _expenseControllers[exp.id]?.dispose();
                  _expenseControllers.remove(exp.id);
                  _expenses.removeAt(index);
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField(
    String label,
    TextEditingController controller,
    {FocusNode? focusNode,
    Function(String)? onChanged,
    VoidCallback? onSubmitted,
    String? prefix,
    String? suffix,
    String? hintText}
  ) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (focusNode?.context != null) {
              Scrollable.ensureVisible(
                focusNode!.context!,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: 0.1,
              );
            }
          });
        }
      },
      child: TextField(
        focusNode: focusNode,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          prefixText: prefix,
          suffixText: suffix,
          hintText: hintText,
          hintStyle: hintText != null ? const TextStyle(color: Colors.grey, fontWeight: FontWeight.normal) : null,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
        textInputAction: TextInputAction.next,
        onChanged: onChanged ?? (_) => setState(() {}),
        onSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
      ),
    );
  }
}

class SaleSummaryPage extends StatefulWidget {
  final String vegetableName;
  final String vegetableEmoji;
  final int totalImportedKgs;
  final List<PricingRow> pricingRows;
  final List<PricingRow> originalPricingRows;
  final bool isTe;

  const SaleSummaryPage({
    super.key,
    required this.vegetableName,
    required this.vegetableEmoji,
    required this.totalImportedKgs,
    required this.pricingRows,
    required this.originalPricingRows,
    required this.isTe,
  });

  @override
  State<SaleSummaryPage> createState() => _SaleSummaryPageState();
}

class _SaleSummaryPageState extends State<SaleSummaryPage> {
  late List<PricingRow> _currentGroupedRows;
  late List<PricingRow> _originalGroupedRows;

  @override
  void initState() {
    super.initState();
    _currentGroupedRows = _groupRows(widget.pricingRows);
    _originalGroupedRows = _groupRows(widget.originalPricingRows);
  }

  List<PricingRow> _groupRows(List<PricingRow> rows) {
    final Map<String, PricingRow> groups = {};
    for (var row in rows) {
      if (row.quantity <= 0 || row.price <= 0) continue;
      final key = "${row.price}_${row.type}";
      if (groups.containsKey(key)) {
        groups[key]!.quantity += row.quantity;
      } else {
        groups[key] = PricingRow(
          id: row.id,
          quantity: row.quantity,
          price: row.price,
          type: row.type,
        );
      }
    }
    return groups.values.toList();
  }

  double get _totalSoldKgs => _currentGroupedRows.fold(0.0, (sum, row) => sum + row.quantity);

  void _showEditDialog(int index) async {
    final t = AppLocalizations.of(context)!;
    final row = _currentGroupedRows[index];

    double initialQuantity = row.quantity;
    double initialPrice = row.price;

    final result = await showModalBottomSheet<Map<String, double>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          double currentQty = row.quantity;
          double currentPrice = row.price;

          double beforeAmount = initialQuantity * initialPrice;
          double editedAmount = currentQty * currentPrice;
          double diff = editedAmount - beforeAmount;

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 32,
              left: 24,
              right: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.isTe ? "అమ్మకపు వివరాలను సవరించండి" : "Edit Sale Details",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Focus(
                          onFocusChange: (hasFocus) {
                            if (hasFocus) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                Scrollable.ensureVisible(
                                  context,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  alignment: 0.1,
                                );
                              });
                            }
                          },
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: widget.isTe ? "మొత్తం కేజీలు" : "Total KGs",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            keyboardType: TextInputType.number,
                            controller: TextEditingController(text: currentQty.round().toString())
                              ..selection = TextSelection.collapsed(offset: currentQty.round().toString().length),
                            onChanged: (val) {
                              setModalState(() {
                                currentQty = double.tryParse(val) ?? 0;
                                row.quantity = currentQty;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Focus(
                          onFocusChange: (hasFocus) {
                            if (hasFocus) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                Scrollable.ensureVisible(
                                  context,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  alignment: 0.1,
                                );
                              });
                            }
                          },
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: widget.isTe ? "ధర" : "Rate",
                              prefixText: "₹",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            keyboardType: TextInputType.number,
                            controller: TextEditingController(text: currentPrice.round().toString())
                              ..selection = TextSelection.collapsed(offset: currentPrice.round().toString().length),
                            onChanged: (val) {
                              setModalState(() {
                                currentPrice = double.tryParse(val) ?? 0;
                                row.price = currentPrice;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryItem(widget.isTe ? "ముందు మొత్తం" : "Before Amount", "₹${beforeAmount.round()}", Colors.grey),
                        const SizedBox(height: 8),
                        _buildSummaryItem(widget.isTe ? "సవరించిన మొత్తం" : "Edited Amount", "₹${editedAmount.round()}", Theme.of(context).colorScheme.primary),
                        const Divider(height: 24),
                        _buildSummaryItem(
                          widget.isTe ? "తేడా" : "Difference",
                          "${diff > 0 ? "+" : ""}₹${diff.round()}",
                          diff == 0 ? Colors.grey : (diff > 0 ? Colors.green : Colors.red),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, {'qty': currentQty, 'price': currentPrice}),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(t.save, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result != null) {
      setState(() {
        row.quantity = result['qty']!;
        row.price = result['price']!;
        _currentGroupedRows = _groupRows(_currentGroupedRows);
      });
    }
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 16)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    double totalOriginalAmount = _originalGroupedRows.fold(0, (sum, r) => sum + (r.quantity * r.price));
    double totalCurrentAmount = _currentGroupedRows.fold(0, (sum, r) => sum + (r.quantity * r.price));
    double totalDiff = totalCurrentAmount - totalOriginalAmount;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _currentGroupedRows);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isTe ? "అమ్మకపు సారాంశం" : "Sale Summary", style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(widget.vegetableEmoji, style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(widget.vegetableName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        '${t.totalKgs}: ${widget.totalImportedKgs} ${t.kgs}',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.isTe ? "అమ్మకపు ధరల విభజన" : "SALE PRICE BREAKDOWN",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              ..._currentGroupedRows.asMap().entries.map((entry) {
                int idx = entry.key;
                PricingRow row = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "₹${row.price.round()}",
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.green),
                            ),
                            Text(
                              "${row.quantity.round()} ${row.type == 'kgs' ? t.kgs : t.bags}",
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              "₹${(row.quantity * row.price).round()}",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: () => _showEditDialog(idx),
                              icon: const Icon(LucideIcons.edit, size: 20),
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                foregroundColor: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.isTe ? "మొత్తం అమ్మినవి" : "TOTAL SOLD", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                            Text("${_totalSoldKgs.round()} ${t.kgs}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(widget.isTe ? "తేడా" : "TOTAL DIFF", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                            Text(
                              "${totalDiff > 0 ? "+" : ""}₹${totalDiff.round()}",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: totalDiff == 0 ? null : (totalDiff > 0 ? Colors.green : Colors.red)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(widget.isTe ? "నికర మొత్తం" : "NET AMOUNT", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("₹${totalCurrentAmount.round()}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
