import 'dart:convert';
import 'split_type.dart';
import 'transport_means.dart';

enum NecessityType { required, unnecessary }

enum ExpenseCategory { music, food, goods, service, transport, fixed, custom }

enum EntryType { expense, specialIncome, carryover, splitSettlement }

extension ExpenseCategoryExt on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.music:     return '音楽';
      case ExpenseCategory.food:      return '食事';
      case ExpenseCategory.goods:     return 'もの';
      case ExpenseCategory.service:   return 'サービス';
      case ExpenseCategory.transport: return '交通費';
      case ExpenseCategory.fixed:     return '固定費';
      case ExpenseCategory.custom:    return 'その他';
    }
  }
  String get emoji {
    switch (this) {
      case ExpenseCategory.music:     return '🎵';
      case ExpenseCategory.food:      return '🍽️';
      case ExpenseCategory.goods:     return '📦';
      case ExpenseCategory.service:   return '💻';
      case ExpenseCategory.transport: return '🚃';
      case ExpenseCategory.fixed:     return '🏠';
      case ExpenseCategory.custom:    return '✏️';
    }
  }
}

class Expense {
  final String id;
  final int amount;
  final ExpenseCategory category;
  final String? customLabel;
  final NecessityType necessity;
  final String? memo;
  final String? photoPath;
  final DateTime date;
  final bool isRecurring;
  final EntryType entryType;
  final int? usableAmount;

  // 交通費関連
  final TransportMeans? transportMeans;
  final String? transportFrom;
  final String? transportTo;

  // 割り勘関連
  final SplitType splitType;
  final int splitPercent;
  final bool splitSettled;
  final DateTime? splitSettledAt;

  Expense({
    required this.id,
    required this.amount,
    required this.category,
    this.customLabel,
    required this.necessity,
    this.memo,
    this.photoPath,
    required this.date,
    this.isRecurring = false,
    this.entryType = EntryType.expense,
    this.usableAmount,
    this.transportMeans,
    this.transportFrom,
    this.transportTo,
    this.splitType = SplitType.none,
    this.splitPercent = 0,
    this.splitSettled = false,
    this.splitSettledAt,
  });

  // 交通費の経路表示（出発地 → 行先）
  String? get transportRoute {
    if (category != ExpenseCategory.transport) return null;
    final from = (transportFrom ?? '').trim();
    final to = (transportTo ?? '').trim();
    if (from.isEmpty && to.isEmpty) return null;
    return '${from.isEmpty ? '?' : from} → ${to.isEmpty ? '?' : to}';
  }

  int get savingsAmount => entryType == EntryType.specialIncome
      ? amount - (usableAmount ?? 0)
      : 0;

  bool get hasSplit => splitType != SplitType.none;
  int get selfAmount => hasSplit ? (amount * splitPercent / 100).round() : amount;
  int get partnerAmount => hasSplit ? amount - selfAmount : 0;

  String get displayLabel {
    switch (entryType) {
      case EntryType.specialIncome:    return '特別収入';
      case EntryType.carryover:        return '前月繰越';
      case EntryType.splitSettlement:  return '割り勘精算';
      case EntryType.expense:          return customLabel ?? category.label;
    }
  }

  bool get isIncome =>
      entryType == EntryType.specialIncome ||
      entryType == EntryType.carryover ||
      entryType == EntryType.splitSettlement;

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'category': category.name,
    'customLabel': customLabel,
    'necessity': necessity.name,
    'memo': memo,
    'photoPath': photoPath,
    'date': date.toIso8601String(),
    'isRecurring': isRecurring,
    'entryType': entryType.name,
    'usableAmount': usableAmount,
    'transportMeans': transportMeans?.name,
    'transportFrom': transportFrom,
    'transportTo': transportTo,
    'splitType': splitType.name,
    'splitPercent': splitPercent,
    'splitSettled': splitSettled,
    'splitSettledAt': splitSettledAt?.toIso8601String(),
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'],
    amount: j['amount'],
    category: ExpenseCategory.values.byName(j['category']),
    customLabel: j['customLabel'],
    necessity: NecessityType.values.byName(j['necessity']),
    memo: j['memo'],
    photoPath: j['photoPath'],
    date: DateTime.parse(j['date']),
    isRecurring: j['isRecurring'] ?? false,
    entryType: EntryType.values.byName(j['entryType'] ?? 'expense'),
    usableAmount: j['usableAmount'],
    transportMeans: j['transportMeans'] != null
        ? TransportMeans.values.byName(j['transportMeans'])
        : null,
    transportFrom: j['transportFrom'],
    transportTo: j['transportTo'],
    splitType: j['splitType'] != null
        ? SplitType.values.byName(j['splitType'])
        : SplitType.none,
    splitPercent: j['splitPercent'] ?? 0,
    splitSettled: j['splitSettled'] ?? false,
    splitSettledAt: j['splitSettledAt'] != null
        ? DateTime.parse(j['splitSettledAt'])
        : null,
  );

  Expense copyWith({
    int? amount,
    ExpenseCategory? category,
    String? customLabel,
    NecessityType? necessity,
    String? memo,
    String? photoPath,
    bool? isRecurring,
    int? usableAmount,
    TransportMeans? transportMeans,
    String? transportFrom,
    String? transportTo,
    SplitType? splitType,
    int? splitPercent,
    bool? splitSettled,
    DateTime? splitSettledAt,
  }) => Expense(
    id: id,
    amount: amount ?? this.amount,
    category: category ?? this.category,
    customLabel: customLabel ?? this.customLabel,
    necessity: necessity ?? this.necessity,
    memo: memo ?? this.memo,
    photoPath: photoPath ?? this.photoPath,
    date: date,
    isRecurring: isRecurring ?? this.isRecurring,
    entryType: entryType,
    usableAmount: usableAmount ?? this.usableAmount,
    transportMeans: transportMeans ?? this.transportMeans,
    transportFrom: transportFrom ?? this.transportFrom,
    transportTo: transportTo ?? this.transportTo,
    splitType: splitType ?? this.splitType,
    splitPercent: splitPercent ?? this.splitPercent,
    splitSettled: splitSettled ?? this.splitSettled,
    splitSettledAt: splitSettledAt ?? this.splitSettledAt,
  );

  static List<Expense> listFromJson(String s) =>
      (jsonDecode(s) as List).map((e) => Expense.fromJson(e)).toList();
  static String listToJson(List<Expense> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());
}
