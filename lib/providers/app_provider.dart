import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/monthly_data.dart';
import '../models/split_type.dart';

const _uuid = Uuid();

class AppProvider extends ChangeNotifier {
  MonthlyData _monthly = MonthlyData(monthKey: _monthKey(DateTime.now()));
  List<Expense> _expenses = [];
  bool _loaded = false;
  int _lastMonthBudget = 0;

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

  // 支出合計（収入系除く、割り勘は自己負担分のみ）
  int get totalSpent => currentMonthExpenses
      .where((e) => !e.isIncome)
      .fold(0, (s, e) => s + e.selfAmount);

  int get requiredSpent => currentMonthExpenses
      .where((e) => !e.isIncome && e.necessity == NecessityType.required)
      .fold(0, (s, e) => s + e.selfAmount);

  int get unnecessarySpent => currentMonthExpenses
      .where((e) => !e.isIncome && e.necessity == NecessityType.unnecessary)
      .fold(0, (s, e) => s + e.selfAmount);

  // 特別収入の使用可能分合計
  int get specialIncomeUsable => currentMonthExpenses
      .where((e) => e.entryType == EntryType.specialIncome)
      .fold(0, (s, e) => s + (e.usableAmount ?? 0));

  // 特別収入の貯金分合計
  int get specialIncomeSavings => currentMonthExpenses
      .where((e) => e.entryType == EntryType.specialIncome)
      .fold(0, (s, e) => s + e.savingsAmount);

  // 繰越額
  int get carryoverAmount {
    final now = DateTime.now();
    final lastKey = _monthKey(DateTime(now.year, now.month - 1));
    final lastSpent = _expenses
        .where((e) => _monthKey(e.date) == lastKey && !e.isIncome)
        .fold(0, (s, e) => s + e.amount);
    return _lastMonthBudget - lastSpent;
  }

  bool get showCarryoverNotification =>
      !_monthly.carryoverConfirmed && _lastMonthBudget > 0;

  int get carryoverDisplay => carryoverAmount;

  // 使用可能残高 = 予算 + 特別収入使用可能分 + 繰越 - 支出
  int get remainingBudget {
    final base = _monthly.availableBudget + specialIncomeUsable - totalSpent;
    if (showCarryoverNotification) return base + carryoverAmount;
    return base;
  }

  // 今月の貯金予定 = 通常貯金 + 特別収入貯金分
  int get totalSavings => _monthly.savingsTarget + specialIncomeSavings;

  double get budgetUsageRatio {
    final budget = _monthly.availableBudget +
        specialIncomeUsable +
        (showCarryoverNotification ? carryoverAmount : 0);
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

    final mStr = prefs.getString('monthly_$key');
    _monthly = mStr != null
        ? MonthlyData.fromJsonString(mStr)
        : MonthlyData(monthKey: key);

    final eStr = prefs.getString('expenses');
    if (eStr != null) _expenses = Expense.listFromJson(eStr);

    final now = DateTime.now();
    final lastKey = _monthKey(DateTime(now.year, now.month - 1));
    final lastMStr = prefs.getString('monthly_$lastKey');
    if (lastMStr != null) {
      _lastMonthBudget = MonthlyData.fromJsonString(lastMStr).availableBudget;
    }

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

  Future<void> setIncome(int income) async {
    _monthly = _monthly.copyWith(income: income, incomeEntered: true);
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
}
