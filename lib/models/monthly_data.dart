import 'dart:convert';

class MonthlyData {
  final String monthKey;
  final int income;
  final bool incomeEntered;
  final bool carryoverConfirmed; // 繰越を✕で確定したか

  MonthlyData({
    required this.monthKey,
    this.income = 0,
    this.incomeEntered = false,
    this.carryoverConfirmed = false,
  });

  int get availableBudget => (income / 2).floor();
  int get savingsTarget => (income / 2).floor();

  MonthlyData copyWith({
    int? income,
    bool? incomeEntered,
    bool? carryoverConfirmed,
  }) => MonthlyData(
    monthKey: monthKey,
    income: income ?? this.income,
    incomeEntered: incomeEntered ?? this.incomeEntered,
    carryoverConfirmed: carryoverConfirmed ?? this.carryoverConfirmed,
  );

  Map<String, dynamic> toJson() => {
    'monthKey': monthKey,
    'income': income,
    'incomeEntered': incomeEntered,
    'carryoverConfirmed': carryoverConfirmed,
  };

  factory MonthlyData.fromJson(Map<String, dynamic> j) => MonthlyData(
    monthKey: j['monthKey'],
    income: j['income'] ?? 0,
    incomeEntered: j['incomeEntered'] ?? false,
    carryoverConfirmed: j['carryoverConfirmed'] ?? false,
  );

  static String toJsonString(MonthlyData d) => jsonEncode(d.toJson());
  static MonthlyData fromJsonString(String s) =>
      MonthlyData.fromJson(jsonDecode(s));
}
