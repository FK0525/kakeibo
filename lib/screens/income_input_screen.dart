import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';

final _yen = NumberFormat('#,###', 'ja_JP');

class IncomeInputScreen extends StatefulWidget {
  final bool isSpecial;
  const IncomeInputScreen({super.key, this.isSpecial = false});

  @override
  State<IncomeInputScreen> createState() => _IncomeInputScreenState();
}

class _IncomeInputScreenState extends State<IncomeInputScreen> {
  final _totalCtrl = TextEditingController();
  final _usableCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();

  int get _total => int.tryParse(_totalCtrl.text.replaceAll(',', '')) ?? 0;
  int get _usable => int.tryParse(_usableCtrl.text.replaceAll(',', '')) ?? 0;
  int get _savings => (_total - _usable).clamp(0, _total);

  Future<void> _submit() async {
    if (_total <= 0) {
      _showSnack('金額を入力してください');
      return;
    }
    if (widget.isSpecial && _usable > _total) {
      _showSnack('使用可能金額が合計を超えています');
      return;
    }

    final p = context.read<AppProvider>();
    final memo = _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim();
    if (widget.isSpecial) {
      await p.addSpecialIncome(_total, _usable, memo: memo);
    } else {
      await p.setIncome(_total);
    }
    if (mounted) Navigator.pop(context);
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white70,
        elevation: 0,
        title: Text(
          widget.isSpecial ? '特別収入' : '今月の収入',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isSpecial ? 'いくら入りましたか？' : '今月いくら入りましたか？',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              widget.isSpecial ? '金額と配分を入力してください' : '手取り金額を入力してください',
              style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 14),
            ),
            const SizedBox(height: 36),

            // 合計金額
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('¥',
                    style: TextStyle(
                        color: Color(0x66FFFFFF),
                        fontSize: 28,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _totalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '0',
                      hintStyle: TextStyle(color: Color(0x33FFFFFF), fontSize: 48),
                    ),
                  ),
                ),
              ],
            ),

            if (widget.isSpecial && _total > 0) ...[
              const SizedBox(height: 8),
              Container(
                height: 1,
                color: Colors.white10,
                margin: const EdgeInsets.only(bottom: 24),
              ),

              const Text('この収入の配分',
                  style: TextStyle(
                      color: Color(0x80FFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
              const SizedBox(height: 12),

              // 使用可能金額
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('使用可能金額に追加',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        const Text('今月の残高に加算されます',
                            style: TextStyle(
                                color: Color(0x66FFFFFF), fontSize: 11)),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
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
                                color: Color(0x40FFFFFF), fontSize: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),
              ),

              const SizedBox(height: 10),

              // 貯金（自動計算）
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Text('🏦', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('貯金',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        const Text('残り分が自動で貯金になります',
                            style: TextStyle(
                                color: Color(0x66FFFFFF), fontSize: 11)),
                      ],
                    ),
                  ),
                  Text(
                    '¥${_yen.format(_savings)}',
                    style: const TextStyle(
                        color: Color(0xFF6EE7B7),
                        fontSize: 20,
                        fontWeight: FontWeight.w900),
                  ),
                ]),
              ),

              // メモ
              const SizedBox(height: 16),
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
            ],

            const SizedBox(height: 40),

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
                child: const Text('設定する'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
