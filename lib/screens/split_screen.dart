import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/expense.dart';
import 'expense_detail_screen.dart';

final _yen = NumberFormat('#,###', 'ja_JP');

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen>
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

  Future<void> _settleAll() async {
    final p = context.read<AppProvider>();
    final total = p.unsettledTotal;
    final count = p.unsettledSplits.length;
    if (count == 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('精算しますか？'),
        content: Text('$count件・¥${_yen.format(total)}\nをパートナーから受取済みとして記録します。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('精算する', style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await p.settleAllSplits();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¥${_yen.format(total)} の精算を記録しました')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final unsettled = p.unsettledSplits;
    final settled = p.settledSplits;
    final unsettledTotal = p.unsettledTotal;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('割り勘'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFFF97316),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: '未精算 (${unsettled.length})'),
            Tab(text: '精算済 (${settled.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // サマリ
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('パートナーから受取予定',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text('¥${_yen.format(unsettledTotal)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1)),
                const SizedBox(height: 8),
                Row(children: [
                  Text('📋 未精算 ${unsettled.length}件',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(width: 14),
                  Text('✅ 精算済 ${settled.length}件',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ],
            ),
          ),

          if (unsettled.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _settleAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFF97316),
                    side: const BorderSide(color: Color(0xFFF97316), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('💰 ¥${_yen.format(unsettledTotal)} をまとめて精算する',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                ),
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildList(unsettled, false),
                _buildList(settled, true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Expense> list, bool isSettled) {
    if (list.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(isSettled ? '✅' : '🤝', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            isSettled ? '精算済みの記録はまだありません' : '未精算の割り勘はありません',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _SplitCard(expense: list[i], isSettled: isSettled),
    );
  }
}

class _SplitCard extends StatelessWidget {
  final Expense expense;
  final bool isSettled;
  const _SplitCard({required this.expense, required this.isSettled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ExpenseDetailScreen(expense: expense))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text(expense.category.emoji, style: const TextStyle(fontSize: 14))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  expense.memo?.trim().isNotEmpty == true ? expense.memo! : expense.category.label,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                ),
                Text(
                  '${expense.category.label}・${DateFormat('M月d日').format(expense.date)}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ])),
              Text('${expense.splitPercent}%',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFF97316), fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Expanded(child: _amountColumn('総額', '¥${_yen.format(expense.amount)}', const Color(0xFF1E293B))),
                Container(width: 1, height: 28, color: const Color(0xFFFED7AA)),
                Expanded(child: _amountColumn('自己', '¥${_yen.format(expense.selfAmount)}', const Color(0xFFF97316))),
                Container(width: 1, height: 28, color: const Color(0xFFFED7AA)),
                Expanded(child: _amountColumn(
                    isSettled ? '受取済' : '受取予定',
                    '¥${_yen.format(expense.partnerAmount)}',
                    isSettled ? const Color(0xFF94A3B8) : const Color(0xFF22C55E))),
              ]),
            ),
            if (isSettled && expense.splitSettledAt != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(100)),
                  child: Text('✅ ${DateFormat('M/d').format(expense.splitSettledAt!)} 精算済',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _amountColumn(String label, String value, Color color) =>
      Column(children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9A3412))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
      ]);
}
