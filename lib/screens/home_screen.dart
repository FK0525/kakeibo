import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../providers/app_provider.dart';
import '../models/expense.dart';
import '../models/transport_means.dart';
import 'expense_input_screen.dart';
import 'expense_detail_screen.dart';
import 'income_input_screen.dart';
import 'history_screen.dart';
import 'chart_screen.dart';
import 'split_screen.dart';
import 'backup_screen.dart';

final _yen = NumberFormat('#,###', 'ja_JP');

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A2E),
            title: Text(
              DateFormat('yyyy年M月').format(DateTime.now()),
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const IncomeInputScreen())),
                icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 16),
                label: const Text('収入',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const IncomeInputScreen(isSpecial: true))),
                icon: const Icon(Icons.add, color: Colors.white, size: 16),
                label: const Text('特別収入',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'バックアップ',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BackupScreen())),
                icon: const Icon(Icons.backup_outlined,
                    color: Colors.white, size: 20),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _HeaderContent(p: p),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Text('支出一覧',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151))),
                    const SizedBox(width: 6),
                    Text('${p.currentMonthExpenses.length}件',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8))),
                  ]),
                  Row(children: [
                    GestureDetector(
                      onTap: () {
                        final now = DateTime.now();
                        final key =
                            '${now.year}-${now.month.toString().padLeft(2, '0')}';
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChartScreen(
                            monthKey: key,
                            expenses: p.currentMonthExpenses,
                            budget: p.availableBudget + p.specialIncomeUsable,
                          ),
                        ));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(children: [
                          Icon(Icons.pie_chart_outline, color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text('グラフ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SplitScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: Row(children: [
                          const Text('🤝', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text('割勘', style: TextStyle(color: const Color(0xFF9A3412), fontSize: 11, fontWeight: FontWeight.w700)),
                          if (p.unsettledSplits.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF97316),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text('${p.unsettledSplits.length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const HistoryScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.history, color: Color(0xFF374151), size: 13),
                          SizedBox(width: 4),
                          Text('履歴', style: TextStyle(color: Color(0xFF374151), fontSize: 11, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),

          // 繰越通知カード
          if (p.showCarryoverNotification)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _CarryoverNotifyCard(p: p),
              ),
            ),

          p.currentMonthExpenses.isEmpty && !p.showCarryoverNotification
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Column(children: [
                        const Text('💰', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text('まだ支出がありません',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 14)),
                      ]),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final e = p.currentMonthExpenses[i];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: e.isIncome
                            ? _IncomeCard(expense: e)
                            : _ExpenseCard(expense: e),
                      );
                    },
                    childCount: p.currentMonthExpenses.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ExpenseInputScreen())),
        backgroundColor: const Color(0xFF1A1A2E),
        icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
        label: const Text('支出を入力',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ── ヘッダー ──
class _HeaderContent extends StatelessWidget {
  final AppProvider p;
  const _HeaderContent({required this.p});

  @override
  Widget build(BuildContext context) {
    final remaining = p.remainingBudget;
    final ratio = p.budgetUsageRatio;
    final isOver = remaining < 0;
    final budget = p.availableBudget;
    final carryover = p.carryoverDisplay;
    // 繰越を除く今月の使用可能ベース（通常予算＋特別収入の使用可能分）
    final usableBase = budget + p.specialIncomeUsable;
    // 通常予算が未設定でも、特別収入や繰越があれば残高を表示する
    final hasBalance = usableBase > 0 || carryover != 0;

    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.fromLTRB(20, 90, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('使用可能残高',
              style: TextStyle(color: Color(0x80FFFFFF), fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            hasBalance ? '¥${_yen.format(remaining)}' : '未設定',
            style: TextStyle(
              color: isOver ? const Color(0xFFFF8A8A) : Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          if (hasBalance) ...[
            const SizedBox(height: 4),
            Text(
              carryover != 0
                  ? '使用可能 ¥${_yen.format(usableBase)} ${carryover >= 0 ? "＋" : "−"} 前月繰越 ¥${_yen.format(carryover.abs())}'
                  : '使用可能 ¥${_yen.format(usableBase)} のうち残り${((1 - ratio) * 100).toInt()}%',
              style: const TextStyle(
                  color: Color(0x66FFFFFF), fontSize: 11),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(ratio > 0.8
                    ? const Color(0xFFFF8A8A)
                    : const Color(0xFF818CF8)),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              _stat('今月予算', '¥${_yen.format(budget)}', Colors.white),
              _divider(),
              _stat('支出', '¥${_yen.format(p.totalSpent)}',
                  const Color(0xFFFF8A8A)),
              _divider(),
              _stat('貯金予定', '¥${_yen.format(p.totalSavings)}',
                  const Color(0xFF6EE7B7)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Column(children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0x66FFFFFF), fontSize: 10)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900)),
        ]),
      );

  Widget _divider() => Container(
      width: 1,
      height: 28,
      color: Colors.white10,
      margin: const EdgeInsets.symmetric(horizontal: 4));
}

// ── 繰越通知カード ──
class _CarryoverNotifyCard extends StatelessWidget {
  final AppProvider p;
  const _CarryoverNotifyCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final amount = p.carryoverDisplay;
    final isPlus = amount >= 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPlus
              ? [const Color(0xFFEEF2FF), const Color(0xFFF5F3FF)]
              : [const Color(0xFFFFF1F2), const Color(0xFFFFF7F7)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPlus
              ? const Color(0xFFA5B4FC)
              : const Color(0xFFFCA5A5),
          width: 1.5,
          // ignore: deprecated_member_use
        ),
      ),
      child: Row(children: [
        Text(isPlus ? '↩️' : '⚠️',
            style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '前月からの繰越',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isPlus
                        ? const Color(0xFF6366F1)
                        : const Color(0xFFDC2626)),
              ),
              Text(
                '${isPlus ? "＋" : "−"}¥${_yen.format(amount.abs())}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isPlus
                        ? const Color(0xFF4338CA)
                        : const Color(0xFFDC2626)),
              ),
              const Text('✕ を押して一覧に追加',
                  style: TextStyle(
                      fontSize: 10, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.read<AppProvider>().confirmCarryover(),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4)
              ],
            ),
            child: const Center(
              child: Text('✕',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF94A3B8))),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── 収入カード（特別収入・繰越確定後）──
class _IncomeCard extends StatelessWidget {
  final Expense expense;
  const _IncomeCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final isCarryover = expense.entryType == EntryType.carryover;
    final isSettlement = expense.entryType == EntryType.splitSettlement;
    final isRegularIncome = expense.entryType == EntryType.income;
    final hasMemo = expense.memo != null && expense.memo!.trim().isNotEmpty;
    final title = hasMemo ? expense.memo! : expense.displayLabel;
    final sub = hasMemo ? expense.displayLabel : null;

    String emoji;
    if (isCarryover) emoji = '↩️';
    else if (isSettlement) emoji = '🤝';
    else if (isRegularIncome) emoji = '💼';
    else emoji = '🎁';

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => ExpenseDetailScreen(expense: expense))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)]),
          borderRadius: BorderRadius.circular(14),
          border: const Border(left: BorderSide(color: Color(0xFF22C55E), width: 3)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(title,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                      ),
                      const SizedBox(width: 8),
                      Text('＋¥${_yen.format(expense.amount)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                    ],
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(100)),
                      child: Text(
                        isCarryover ? '↩️ 繰越' :
                        isSettlement ? '🤝 精算' :
                        isRegularIncome ? '💼 収入' : '🎁 特別収入',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(100)),
                      child: Text(DateFormat('M/d HH:mm').format(expense.date),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 支出カード ──
class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final isRequired = expense.necessity == NecessityType.required;
    final hasMemo = expense.memo != null && expense.memo!.trim().isNotEmpty;
    final route = expense.transportRoute;
    final title = hasMemo ? expense.memo! : expense.displayLabel;
    final sub = hasMemo
        ? (route != null ? '${expense.displayLabel}・$route' : expense.displayLabel)
        : route;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => ExpenseDetailScreen(expense: expense))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: expense.isRecurring
              ? const Border(
                  left: BorderSide(
                      color: Color(0xFF6366F1), width: 3))
              : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 1))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isRequired
                    ? const Color(0xFF2563EB).withOpacity(0.08)
                    : const Color(0xFFDC2626).withOpacity(0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: Text(expense.category.emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '¥${_yen.format(expense.selfAmount)}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _badge(isRequired ? '要' : '不',
                          isRequired ? const Color(0xFF2563EB) : const Color(0xFFDC2626),
                          isRequired ? const Color(0xFFDBEAFE) : const Color(0xFFFEE2E2)),
                      if (expense.category == ExpenseCategory.transport &&
                          expense.transportMeans != null)
                        _badge(
                          '${expense.transportMeans!.emoji} ${expense.transportMeans!.label}',
                          const Color(0xFF0369A1),
                          const Color(0xFFE0F2FE)),
                      if (expense.isRecurring)
                        _badge('🔁 毎月', const Color(0xFF7C3AED), const Color(0xFFEDE9FE)),
                      if (expense.hasSplit)
                        _badge(
                          '🤝 割勘 ¥${_yen.format(expense.selfAmount)}/${_yen.format(expense.amount)}',
                          const Color(0xFFEA580C),
                          const Color(0xFFFFF7ED),
                          borderColor: const Color(0xFFFED7AA),
                        ),
                      _badge(
                        DateFormat('M/d HH:mm').format(expense.date),
                        const Color(0xFF64748B),
                        const Color(0xFFF1F5F9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color textColor, Color bgColor, {Color? borderColor}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(100),
          border: borderColor != null ? Border.all(color: borderColor) : null,
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: textColor)),
      );
}
