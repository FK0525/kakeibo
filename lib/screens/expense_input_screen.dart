import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../providers/app_provider.dart';
import '../models/expense.dart';
import '../models/split_type.dart';

final _yen = NumberFormat('#,###', 'ja_JP');

class ExpenseInputScreen extends StatefulWidget {
  final Expense? editExpense;
  const ExpenseInputScreen({super.key, this.editExpense});

  @override
  State<ExpenseInputScreen> createState() => _ExpenseInputScreenState();
}

class _ExpenseInputScreenState extends State<ExpenseInputScreen> {
  final _amountCtrl = TextEditingController();
  final _customLabelCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  final _customPctCtrl = TextEditingController(text: '50');

  ExpenseCategory _category = ExpenseCategory.food;
  NecessityType _necessity = NecessityType.required;
  bool _isRecurring = false;
  String? _photoPath;
  bool _saving = false;

  SplitType _splitType = SplitType.none;
  int _splitPercent = 0;

  bool get _isEdit => widget.editExpense != null;
  bool get _splitOn => _splitType != SplitType.none;

  int get _amount => int.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
  int get _selfAmount => _splitOn ? (_amount * _splitPercent / 100).round() : _amount;
  int get _partnerAmount => _amount - _selfAmount;

  @override
  void initState() {
    super.initState();
    final e = widget.editExpense;
    if (e != null) {
      _amountCtrl.text = e.amount.toString();
      _category = e.category;
      _necessity = e.necessity;
      _isRecurring = e.isRecurring;
      _photoPath = e.photoPath;
      if (e.customLabel != null) _customLabelCtrl.text = e.customLabel!;
      if (e.memo != null) _memoCtrl.text = e.memo!;
      _splitType = e.splitType;
      _splitPercent = e.splitPercent;
      if (e.splitType == SplitType.custom) {
        _customPctCtrl.text = e.splitPercent.toString();
      }
    }
  }

  static const _categories = [
    ExpenseCategory.music,
    ExpenseCategory.food,
    ExpenseCategory.goods,
    ExpenseCategory.service,
    ExpenseCategory.fixed,
    ExpenseCategory.custom,
  ];

  void _onSplitTypeChanged(SplitType t) {
    setState(() {
      _splitType = t;
      if (t == SplitType.food75) {
        _splitPercent = 75;
        _category = ExpenseCategory.food;  // 食事カテゴリ
        _necessity = NecessityType.required;
        _isRecurring = false;
      } else if (t == SplitType.daily50) {
        _splitPercent = 50;
        _category = ExpenseCategory.goods;  // ものカテゴリ
        _necessity = NecessityType.required;
        _isRecurring = false;
      } else if (t == SplitType.custom) {
        _splitPercent = int.tryParse(_customPctCtrl.text) ?? 50;
        _necessity = NecessityType.required;
        _isRecurring = false;
      } else {
        _splitPercent = 0;
      }
    });
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF1A1A2E)),
              title: const Text('カメラで撮影', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF1A1A2E)),
              title: const Text('ギャラリーから選択', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            if (_photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                title: const Text('写真を削除', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _photoPath = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final img = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (img != null) setState(() => _photoPath = img.path);
  }

  Future<void> _submit() async {
    if (_amount <= 0) { _showSnack('金額を入力してください'); return; }
    if (_category == ExpenseCategory.custom && _customLabelCtrl.text.trim().isEmpty) {
      _showSnack('カスタム用途名を入力してください'); return;
    }
    if (_splitType == SplitType.custom) {
      final pct = int.tryParse(_customPctCtrl.text) ?? -1;
      if (pct < 0 || pct > 100) { _showSnack('割合は0〜100で入力してください'); return; }
      _splitPercent = pct;
    }

    setState(() => _saving = true);
    final p = context.read<AppProvider>();
    if (_isEdit) {
      await p.updateExpense(
        id: widget.editExpense!.id,
        amount: _amount,
        category: _category,
        customLabel: _category == ExpenseCategory.custom ? _customLabelCtrl.text.trim() : null,
        necessity: _necessity,
        memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
        photoPath: _photoPath,
        isRecurring: _isRecurring,
        splitType: _splitType,
        splitPercent: _splitPercent,
      );
    } else {
      await p.addExpense(
        amount: _amount,
        category: _category,
        customLabel: _category == ExpenseCategory.custom ? _customLabelCtrl.text.trim() : null,
        necessity: _necessity,
        memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
        photoPath: _photoPath,
        isRecurring: _isRecurring,
        splitType: _splitType,
        splitPercent: _splitPercent,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(_isEdit ? '支出を編集' : '支出を入力'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('金額', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('¥', style: TextStyle(fontSize: 22, color: Color(0xFFCBD5E1))),
                const SizedBox(width: 6),
                Expanded(child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofocus: !_isEdit,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -1),
                  decoration: const InputDecoration(border: InputBorder.none, hintText: '0', hintStyle: TextStyle(color: Color(0xFFCBD5E1))),
                )),
              ]),
            ])),

            const SizedBox(height: 12),

            GestureDetector(
              onTap: () => _onSplitTypeChanged(_splitOn ? SplitType.none : SplitType.daily50),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _splitOn ? const Color(0xFFF97316) : const Color(0xFFE2E8F0), width: 2),
                ),
                child: Row(children: [
                  const Text('🤝', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('割り勘で支払う', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                    Text('パートナーと共有して精算する', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ])),
                  Container(
                    width: 44, height: 24,
                    decoration: BoxDecoration(color: _splitOn ? const Color(0xFFF97316) : const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(100)),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 150),
                      alignment: _splitOn ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 20, height: 20, margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 2)]),
                      ),
                    ),
                  ),
                ]),
              ),
            ),

            if (_splitOn) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('⚙️ 割り勘の設定', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9A3412))),
                  const SizedBox(height: 10),
                  Row(children: [
                    _splitTypeBtn(SplitType.food75, '75%', '食事'),
                    const SizedBox(width: 6),
                    _splitTypeBtn(SplitType.daily50, '50%', '日用品'),
                    const SizedBox(width: 6),
                    _splitTypeBtn(SplitType.custom, '…%', 'カスタム'),
                  ]),
                  if (_splitType == SplitType.custom) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      const Text('自己負担: ', style: TextStyle(fontSize: 12, color: Color(0xFF9A3412))),
                      SizedBox(width: 60, child: TextField(
                        controller: _customPctCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                        onChanged: (v) {
                          final p = int.tryParse(v) ?? 0;
                          setState(() => _splitPercent = p.clamp(0, 100));
                        },
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          border: OutlineInputBorder(), filled: true, fillColor: Colors.white,
                        ),
                      )),
                      const Text(' %', style: TextStyle(fontSize: 12, color: Color(0xFF9A3412))),
                    ]),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFED7AA))),
                    child: Column(children: [
                      _splitResultRow('支払総額', '¥${_yen.format(_amount)}', const Color(0xFF1E293B)),
                      Divider(height: 12, color: const Color(0xFFFED7AA).withOpacity(0.5)),
                      _splitResultRow('🙋 自己負担（$_splitPercent%）', '¥${_yen.format(_selfAmount)}', const Color(0xFFF97316)),
                      Divider(height: 12, color: const Color(0xFFFED7AA).withOpacity(0.5)),
                      _splitResultRow('💚 パートナーから受取', '¥${_yen.format(_partnerAmount)}', const Color(0xFF22C55E)),
                    ]),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 12),

            // カテゴリ（割り勘OFF時のみ）
            if (!_splitOn) ...[
              _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('カテゴリ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8,
                  childAspectRatio: 2.0, shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _categories.map((c) {
                    final active = _category == c;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _category = c;
                        if (c != ExpenseCategory.fixed) _isRecurring = false;
                      }),
                      child: Container(
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF1A1A2E) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: active ? const Color(0xFF1A1A2E) : const Color(0xFFE2E8F0), width: 1.5),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(c.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 2),
                          Text(c.label, style: TextStyle(fontSize: 11, color: active ? Colors.white : const Color(0xFF374151))),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                if (_category == ExpenseCategory.custom) ...[
                  const SizedBox(height: 8),
                  TextField(controller: _customLabelCtrl, decoration: const InputDecoration(labelText: 'カテゴリ名', border: OutlineInputBorder())),
                ],
              ])),

              const SizedBox(height: 12),

              // 要・不
              _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('要・不', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _necessityBtn(NecessityType.required, '要（必要）', const Color(0xFF2563EB))),
                  const SizedBox(width: 8),
                  Expanded(child: _necessityBtn(NecessityType.unnecessary, '不（不要）', const Color(0xFFDC2626))),
                ]),
              ])),

              const SizedBox(height: 12),

              // 毎月計上（固定費カテゴリ選択時のみ）
              if (_category == ExpenseCategory.fixed)
                _card(child: GestureDetector(
                  onTap: () => setState(() => _isRecurring = !_isRecurring),
                  child: Row(children: [
                    const Text('🔁', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('毎月計上する（固定費）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)))),
                    Switch(value: _isRecurring, activeColor: const Color(0xFF6366F1), onChanged: (v) => setState(() => _isRecurring = v)),
                  ]),
                )),

              if (_category == ExpenseCategory.fixed) const SizedBox(height: 12),
            ],

            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('メモ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
              const SizedBox(height: 8),
              TextField(controller: _memoCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'メモを入力（任意）', border: OutlineInputBorder())),
            ])),

            const SizedBox(height: 12),

            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('写真', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
              const SizedBox(height: 8),
              if (_photoPath != null) ...[
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_photoPath!), height: 120, width: double.infinity, fit: BoxFit.cover)),
                const SizedBox(height: 8),
              ],
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text(
                    _photoPath != null ? '📷 写真を変更・削除' : '📷 撮影 / ギャラリーから選択',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                  )),
                ),
              ),
            ])),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A2E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_isEdit ? '保存する' : '支出を登録する', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
    child: child,
  );

  Widget _splitTypeBtn(SplitType type, String pct, String label) {
    final active = _splitType == type;
    return Expanded(child: GestureDetector(
      onTap: () => _onSplitTypeChanged(type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF97316) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? const Color(0xFFF97316) : const Color(0xFFE2E8F0), width: 1.5),
        ),
        child: Column(children: [
          Text(pct, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: active ? Colors.white : const Color(0xFF64748B))),
          Text(label, style: TextStyle(fontSize: 10, color: active ? Colors.white : const Color(0xFF64748B))),
        ]),
      ),
    ));
  }

  Widget _splitResultRow(String label, String value, Color valueColor) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: valueColor)),
      ]);

  Widget _necessityBtn(NecessityType t, String label, Color color) {
    final active = _necessity == t;
    return GestureDetector(
      onTap: () => setState(() => _necessity = t),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : const Color(0xFFE2E8F0), width: 1.5),
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : const Color(0xFF64748B)))),
      ),
    );
  }
}