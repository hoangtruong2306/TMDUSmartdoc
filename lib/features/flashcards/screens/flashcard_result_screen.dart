// =============================================================================
// FLASHCARD RESULT SCREEN — Thống kê sau khi hoàn thành bộ thẻ
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';

import '../../flashcards/models/flashcard_model.dart';
import '../../flashcards/providers/flashcard_provider.dart';
import 'flashcard_study_screen.dart';

class FlashCardResultScreen extends StatelessWidget {
  final FlashCardResult result;
  final String notebookId;
  final String notebookName;
  final bool isMock;

  const FlashCardResultScreen({
    super.key,
    required this.result,
    required this.notebookId,
    required this.notebookName,
    this.isMock = false,
  });

  Color get _scoreColor {
    final pct = result.scorePct;
    if (pct >= 80) return const Color(0xFF4CAF50);
    if (pct >= 50) return const Color(0xFFFFA726);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Kết quả học', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Score circle
            Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _scoreColor.withValues(alpha: 0.08),
                border: Border.all(color: _scoreColor, width: 3),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${result.scorePct}%',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: _scoreColor,
                      ),
                    ),
                    Text(
                      '${result.masteredCount}/${result.total}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _scoreColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              result.scorePct >= 80
                  ? 'Xuất sắc! 🎉'
                  : result.scorePct >= 50
                      ? 'Đang tiến bộ 💪'
                      : 'Cần ôn thêm 📚',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Mastered ${result.masteredCount} · Ôn lại ${result.reviewCount} · Bỏ qua ${result.skippedCount}',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),

            // Mock notice
            if (isMock) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: AppRadius.control,
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đây là thẻ mẫu. Tải tài liệu vào notebook để nhận thẻ từ nội dung thực.',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade800, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Stats breakdown
            _StatCard(
              icon: Icons.check_circle_rounded,
              label: 'Đã thuộc',
              count: result.masteredCount,
              color: const Color(0xFF4CAF50),
              total: result.total,
            ),
            const SizedBox(height: 8),
            _StatCard(
              icon: Icons.replay_rounded,
              label: 'Cần ôn lại',
              count: result.reviewCount,
              color: const Color(0xFFFFA726),
              total: result.total,
            ),
            const SizedBox(height: 8),
            _StatCard(
              icon: Icons.skip_next_rounded,
              label: 'Bỏ qua',
              count: result.skippedCount,
              color: AppColors.textTertiary,
              total: result.total,
            ),

            const SizedBox(height: 28),

            // Action buttons
            FilledButton.icon(
              onPressed: () {
                final p = context.read<FlashCardProvider>();
                p.resetSession();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => FlashCardStudyScreen(
                      notebookId: notebookId,
                      notebookName: notebookName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Làm lại bộ này', style: TextStyle(fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Quay lại notebook', style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final int total;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.control,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
