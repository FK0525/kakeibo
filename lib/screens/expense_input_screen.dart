import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/app_provider.dart';
import '../models/expense.dart';

class ExpenseInputScreen extends StatefulWidget {
  final Expense? editExpense; // 編集モード時に渡す
  const ExpenseInputScreen({super.key, this.editExpense});

  @override
  State<ExpenseInputScreen> createState() => _ExpenseInputScreenState();
}

class _ExpenseInputScreenState extends State<ExpenseInputScreen> {
  final _amountCtrl = TextEditingController();
  final _customLabelCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();

  bool get _isEdit => widget.editExpense != null;

  ExpenseCategory _category = ExpenseCategory.food;
  NecessityType _necessity = NecessityType.required;
  bool _isRecurring = false;
  String? _photoPath;
  bool _saving = false;

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

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker()
        .pickImage(source: source, imageQuality: 70);
    if (picked != null) setState(() => _photoPath = picked.path);
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      _showSnack('金額を入力してください');
      return;
    }
    if (_category == ExpenseCategory.custom &&
        _customLabelCtrl.text.trim().isEmpty) {
      _showSnack('用途を入力してください');
      return;
    }
    setState(() => _saving = true);
    final p = context.read<AppProvider>();
    if (_isEdit) {
      await p.updateExpense(
        id: widget.editExpense!.id,
        amount: amount,
        category: _category,
        customLabel: _category == ExpenseCategory.custom
            ? _customLabelCtrl.text.trim()
            : null,
        necessity: _necessity,
        memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
        photoPath: _photoPath,
        isRecurring: _isRecurring,
      );
    } else {
      await p.addExpense(
          amount: amount,
          category: _category,
          customLabel: _category == ExpenseCategory.custom
              ? _customLabelCtrl.text.trim()
              : null,
          necessity: _necessity,
          memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
          photoPath: _photoPath,
          isRecurring: _isRecurring,
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
            // ── 金額 ──
            _label('金額'),
            const SizedBox(height: 8),
            _card(
              child: TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  prefixText: '¥ ',
                  prefixStyle: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8)),
                  hintText: '0',
                  hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
                ),
                style: const TextStyle(fontSize: 32,
                    fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
              ),
            ),
            const SizedBox(height: 24),

            // ── 用途 ──
            _label('用途'),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.4,
              children: _categories.map((cat) {
                final active = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() {
                    _category = cat;
                    if (cat != ExpenseCategory.fixed) _isRecurring = false;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF1A1A2E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05),
                            blurRadius: 3, offset: const Offset(0, 1))
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(cat.emoji,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(cat.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : const Color(0xFF374151),
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            // 手入力フィールド
            if (_category == ExpenseCategory.custom) ...[
              const SizedBox(height: 10),
              _card(
                child: TextField(
                  controller: _customLabelCtrl,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '用途を入力...',
                    hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
                  ),
                  style: const TextStyle(fontSize: 15,
                      color: Color(0xFF1E293B)),
                ),
              ),
            ],

            // 固定費チェック
            if (_category == ExpenseCategory.fixed) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () =>
                    setState(() => _isRecurring = !_isRecurring),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isRecurring
                        ? const Color(0xFFEEF2FF)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isRecurring
                          ? const Color(0xFFA5B4FC)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: _isRecurring
                            ? const Color(0xFF6366F1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _isRecurring
                              ? const Color(0xFF6366F1)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: _isRecurring
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('毎月固定費として計上する',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _isRecurring
                                  ? const Color(0xFF4338CA)
                                  : const Color(0xFF374151),
                            )),
                        Text('翌月から自動で支出に追加されます',
                            style: TextStyle(
                              fontSize: 11,
                              color: _isRecurring
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFF94A3B8),
                            )),
                      ],
                    ),
                  ]),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── 要・不 ──
            _label('要・不'),
            const SizedBox(height: 8),
            Row(children: [
              _necessityBtn('要　必要な支出', NecessityType.required,
                  const Color(0xFF2563EB)),
              const SizedBox(width: 12),
              _necessityBtn('不　不要な支出', NecessityType.unnecessary,
                  const Color(0xFFDC2626)),
            ]),

            const SizedBox(height: 24),

            // ── メモ ──
            _label('メモ（任意）'),
            const SizedBox(height: 8),
            _card(
              child: TextField(
                controller: _memoCtrl,
                maxLines: 3,
                maxLength: 100,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'メモを入力...',
                  hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
                  counterStyle: TextStyle(
                      fontSize: 10, color: Color(0xFFCBD5E1)),
                ),
                style: const TextStyle(fontSize: 14,
                    color: Color(0xFF1E293B), height: 1.6),
              ),
            ),

            const SizedBox(height: 24),

            // ── 写真 ──
            _label('写真（任意）'),
            const SizedBox(height: 8),
            if (_photoPath != null)
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_photoPath!),
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _photoPath = null),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ])
            else
              Row(children: [
                Expanded(
                    child: _photoBtn(Icons.camera_alt_outlined, 'カメラ',
                        () => _pickPhoto(ImageSource.camera))),
                const SizedBox(width: 12),
                Expanded(
                    child: _photoBtn(Icons.photo_library_outlined, 'アルバム',
                        () => _pickPhoto(ImageSource.gallery))),
              ]),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A2E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('記録する'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: Color(0xFF374151)));

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 4, offset: const Offset(0, 1))
      ],
    ),
    child: child,
  );

  Widget _necessityBtn(
      String label, NecessityType type, Color activeColor) {
    final active = _necessity == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _necessity = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? activeColor : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : const Color(0xFF94A3B8),
              )),
        ),
      ),
    );
  }

  Widget _photoBtn(IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 3, offset: const Offset(0, 1))
            ],
          ),
          child: Column(children: [
            Icon(icon, color: Colors.grey.shade400, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade400)),
          ]),
        ),
      );
}
