// =============================================================================
// FLASHCARD STUDY SCREEN — Màn hình học thẻ chính
// =============================================================================
//
// UI LAYOUT:
//   AppBar: counter + progress + nút đóng
//   Body:
//     ── Progress bar ──
//     ── FlipCardWidget (center) ──
//     ── Navigation row (prev / flip / next) ──
//     ── Action row (Review / Skip / Mastered) ──
//
// GESTURES:
//   - Tap trên card → flip
//   - Swipe trái  → markReview (đỏ)
//   - Swipe phải  → markMastered (xanh)
//
// ANIMATIONS:
//   - Card slideIn từ phải sang khi next
//   - Card slideOut sang trái khi mark
//   - Haptic feedback khi mark
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';

import '../models/flashcard_model.dart';
import '../providers/flashcard_provider.dart';
import '../widgets/flash_card_widget.dart';
import 'flashcard_result_screen.dart';

// Chuyển sang StatefulWidget để quản lý logic xác nhận thoát
class FlashCardStudyScreen extends StatefulWidget {
  final String notebookId;
  final String notebookName;

  const FlashCardStudyScreen({
    super.key,
    required this.notebookId,
    required this.notebookName,
  });

  @override
  State<FlashCardStudyScreen> createState() => _FlashCardStudyScreenState();
}

class _FlashCardStudyScreenState extends State<FlashCardStudyScreen> {

  // ── Exit confirmation ───────────────────────────────────────────────────────

  /// Hiển thị dialog xác nhận thoát phiên học flashcard.
  /// Trả về true ngay nếu đang chuyển sang màn hình kết quả (showResult == true).
  Future<bool> _showExitDialog() async {
    final provider = context.read<FlashCardProvider>();
    // Đang chuyển sang kết quả → không cần hỏi, thoát tự do
    if (provider.showResult) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // bắt buộc người dùng chọn nút
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFFA726), size: 22),
            SizedBox(width: 8),
            Flexible(child: Text('Thoát phiên học?')),
          ],
        ),
        content: const Text(
          'Tiến trình học flashcard hiện tại sẽ không được lưu.\nBạn có chắc muốn kết thúc?',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          // Hủy → tiếp tục học
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Tiếp tục học'),
          ),
          // Xác nhận → xóa state và thoát
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Kết thúc'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Xử lý thoát: hỏi xác nhận, nếu đồng ý thì clear provider và pop
  Future<void> _close() async {
    final shouldExit = await _showExitDialog();
    if (!mounted || !shouldExit) return;
    context.read<FlashCardProvider>().clear();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // PopScope: chặn Android back button trong phiên học để hỏi xác nhận
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Đóng',
            onPressed: _close, // async — hỏi xác nhận trước khi thoát
          ),
          title: Consumer<FlashCardProvider>(
            builder: (_, p, __) => Text(
              '${p.currentIndex + 1} / ${p.totalCards}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          centerTitle: true,
        ),
        body: Consumer<FlashCardProvider>(
          builder: (_, provider, __) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.error != null) {
              return _ErrorView(message: provider.error!, onRetry: () {
                provider.generateDeck(
                  notebookId: widget.notebookId,
                  notebookName: widget.notebookName,
                  numCards: provider.numCards,
                );
              });
            }
            if (provider.showResult) {
              return _ResultTransition(
                provider: provider,
                notebookId: widget.notebookId,
                notebookName: widget.notebookName,
              );
            }

            final card = provider.currentCard;
            if (card == null) return const SizedBox.shrink();

            return _StudyBody(card: card, provider: provider);
          },
        ),
      ),
    );
  }
}

// ── Study Body ───────────────────────────────────────────────────────────────

class _StudyBody extends StatefulWidget {
  final FlashCard card;
  final FlashCardProvider provider;

  const _StudyBody({required this.card, required this.provider});

  @override
  State<_StudyBody> createState() => _StudyBodyState();
}

class _StudyBodyState extends State<_StudyBody>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;


  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _animateAndMark(CardResult result, bool isRight) {
    HapticFeedback.mediumImpact();
    setState(() {
      _slideAnim = Tween<Offset>(
        begin: Offset.zero,
        end: isRight
            ? const Offset(1.2, 0)
            : const Offset(-1.2, 0),
      ).animate(CurvedAnimation(
        parent: _slideCtrl,
        curve: Curves.easeOutCubic,
      ));
    });
    _slideCtrl.forward(from: 0).then((_) {
      widget.provider.markCard(result);
      _slideCtrl.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final card = widget.card;
    final showAnswer = p.showAnswer;
    final accent = AppColors.primary;

    return Column(
      children: [
        // Progress bar
        TweenAnimationBuilder<double>(
          tween: Tween(
            begin: (p.currentIndex) / p.totalCards,
            end: (p.currentIndex + 1) / p.totalCards,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (_, value, __) => LinearProgressIndicator(
            value: value,
            backgroundColor: AppColors.border,
            color: accent,
            minHeight: 4,
          ),
        ),

        const SizedBox(height: 12),

        // Mastery indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _StatusBadge(
                icon: Icons.check_circle_rounded,
                label: '${p.completedCount}/${p.totalCards}',
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 8),
              _StatusBadge(
                icon: Icons.replay_rounded,
                label: '${p.answers.values.where((r) => r == CardResult.review).length}',
                color: const Color(0xFFFFA726),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Flip Card (with slide animation)
        Expanded(
          child: SlideTransition(
            position: _slideAnim,
            child: FlipCardWidget(
              card: card,
              showAnswer: showAnswer,
              onFlip: () => p.flipCard(),
              color: accent,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Navigation row: prev | flip | next
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NavButton(
                icon: Icons.arrow_back_rounded,
                label: 'Trước',
                onPressed: p.currentIndex > 0 ? () {
                  HapticFeedback.lightImpact();
                  p.previousCard();
                } : null,
              ),
              const SizedBox(width: 12),
              _NavButton(
                icon: Icons.flip_rounded,
                label: 'Lật thẻ',
                isPrimary: true,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  p.flipCard();
                },
              ),
              const SizedBox(width: 12),
              _NavButton(
                icon: Icons.arrow_forward_rounded,
                label: 'Tiếp',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  p.markCard(CardResult.skipped);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Action buttons: Review | Mastered
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              // Cần ôn lại (đỏ)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _animateAndMark(CardResult.review, false),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text(
                    'Cần ôn lại',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: const Color(0xFFFF6B6B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.control,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Đã thuộc (xanh)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _animateAndMark(CardResult.mastered, true),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text(
                    'Đã thuộc',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.control,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Nav Button ───────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _NavButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: isPrimary ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: isPrimary
                  ? null
                  : BoxDecoration(
                      border: Border.all(
                        color: enabled ? AppColors.border : Colors.transparent,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
              child: Icon(
                icon,
                size: 22,
                color: isPrimary
                    ? Colors.white
                    : enabled
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: enabled ? AppColors.textSecondary : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

// ── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error View ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Result Transition ────────────────────────────────────────────────────────

class _ResultTransition extends StatelessWidget {
  final FlashCardProvider provider;
  final String notebookId;
  final String notebookName;

  const _ResultTransition({
    required this.provider,
    required this.notebookId,
    required this.notebookName,
  });

  @override
  Widget build(BuildContext context) {
    final result = FlashCardResult(
      cards:    provider.deck!.cards,
      answers:  Map.from(provider.answers),
    );

    // Push result screen sau 200ms để动画 mượt
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => FlashCardResultScreen(
            result: result,
            notebookId: notebookId,
            notebookName: notebookName,
            isMock: provider.deck!.isMock,
          ),
        ),
      );
      provider.clear();
    });

    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Đang tính kết quả...'),
        ],
      ),
    );
  }
}
