import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/expense.dart';
import 'chart_screen.dart';

final _yen = NumberFormat('#,###', 'ja_JP');

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // 月ごとにグループ化
  Map<String, List<Expense>> _groupByMonth(List<Expense> expenses) {
    final map = <String, List<Expense>>{};
    for (final e in expenses) {
      if (e.isIncome) continue;
      final key =
          '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(e);
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return Map.fromEntries(sorted);
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    return '${parts[0]}年${int.parse(parts[1])}月';
  }

  bool _isCurrentMonth(String key) {
    final now = DateTime.now();
    return key ==
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final grouped = _groupByMonth(p.expenses);
    final months = grouped.keys.toList();

    // 過去6ヶ月分のデータ（グラフ用）
    final now = DateTime.now();
    final last6 = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - i);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    }).reversed.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('支出履歴'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'サマリ'),
            Tab(text: '月別一覧'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ── サマリタブ ──
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // バーグラフ
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('過去6ヶ月の支出推移',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151))),
                      const SizedBox(height: 16),
                      ...last6.map((key) {
                        final list = grouped[key] ?? [];
                        final total = list
                            .where((e) => !e.isIncome)
                            .fold(0, (s, e) => s + e.amount);
                        final allMax = last6.map((k) {
                          return (grouped[k] ?? [])
                              .where((e) => !e.isIncome)
                              .fold(0, (s, e) => s + e.amount);
                        }).reduce((a, b) => a > b ? a : b);

                        final ratio =
                            allMax > 0 ? total / allMax : 0.0;
                        final isOver = total >
                            p.monthly.availableBudget;
                        final parts = key.split('-');
                        final label =
                            '${int.parse(parts[1])}月';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(children: [
                            SizedBox(
                              width: 28,
                              child: Text(label,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio.toDouble(),
                                  minHeight: 8,
                                  backgroundColor:
                                      const Color(0xFFF1F5F9),
                                  valueColor: AlwaysStoppedAnimation(
                                    isOver
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 76,
                              child: Text(
                                '¥${_yen.format(total)}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isOver
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF374151)),
                              ),
                            ),
                          ]),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 統計
                _card(
                  child: Column(children: [
                    _statRow('月平均支出', () {
                      if (grouped.isEmpty) return '¥0';
                      final total = grouped.values
                          .expand((e) => e)
                          .where((e) => !e.isIncome)
                          .fold(0, (s, e) => s + e.amount);
                      return '¥${_yen.format(total ~/ grouped.length)}';
                    }()),
                    _statRow('要（必要）の平均', () {
                      if (grouped.isEmpty) return '¥0';
                      final total = grouped.values
                          .expand((e) => e)
                          .where((e) =>
                              !e.isIncome &&
                              e.necessity == NecessityType.required)
                          .fold(0, (s, e) => s + e.amount);
                      return '¥${_yen.format(total ~/ grouped.length)}';
                    }(),
                        valueColor: const Color(0xFF2563EB)),
                    _statRow('不（不要）の平均', () {
                      if (grouped.isEmpty) return '¥0';
                      final total = grouped.values
                          .expand((e) => e)
                          .where((e) =>
                              !e.isIncome &&
                              e.necessity == NecessityType.unnecessary)
                          .fold(0, (s, e) => s + e.amount);
                      return '¥${_yen.format(total ~/ grouped.length)}';
                    }(),
                        valueColor: const Color(0xFFDC2626),
                        isLast: true),
                  ]),
                ),

                const SizedBox(height: 12),

                // 月別カード（サマリタブ）
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('月別内訳',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151))),
                ),
                const SizedBox(height: 8),
                ...months.map((key) => _MonthCard(
                      monthKey: key,
                      expenses: grouped[key] ?? [],
                      budget: p.monthly.availableBudget,
                      isCurrent: _isCurrentMonth(key),
                      monthLabel: _monthLabel(key),
                    )),
              ],
            ),
          ),

          // ── 月別一覧タブ ──
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: months.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final key = months[i];
              final list = grouped[key] ?? [];
              return _MonthCard(
                monthKey: key,
                expenses: list,
                budget: p.monthly.availableBudget,
                isCurrent: _isCurrentMonth(key),
                monthLabel: _monthLabel(key),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 1))
          ],
        ),
        child: child,
      );

  Widget _statRow(String label, String value,
      {Color? valueColor, bool isLast = false}) =>
      Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF94A3B8))),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? const Color(0xFF1E293B))),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
      ]);
}

class _MonthCard extends StatelessWidget {
  final String monthKey;
  final List<Expense> expenses;
  final int budget;
  final bool isCurrent;
  final String monthLabel;

  const _MonthCard({
    required this.monthKey,
    required this.expenses,
    required this.budget,
    required this.isCurrent,
    required this.monthLabel,
  });

  @override
  Widget build(BuildContext context) {
    final total = expenses
        .where((e) => !e.isIncome)
        .fold(0, (s, e) => s + e.amount);
    final req = expenses
        .where((e) => !e.isIncome && e.necessity == NecessityType.required)
        .fold(0, (s, e) => s + e.amount);
    final unneeded = expenses
        .where((e) => !e.isIncome && e.necessity == NecessityType.unnecessary)
        .fold(0, (s, e) => s + e.amount);
    final count = expenses.where((e) => !e.isIncome).length;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChartScreen(
            monthKey: monthKey,
            expenses: expenses,
            budget: budget,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 1))
          ],
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(monthLabel,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B))),
                  if (isCurrent)
                    const Text('今月',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8))),
                ]),
                Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('¥${_yen.format(total)}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFDC2626))),
                    Text('$count件',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8))),
                  ]),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right,
                      color: Color(0xFF94A3B8), size: 18),
                ]),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(children: [
              _breakdown('要（必要）', req, const Color(0xFF2563EB)),
              _divider(),
              _breakdown('不（不要）', unneeded, const Color(0xFFDC2626)),
              _divider(),
              _breakdown('件数', null, const Color(0xFF374151),
                  countLabel: '$count件'),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _breakdown(String label, int? amount, Color color,
      {String? countLabel}) =>
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF94A3B8))),
          const SizedBox(height: 3),
          Text(
            countLabel ?? '¥${_yen.format(amount ?? 0)}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color),
          ),
        ]),
      );

  Widget _divider() => Container(
      width: 1,
      height: 28,
      color: const Color(0xFFF1F5F9),
      margin: const EdgeInsets.symmetric(horizontal: 8));
}
