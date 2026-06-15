import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../models/expense.dart';

final _yen = NumberFormat('#,###', 'ja_JP');

class ChartScreen extends StatelessWidget {
  final String monthKey; // "2025-06"
  final List<Expense> expenses;
  final int budget; // 使用可能額

  const ChartScreen({
    super.key,
    required this.monthKey,
    required this.expenses,
    required this.budget,
  });

  @override
  Widget build(BuildContext context) {
    final spent = expenses.where((e) => !e.isIncome);
    final required = spent
        .where((e) => e.necessity == NecessityType.required)
        .fold(0, (s, e) => s + e.amount);
    final unnecessary = spent
        .where((e) => e.necessity == NecessityType.unnecessary)
        .fold(0, (s, e) => s + e.amount);
    final remaining = (budget - required - unnecessary).clamp(0, budget);

    final total = budget > 0 ? budget : (required + unnecessary);

    // カテゴリ別集計
    final Map<String, int> categoryRequired = {};
    final Map<String, int> categoryUnnecessary = {};
    for (final e in spent) {
      final label = '${e.category.emoji} ${e.category.label}';
      if (e.necessity == NecessityType.required) {
        categoryRequired[label] = (categoryRequired[label] ?? 0) + e.amount;
      } else {
        categoryUnnecessary[label] =
            (categoryUnnecessary[label] ?? 0) + e.amount;
      }
    }

    final allCategories = <MapEntry<String, int>>[
      ...categoryRequired.entries.map((e) => MapEntry('${e.key}（要）', e.value)),
      ...categoryUnnecessary.entries.map((e) => MapEntry('${e.key}（不）', e.value)),
    ]..sort((a, b) => b.value.compareTo(a.value));

    final maxCat = allCategories.isEmpty
        ? 1
        : allCategories.first.value;

    // 月タイトル
    final parts = monthKey.split('-');
    final title = '${parts[0]}年${int.parse(parts[1])}月の内訳';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 円グラフカード
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 1))
                ],
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('使用可能額に対する内訳',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600)),
                  ),
                  const SizedBox(height: 20),
                  // ドーナツ
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(200, 200),
                          painter: _DonutPainter(
                            remaining: remaining,
                            required: required,
                            unnecessary: unnecessary,
                            total: total,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('予算総額',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400)),
                            Text('¥${_yen.format(budget)}',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E293B),
                                    letterSpacing: -0.5)),
                            Text('使用可能額',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade400)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 凡例
                  _legend('残高', remaining, total, const Color(0xFF22C55E)),
                  const SizedBox(height: 10),
                  _legend('要（必要な支出）', required, total,
                      const Color(0xFF2563EB)),
                  const SizedBox(height: 10),
                  _legend('不（不要な支出）', unnecessary, total,
                      const Color(0xFFDC2626)),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // カテゴリ別
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 1))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('カテゴリ別内訳',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 12),
                  if (allCategories.isEmpty)
                    Center(
                      child: Text('支出がありません',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 13)),
                    )
                  else
                    ...allCategories.map((e) {
                      final isReq = e.key.endsWith('（要）');
                      final color = isReq
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFDC2626);
                      final ratio = maxCat > 0 ? e.value / maxCat : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(e.key,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF374151))),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: ratio.toDouble(),
                                minHeight: 6,
                                backgroundColor:
                                    const Color(0xFFF1F5F9),
                                valueColor:
                                    AlwaysStoppedAnimation(color),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 70,
                            child: Text(
                              '¥${_yen.format(e.value)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B)),
                            ),
                          ),
                        ]),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(String label, int amount, int total, Color color) {
    final pct = total > 0 ? (amount / total * 100).round() : 0;
    return Row(children: [
      Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(label,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF374151))),
      ),
      Text('¥${_yen.format(amount)}',
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B))),
      const SizedBox(width: 6),
      SizedBox(
        width: 32,
        child: Text('$pct%',
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF94A3B8))),
      ),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  final int remaining;
  final int required;
  final int unnecessary;
  final int total;

  _DonutPainter({
    required this.remaining,
    required this.required,
    required this.unnecessary,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    const strokeWidth = 28.0;
    const startAngle = -pi / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    if (total <= 0) {
      paint.color = const Color(0xFFE2E8F0);
      canvas.drawCircle(center, radius, paint);
      return;
    }

    void drawArc(Color color, int value, double start) {
      final sweep = 2 * pi * value / total;
      paint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start, sweep, false, paint,
      );
    }

    double angle = startAngle;
    drawArc(const Color(0xFF22C55E), remaining, angle);
    angle += 2 * pi * remaining / total;
    drawArc(const Color(0xFF2563EB), required, angle);
    angle += 2 * pi * required / total;
    drawArc(const Color(0xFFDC2626), unnecessary, angle);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.remaining != remaining ||
      old.required != required ||
      old.unnecessary != unnecessary ||
      old.total != total;
}
