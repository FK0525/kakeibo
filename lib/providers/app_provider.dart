import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../models/expense.dart';
import '../models/monthly_data.dart';
import '../models/split_type.dart';
import '../models/transport_means.dart';

const _uuid = Uuid();

class AppProvider extends ChangeNotifier {
  MonthlyData _monthly = MonthlyData(monthKey: _monthKey(DateTime.now()));
  List<Expense> _expenses = [];
  bool _loaded = false;
  // 全月の月次データ（使用可能残高の繰越を積み上げ計算するために保持）
  final Map<String, MonthlyData> _monthlyMap = {};

  MonthlyData get monthly => _monthly;
  List<Expense> get expenses => _expenses;
  bool get loaded => _loaded;

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  List<Expense> get currentMonthExpenses {
    final key = _monthKey(DateTime.now());
    return _expenses
        .where((e) => _monthKey(e.date) == key)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // 固定費（カテゴリが固定費のもの）
  List<Expense> get fixedExpenses => currentMonthExpenses
      .where((e) => !e.isIncome && e.category == ExpenseCategory.fixed)
      .toList();

  int get totalFixedCost => fixedExpenses.fold(0, (s, e) => s + e.selfAmount);

  // 支出合計（収入系除く、固定費除く、割り勘は自己負担分のみ）
  int get totalSpent => currentMonthExpenses
      .where((e) => !e.isIncome && e.category != ExpenseCategory.fixed)
      .fold(0, (s, e) => s + e.selfAmount);

  int get requiredSpent => currentMonthExpenses
      .where((e) => !e.isIncome && e.category != ExpenseCategory.fixed && e.necessity == NecessityType.required)
      .fold(0, (s, e) => s + e.selfAmount);

  int get unnecessarySpent => currentMonthExpenses
      .where((e) => !e.isIncome && e.category != ExpenseCategory.fixed && e.necessity == NecessityType.unnecessary)
      .fold(0, (s, e) => s + e.selfAmount);

  // 特別収入の使用可能分合計
  int get specialIncomeUsable => currentMonthExpenses
      .where((e) => e.entryType == EntryType.specialIncome)
      .fold(0, (s, e) => s + (e.usableAmount ?? 0));

  // 特別収入の貯金分合計
  int get specialIncomeSavings => currentMonthExpenses
      .where((e) => e.entryType == EntryType.specialIncome)
      .fold(0, (s, e) => s + e.savingsAmount);

  // 集計対象の全月キー（月次データ・支出の両方から収集して昇順）
  List<String> get _activeMonthKeys {
    final set = <String>{};
    set.addAll(_monthlyMap.keys);
    for (final e in _expenses) {
      set.add(_monthKey(e.date));
    }
    final list = set.toList()..sort();
    return list;
  }

  // その月の通常収入（Expense記録を優先、なければ旧 monthly.income）
  int _incomeForMonth(String key) {
    final fromExpenses = _expenses
        .where((e) =>
            _monthKey(e.date) == key && e.entryType == EntryType.income)
        .fold(0, (s, e) => s + e.amount);
    if (fromExpenses > 0) return fromExpenses;
    return _monthlyMap[key]?.income ?? 0;
  }

  // その月の固定費合計
  int _fixedCostForMonth(String key) => _expenses
      .where((e) =>
          _monthKey(e.date) == key &&
          !e.isIncome &&
          e.category == ExpenseCategory.fixed)
      .fold(0, (s, e) => s + e.selfAmount);

  // その月の使用可能予算 = (収入 - 固定費) ÷ 2
  int _budgetForMonth(String key) {
    final base = _incomeForMonth(key) - _fixedCostForMonth(key);
    return (base / 2).floor();
  }

  int _specialUsableForMonth(String key) => _expenses
      .where((e) =>
          _monthKey(e.date) == key && e.entryType == EntryType.specialIncome)
      .fold(0, (s, e) => s + (e.usableAmount ?? 0));

  // その月の支出（収入・固定費を除く）
  int _spentForMonth(String key) => _expenses
      .where((e) =>
          _monthKey(e.date) == key &&
          !e.isIncome &&
          e.category != ExpenseCategory.fixed)
      .fold(0, (s, e) => s + e.selfAmount);

  // 繰越額 = 今月より前の全月の残高を積み上げた額（毎月きちんと繰り越される）
  int get carryoverAmount {
    final cur = _monthKey(DateTime.now());
    int carry = 0;
    for (final k in _activeMonthKeys) {
      if (k.compareTo(cur) >= 0) break;
      carry =
          _budgetForMonth(k) + _specialUsableForMonth(k) + carry - _spentForMonth(k);
    }
    return carry;
  }

  bool get showCarryoverNotification =>
      !_monthly.carryoverConfirmed && carryoverAmount != 0;

  int get carryoverDisplay => carryoverAmount;

  // 今月の通常収入合計（Expenseとして記録された分）
  int get monthlyIncome => currentMonthExpenses
      .where((e) => e.entryType == EntryType.income)
      .fold(0, (s, e) => s + e.amount);

  // 通常収入が入力されているか
  bool get hasIncome => monthlyIncome > 0 || _monthly.income > 0;

  // 使用可能予算 = (収入 - 固定費) ÷ 2
  int get availableBudget {
    // 新方式（monthlyIncome）を優先、なければ旧方式（_monthly.income）
    final income = monthlyIncome > 0 ? monthlyIncome : _monthly.income;
    final base = income - totalFixedCost;
    return (base / 2).floor();
  }

  // 貯金予定 = (収入 - 固定費) ÷ 2
  int get savingsTarget {
    final income = monthlyIncome > 0 ? monthlyIncome : _monthly.income;
    final base = income - totalFixedCost;
    return (base / 2).floor();
  }

  // 使用可能残高 = 予算 + 特別収入使用可能分 + 繰越 - 支出（固定費除く）
  // 繰越は確定（✕）の有無に関わらず常に残高へ反映され、月をまたいでも0にならない
  int get remainingBudget =>
      availableBudget + specialIncomeUsable + carryoverAmount - totalSpent;

  // 今月の貯金予定 = 通常貯金 + 特別収入貯金分
  int get totalSavings => savingsTarget + specialIncomeSavings;

  double get budgetUsageRatio {
    final budget =
        availableBudget + specialIncomeUsable + carryoverAmount;
    if (budget <= 0) return 0;
    return (totalSpent / budget).clamp(0.0, 1.0);
  }

  bool get shouldShowIncomeInput {
    final now = DateTime.now();
    return now.day >= 25 && !_monthly.incomeEntered;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _monthKey(DateTime.now());

    // すべての月次データを読み込む（繰越の積み上げ計算に使用）
    _monthlyMap.clear();
    for (final k in prefs.getKeys()) {
      if (!k.startsWith('monthly_')) continue;
      final s = prefs.getString(k);
      if (s == null) continue;
      final d = MonthlyData.fromJsonString(s);
      _monthlyMap[d.monthKey] = d;
    }

    _monthly = _monthlyMap[key] ?? MonthlyData(monthKey: key);
    _monthlyMap[key] = _monthly;

    final eStr = prefs.getString('expenses');
    if (eStr != null) _expenses = Expense.listFromJson(eStr);

    await _applyRecurringExpenses();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _applyRecurringExpenses() async {
    final now = DateTime.now();
    final key = _monthKey(now);
    final lastKey = _monthKey(DateTime(now.year, now.month - 1));

    final templates = _expenses
        .where((e) => _monthKey(e.date) == lastKey && e.isRecurring)
        .toList();
    final added = _expenses
        .where((e) => _monthKey(e.date) == key && e.isRecurring)
        .map((e) => e.displayLabel)
        .toSet();

    bool changed = false;
    for (final t in templates) {
      if (!added.contains(t.displayLabel)) {
        _expenses.add(Expense(
          id: _uuid.v4(),
          amount: t.amount,
          category: t.category,
          customLabel: t.customLabel,
          necessity: t.necessity,
          date: DateTime(now.year, now.month, 1),
          isRecurring: true,
        ));
        changed = true;
      }
    }
    if (changed) await _saveExpenses();
  }

  Future<void> _saveMonthly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'monthly_${_monthly.monthKey}', MonthlyData.toJsonString(_monthly));
  }

  Future<void> _saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('expenses', Expense.listToJson(_expenses));
  }

  // 通常収入を追加（Expenseエントリとして記録）
  Future<void> setIncome(int income, {String? memo}) async {
    _expenses.insert(0, Expense(
      id: _uuid.v4(),
      amount: income,
      category: ExpenseCategory.custom,
      necessity: NecessityType.required,
      date: DateTime.now(),
      entryType: EntryType.income,
      memo: memo,
    ));
    _monthly = _monthly.copyWith(incomeEntered: true);
    _monthlyMap[_monthly.monthKey] = _monthly;
    await _saveExpenses();
    await _saveMonthly();
    notifyListeners();
  }

  Future<void> confirmCarryover() async {
    final now = DateTime.now();
    _expenses.insert(0, Expense(
      id: _uuid.v4(),
      amount: carryoverAmount.abs(),
      category: ExpenseCategory.custom,
      necessity: NecessityType.required,
      date: DateTime(now.year, now.month, 1),
      entryType: EntryType.carryover,
    ));
    _monthly = _monthly.copyWith(carryoverConfirmed: true);
    _monthlyMap[_monthly.monthKey] = _monthly;
    await _saveExpenses();
    await _saveMonthly();
    notifyListeners();
  }

  // 特別収入追加（使用可能金額と貯金を分けて管理）
  Future<void> addSpecialIncome(int amount, int usableAmount, {String? memo}) async {
    _expenses.insert(0, Expense(
      id: _uuid.v4(),
      amount: amount,
      category: ExpenseCategory.custom,
      necessity: NecessityType.required,
      date: DateTime.now(),
      entryType: EntryType.specialIncome,
      usableAmount: usableAmount,
      memo: memo,
    ));
    await _saveExpenses();
    notifyListeners();
  }

  Future<void> addExpense({
    required int amount,
    required ExpenseCategory category,
    String? customLabel,
    required NecessityType necessity,
    String? memo,
    String? photoPath,
    bool isRecurring = false,
    TransportMeans? transportMeans,
    String? transportFrom,
    String? transportTo,
    SplitType splitType = SplitType.none,
    int splitPercent = 0,
  }) async {
    _expenses.insert(0, Expense(
      id: _uuid.v4(),
      amount: amount,
      category: category,
      customLabel: customLabel,
      necessity: necessity,
      memo: memo,
      photoPath: photoPath,
      date: DateTime.now(),
      isRecurring: isRecurring,
      transportMeans: transportMeans,
      transportFrom: transportFrom,
      transportTo: transportTo,
      splitType: splitType,
      splitPercent: splitPercent,
    ));
    await _saveExpenses();
    notifyListeners();
  }

  // 支出の編集
  Future<void> updateExpense({
    required String id,
    required int amount,
    required ExpenseCategory category,
    String? customLabel,
    required NecessityType necessity,
    String? memo,
    String? photoPath,
    bool? isRecurring,
    int? usableAmount,
    TransportMeans? transportMeans,
    String? transportFrom,
    String? transportTo,
    SplitType? splitType,
    int? splitPercent,
  }) async {
    final idx = _expenses.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _expenses[idx] = _expenses[idx].copyWith(
      amount: amount,
      category: category,
      customLabel: customLabel,
      necessity: necessity,
      memo: memo,
      photoPath: photoPath,
      isRecurring: isRecurring,
      usableAmount: usableAmount,
      transportMeans: transportMeans,
      transportFrom: transportFrom,
      transportTo: transportTo,
      splitType: splitType,
      splitPercent: splitPercent,
    );
    await _saveExpenses();
    notifyListeners();
  }

  // 未精算の割り勘
  List<Expense> get unsettledSplits => _expenses
      .where((e) => e.hasSplit && !e.splitSettled && !e.isIncome)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  // 精算済みの割り勘
  List<Expense> get settledSplits => _expenses
      .where((e) => e.hasSplit && e.splitSettled && !e.isIncome)
      .toList()
    ..sort((a, b) => (b.splitSettledAt ?? b.date).compareTo(a.splitSettledAt ?? a.date));

  // 未精算合計（受取予定）
  int get unsettledTotal =>
      unsettledSplits.fold(0, (s, e) => s + e.partnerAmount);

  // 一括精算
  Future<void> settleAllSplits() async {
    if (unsettledSplits.isEmpty) return;
    final total = unsettledTotal;
    final now = DateTime.now();

    // 未精算をすべて精算済みに
    for (final e in unsettledSplits) {
      final idx = _expenses.indexWhere((x) => x.id == e.id);
      if (idx >= 0) {
        _expenses[idx] = _expenses[idx].copyWith(
          splitSettled: true,
          splitSettledAt: now,
        );
      }
    }

    // 精算金額を収入として記録
    _expenses.insert(0, Expense(
      id: _uuid.v4(),
      amount: total,
      category: ExpenseCategory.custom,
      necessity: NecessityType.required,
      date: now,
      entryType: EntryType.splitSettlement,
      memo: 'パートナーから精算受取',
    ));

    await _saveExpenses();
    notifyListeners();
  }

  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    await _saveExpenses();
    notifyListeners();
  }

  Future<void> updateRecurringAmount(String id, int newAmount) async {
    final idx = _expenses.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _expenses[idx] = _expenses[idx].copyWith(amount: newAmount);
    await _saveExpenses();
    notifyListeners();
  }

  // ── データのバックアップ（エクスポート／インポート）──

  // 全データを JSON 文字列として書き出す
  String exportJson() {
    final monthly = <String, dynamic>{};
    for (final entry in _monthlyMap.entries) {
      monthly[entry.key] = entry.value.toJson();
    }
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'kakeibo',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'expenses': _expenses.map((e) => e.toJson()).toList(),
      'monthly': monthly,
    });
  }

  // JSON 文字列からデータを復元する（既存データは置き換え）
  Future<void> importJson(String jsonStr) async {
    final data = jsonDecode(jsonStr.trim());
    if (data is! Map || data['app'] != 'kakeibo') {
      throw const FormatException('このデータは家計簿のバックアップではありません');
    }
    final expensesJson = data['expenses'];
    final monthlyJson = data['monthly'];
    if (expensesJson is! List || monthlyJson is! Map) {
      throw const FormatException('バックアップデータの形式が正しくありません');
    }
    // 先に全件パースして形式を検証（失敗時は書き込まずに中断）
    final expenses = expensesJson
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
    final monthly = <String, MonthlyData>{};
    monthlyJson.forEach((k, v) {
      monthly[k as String] = MonthlyData.fromJson(v as Map<String, dynamic>);
    });

    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().toList()) {
      if (k.startsWith('monthly_')) await prefs.remove(k);
    }
    await prefs.setString('expenses', Expense.listToJson(expenses));
    for (final entry in monthly.entries) {
      await prefs.setString(
          'monthly_${entry.key}', MonthlyData.toJsonString(entry.value));
    }
    await load();
  }
}
