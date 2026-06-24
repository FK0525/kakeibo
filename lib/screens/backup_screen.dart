import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// データのバックアップ（エクスポート）と復元（インポート）。
/// 端末の故障・再インストール・機種変更でもデータを取り戻せるようにするための画面。
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _importCtrl = TextEditingController();
  String _exportText = '';

  @override
  void initState() {
    super.initState();
    _exportText = context.read<AppProvider>().exportJson();
  }

  @override
  void dispose() {
    _importCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _copyExport() async {
    await Clipboard.setData(ClipboardData(text: _exportText));
    if (mounted) _snack('バックアップをコピーしました。メモ・メール・ドライブ等に貼り付けて保存してください');
  }

  Future<void> _pasteImport() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null && d!.text!.trim().isNotEmpty) {
      setState(() => _importCtrl.text = d.text!);
    } else {
      _snack('クリップボードが空です');
    }
  }

  Future<void> _import() async {
    final text = _importCtrl.text.trim();
    if (text.isEmpty) {
      _snack('復元するデータを貼り付けてください');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('データを復元しますか？'),
        content: const Text('現在のデータはすべて置き換えられます。\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('復元',
                  style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<AppProvider>().importJson(text);
      if (mounted) {
        _snack('復元しました');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _snack('復元に失敗しました：${e is FormatException ? e.message : e}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final expenseCount = p.expenses.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('データのバックアップ'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // エクスポート
            _card(children: [
              const Text('📤 バックアップを取り出す',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 6),
              Text('現在のデータ（$expenseCount 件の記録 ＋ 月次設定）を書き出します。\n下のボタンでコピーして、メモ・メール・クラウドなど安全な場所に保存してください。',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B), height: 1.5)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 140,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _exportText,
                    style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Color(0xFF334155)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _copyExport,
                  icon: const Icon(Icons.copy, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A2E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  label: const Text('コピーする',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ]),

            const SizedBox(height: 14),

            // インポート
            _card(children: [
              const Text('📥 バックアップから復元する',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 6),
              const Text('保存しておいたバックアップのテキストを貼り付けて復元します。\n現在のデータは置き換えられます。',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF64748B), height: 1.5)),
              const SizedBox(height: 12),
              TextField(
                controller: _importCtrl,
                maxLines: 6,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'ここにバックアップのテキストを貼り付け',
                  hintStyle: const TextStyle(fontSize: 12, fontFamily: null),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pasteImport,
                    icon: const Icon(Icons.paste, size: 18),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A1A2E),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    label: const Text('貼り付け'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _import,
                    icon: const Icon(Icons.restore, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    label: const Text('復元する',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ]),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}
