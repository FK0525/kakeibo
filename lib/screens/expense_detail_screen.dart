import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../providers/app_provider.dart';
import '../models/expense.dart';
import 'expense_input_screen.dart';
import 'income_input_screen.dart';

final _yen = NumberFormat('#,###', 'ja_JP');

class ExpenseDetailScreen extends StatefulWidget {
  final Expense expense;
  const ExpenseDetailScreen({super.key, required this.expense});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  bool _editingAmount = false;
  final _amountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.expense.amount.toString();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除しますか？'),
        content: const Text('この記録を削除します。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除',
                  style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AppProvider>().deleteExpense(widget.expense.id);
      Navigator.pop(context);
    }
  }

  Future<void> _saveRecurringAmount() async {
    final amount = int.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;
    await context
        .read<AppProvider>()
        .updateRecurringAmount(widget.expense.id, amount);
    setState(() => _editingAmount = false);
  }

  // 編集画面を開く
  void _openEdit() {
    final e = widget.expense;
    if (e.isIncome) {
      // 特別収入の編集
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _SpecialIncomeEditScreen(expense: e),
        ),
      ).then((_) => Navigator.pop(context));
    } else {
      // 支出の編集
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExpenseInputScreen(editExpense: e),
        ),
      ).then((_) => Navigator.pop(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;
    final isRequired = e.necessity == NecessityType.required;

    // ヒーローカラー
    Color heroBadgeColor;
    Color heroBadgeText;
    String heroBadgeLabel;

    if (e.isIncome) {
      heroBadgeColor = const Color(0xFF22C55E).withOpacity(0.25);
      heroBadgeText = const Color(0xFF6EE7B7);
      heroBadgeLabel = e.entryType == EntryType.carryover ? '↩️ 前月繰越' : '🎁 特別収入';
    } else {
      heroBadgeColor = isRequired
          ? const Color(0xFF2563EB).withOpacity(0.25)
          : const Color(0xFFDC2626).withOpacity(0.25);
      heroBadgeText = isRequired
          ? const Color(0xFF93C5FD)
          : const Color(0xFFFCA5A5);
      heroBadgeLabel = isRequired ? '要・必要な支出' : '不・不要な支出';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('詳細'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _delete,
            child: const Text('削除',
                style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF1A1A2E).withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(children: [
                Text('${e.category.emoji} ${e.displayLabel}',
                    style: const TextStyle(
                        color: Color(0x80FFFFFF), fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  e.isIncome
                      ? '＋¥${_yen.format(e.amount)}'
                      : '¥${_yen.format(e.amount)}',
                  style: TextStyle(
                      color: e.isIncome
                          ? const Color(0xFF6EE7B7)
                          : Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      height: 1),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _heroBadge(heroBadgeLabel, heroBadgeColor, heroBadgeText),
                    if (e.isRecurring) ...[
                      const SizedBox(width: 8),
                      _heroBadge('🔁 毎月計上',
                          const Color(0xFF6366F1).withOpacity(0.3),
                          const Color(0xFFA5B4FC)),
                    ],
                  ],
                ),
              ]),
            ),

            const SizedBox(height: 14),

            // 編集ボタン（繰越以外）
            if (e.entryType != EntryType.carryover) ...[
              GestureDetector(
                onTap: _openEdit,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4)
                    ],
                  ),
                  child: Row(children: [
                    const Text('✏️', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.isIncome ? 'この収入を編集する' : 'この支出を編集する',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B)),
                      ),
                    ),
                    const Text('›',
                        style: TextStyle(
                            fontSize: 18, color: Color(0xFF94A3B8))),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 詳細情報
            _detailCard([
              _row('記録日',
                  DateFormat('yyyy年M月d日 HH:mm').format(e.date)),
              _row('用途', e.displayLabel),
              if (!e.isIncome)
                _row('要・不', isRequired ? '要（必要な支出）' : '不（不要な支出）',
                    valueColor: isRequired
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFDC2626)),
              if (e.memo != null) _row('メモ', e.memo!),
            ]),

            // 特別収入の配分表示
            if (e.entryType == EntryType.specialIncome) ...[
              const SizedBox(height: 14),
              _detailCard([
                _row('使用可能に追加', '¥${_yen.format(e.usableAmount ?? 0)}',
                    valueColor: const Color(0xFF6366F1)),
                _row('貯金', '¥${_yen.format(e.savingsAmount)}',
                    valueColor: const Color(0xFF16A34A)),
              ]),
            ],

            // 割り勘表示
            if (e.hasSplit) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('🤝', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      const Text('割り勘',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF9A3412))),
                      const Spacer(),
                      if (e.splitSettled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            '✅ ${e.splitSettledAt != null ? DateFormat("M/d").format(e.splitSettledAt!) : ""} 精算済',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text('未精算',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                        ),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(children: [
                        _splitDetailRow('支払総額', '¥${_yen.format(e.amount)}', const Color(0xFF1E293B)),
                        const Divider(height: 12, color: Color(0xFFFED7AA)),
                        _splitDetailRow('🙋 自己負担（${e.splitPercent}%）',
                            '¥${_yen.format(e.selfAmount)}', const Color(0xFFF97316)),
                        const Divider(height: 12, color: Color(0xFFFED7AA)),
                        _splitDetailRow(
                            e.splitSettled ? '💚 パートナーから受取済' : '💚 パートナーから受取予定',
                            '¥${_yen.format(e.partnerAmount)}',
                            const Color(0xFF22C55E)),
                      ]),
                    ),
                  ],
                ),
              ),
            ],

            // 固定費の翌月金額変更
            if (e.isRecurring) ...[
              const SizedBox(height: 14),
              const Text('🔁 翌月以降の計上金額',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4338CA))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE0E7FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('翌月から適用する金額',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6366F1))),
                    const SizedBox(height: 8),
                    if (_editingAmount)
                      Row(children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: TextField(
                              controller: _amountCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              autofocus: true,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                prefixText: '¥ ',
                              ),
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _saveRecurringAmount,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('保存',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ])
                    else
                      Row(children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('¥${_yen.format(e.amount)}',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E293B))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _editingAmount = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('変更',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ]),
                    const SizedBox(height: 10),
                    const Text(
                      'ここで変更すると来月以降の固定費として自動計上されます。\n今月分は変更されません。',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          height: 1.6),
                    ),
                  ],
                ),
              ),
            ],

            // 写真
            if (e.photoPath != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(File(e.photoPath!),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heroBadge(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
        child: Text(text,
            style: TextStyle(
                color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
      );

  Widget _splitDetailRow(String label, String value, Color valueColor) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: valueColor)),
      ]);

  Widget _detailCard(List<Widget> children) => Container(
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
        child: Column(children: children),
      );

  Widget _row(String key, String value, {Color? valueColor}) => Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  child: Text(key,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF94A3B8))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: valueColor ?? const Color(0xFF1E293B),
                      )),
                ),
              ],
            ),
          ),
          const Divider(
              height: 1, indent: 16, color: Color(0xFFF1F5F9)),
        ],
      );
}

// 特別収入の編集画面
class _SpecialIncomeEditScreen extends StatefulWidget {
  final Expense expense;
  const _SpecialIncomeEditScreen({required this.expense});

  @override
  State<_SpecialIncomeEditScreen> createState() =>
      _SpecialIncomeEditScreenState();
}

class _SpecialIncomeEditScreenState extends State<_SpecialIncomeEditScreen> {
  late final TextEditingController _totalCtrl;
  late final TextEditingController _usableCtrl;
  late final TextEditingController _memoCtrl;

  @override
  void initState() {
    super.initState();
    _totalCtrl = TextEditingController(text: widget.expense.amount.toString());
    _usableCtrl = TextEditingController(text: (widget.expense.usableAmount ?? 0).toString());
    _memoCtrl = TextEditingController(text: widget.expense.memo ?? '');
  }

  int get _total => int.tryParse(_totalCtrl.text) ?? 0;
  int get _usable => int.tryParse(_usableCtrl.text) ?? 0;
  int get _savings => (_total - _usable).clamp(0, _total);

  final _yen = NumberFormat('#,###', 'ja_JP');

  Future<void> _submit() async {
    if (_total <= 0) return;
    await context.read<AppProvider>().updateExpense(
          id: widget.expense.id,
          amount: _total,
          category: widget.expense.category,
          necessity: widget.expense.necessity,
          usableAmount: _usable,
          memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white70,
        elevation: 0,
        title: const Text('特別収入を編集',
            style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('合計金額',
                style: TextStyle(
                    color: Color(0x80FFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('¥',
                  style: TextStyle(
                      color: Color(0x66FFFFFF),
                      fontSize: 24,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _totalCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2),
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '0',
                      hintStyle: TextStyle(
                          color: Color(0x33FFFFFF), fontSize: 44)),
                ),
              ),
            ]),
            Container(height: 1, color: Colors.white10,
                margin: const EdgeInsets.symmetric(vertical: 20)),
            const Text('配分',
                style: TextStyle(
                    color: Color(0x80FFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.4)),
              ),
              child: Row(children: [
                const Text('💰', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('使用可能金額に追加',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      Text('今月の残高に加算されます',
                          style: TextStyle(
                              color: Color(0x66FFFFFF), fontSize: 11)),
                    ],
                  ),
                ),
                Row(children: [
                  const Text('¥',
                      style: TextStyle(
                          color: Color(0x80FFFFFF), fontSize: 14)),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _usableCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      onChanged: (_) => setState(() {}),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: Color(0xFFA5B4FC),
                          fontSize: 20,
                          fontWeight: FontWeight.w900),
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                          hintStyle: TextStyle(
                              color: Color(0x40FFFFFF), fontSize: 20)),
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Text('🏦', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('貯金',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      Text('残り分が自動で貯金になります',
                          style: TextStyle(
                              color: Color(0x66FFFFFF), fontSize: 11)),
                    ],
                  ),
                ),
                Text('¥${_yen.format(_savings)}',
                    style: const TextStyle(
                        color: Color(0xFF6EE7B7),
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('メモ',
                style: TextStyle(
                    color: Color(0x80FFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _memoCtrl,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'メモを入力（任意）',
                hintStyle: const TextStyle(color: Color(0x66FFFFFF)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1A1A2E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900),
                ),
                child: const Text('保存する'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
