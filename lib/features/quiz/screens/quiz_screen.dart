// =============================================================================
// QUIZ SCREEN — Màn hình làm bài trắc nghiệm từ nội dung notebook
// =============================================================================
//
// CẤU TRÚC WIDGET TREE:
//
//   QuizScreen (StatefulWidget)
//   └── Scaffold
//       ├── AppBar  (tiêu đề + bộ đếm câu)
//       └── Body  (switch theo trạng thái provider)
//           ├── _LoadingView     → đang gọi API
//           ├── _ErrorView       → API lỗi + nút thử lại
//           ├── _QuestionView    → câu hỏi hiện tại
//           └── _ResultView      → kết quả sau câu cuối
//
// STATE FLOW (xem quiz_provider.dart để biết chi tiết):
//   initState → generateQuiz() → loading → questioning → ... → result
//
// ANIMATION:
//   AnimatedSwitcher: chuyển giữa các view với fade + scale nhẹ
//   AnimatedContainer: highlight đáp án đúng/sai khi chọn (200ms)
//
// COLOR CODING sau khi chọn đáp án:
//   Đúng    → xanh lá (Colors.green)
//   Sai     → đỏ (AppColors.error)
//   Không chọn → không đổi màu
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../providers/quiz_provider.dart';
import '../models/quiz_model.dart';

class QuizScreen extends StatefulWidget {
  final String notebookId;
  final String notebookName;

  const QuizScreen({
    super.key,
    required this.notebookId,
    required this.notebookName,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  @override
  void initState() {
    super.initState();
    // Gọi sau frame đầu để context.read() hoạt động đúng
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  /// Trigger gọi API generate quiz với tham số mặc định (5 câu, medium)
  void _generate() {
    context.read<QuizProvider>().generateQuiz(
          notebookId: widget.notebookId,
          numQuestions: 5,
          difficulty: 'medium',
        );
  }

  /// Đóng màn hình: clear state để lần sau mở lại sạch
  void _close() {
    context.read<QuizProvider>().clear();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuizProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Đóng quiz',
          onPressed: _close,
        ),
        title: Text(
          'Luyện thi — ${widget.notebookName}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Bộ đếm "Câu X/N" chỉ hiển thị khi đang làm bài
          if (!provider.isLoading &&
              provider.result != null &&
              !provider.showResult)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${provider.currentIndex + 1} / ${provider.totalQuestions}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      // AnimatedSwitcher: chuyển view với fade + scale nhẹ
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: _buildBody(provider),
      ),
    );
  }

  // ── Body switch theo trạng thái provider ────────────────────────────────────
  Widget _buildBody(QuizProvider provider) {
    if (provider.isLoading) {
      return _LoadingView(key: const ValueKey('loading'));
    }
    if (provider.error != null) {
      return _ErrorView(
        key: const ValueKey('error'),
        message: provider.error!,
        onRetry: _generate,
      );
    }
    if (provider.showResult) {
      return _ResultView(
        key: const ValueKey('result'),
        provider: provider,
        onRedo: provider.reset,
        onNewSet: _generate,
      );
    }

    final question = provider.currentQuestion;
    if (question == null) return const SizedBox.shrink(key: ValueKey('empty'));

    // Key = currentIndex để AnimatedSwitcher detect thay đổi khi đổi câu
    return _QuestionView(
      key: ValueKey('question_${provider.currentIndex}'),
      question: question,
      index: provider.currentIndex,
      total: provider.totalQuestions,
      selectedAnswer: provider.answers[provider.currentIndex],
      onSelect: provider.selectAnswer,
      onNext: provider.answers.containsKey(provider.currentIndex)
          ? provider.nextQuestion
          : null, // null → nút Next ẩn (chưa chọn đáp án)
      isLast: provider.isLastQuestion,
      isMock: provider.result?.isMock ?? false,
    );
  }
}

// =============================================================================
// _LoadingView — Spinner khi đang gọi API
// =============================================================================
class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'AI đang tạo câu hỏi từ tài liệu...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thường mất 5-15 giây',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _ErrorView — Hiển thị lỗi + nút thử lại
// =============================================================================
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(160, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _QuestionView — Hiển thị một câu hỏi + 4 lựa chọn
// =============================================================================
//
// THUẬT TOÁN COLOR CODING:
//   Trước khi chọn (_answered = false):
//     → tất cả option màu surfaceElevated, border bình thường
//
//   Sau khi chọn (_answered = true):
//     → option đúng  (letter == correct) → xanh lá
//     → option sai đã chọn (letter == selectedAnswer && != correct) → đỏ
//     → option còn lại → không đổi
//
//   Animation: AnimatedContainer 200ms → highlight xuất hiện mượt mà
//
// PROGRESS BAR:
//   LinearProgressIndicator ở đầu → value = (index+1) / total
//   → trực quan tiến độ làm bài
//
class _QuestionView extends StatelessWidget {
  final QuizQuestion question;
  final int index;
  final int total;
  final String? selectedAnswer;  // null = chưa chọn
  final ValueChanged<String> onSelect;
  final VoidCallback? onNext;    // null = ẩn nút Next
  final bool isLast;
  final bool isMock;

  const _QuestionView({
    super.key,
    required this.question,
    required this.index,
    required this.total,
    required this.selectedAnswer,
    required this.onSelect,
    required this.onNext,
    required this.isLast,
    required this.isMock,
  });

  bool get _answered => selectedAnswer != null;

  // ── Color helpers ──────────────────────────────────────────────────────────

  /// Màu nền của một option sau khi đã chọn đáp án
  Color _optionBg(String letter) {
    if (!_answered) return AppColors.surfaceElevated;
    if (letter == question.correct) return const Color(0xFFE8F5E9); // xanh lá nhạt
    if (letter == selectedAnswer)   return const Color(0xFFFFEBEE); // đỏ nhạt
    return AppColors.surfaceElevated;
  }

  /// Màu viền của một option sau khi đã chọn đáp án
  Color _optionBorder(String letter) {
    if (!_answered) return AppColors.border;
    if (letter == question.correct) return Colors.green.shade400;
    if (letter == selectedAnswer)   return AppColors.error;
    return AppColors.border;
  }

  @override
  Widget build(BuildContext context) {
    const letters = ['A', 'B', 'C', 'D'];

    return Column(
      children: [
        // ── Progress bar ──────────────────────────────────────────────────────
        TweenAnimationBuilder<double>(
          tween: Tween(begin: index / total, end: (index + 1) / total),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          builder: (_, value, __) => LinearProgressIndicator(
            value: value,
            backgroundColor: AppColors.border,
            color: AppColors.primary,
            minHeight: 4,
          ),
        ),

        // ── Mock banner ───────────────────────────────────────────────────────
        if (isMock)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.orange.shade50,
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Text(
                  'Câu hỏi mẫu — Tải tài liệu để nhận câu hỏi từ nội dung thực',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),

        // ── Nội dung câu hỏi + options ────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card câu hỏi
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: AppRadius.card,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Câu ${index + 1} / $total',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        question.question,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Options A → D
                ...question.options.asMap().entries.map((entry) {
                  final letter = letters[entry.key];
                  final optionText = entry.value;
                  final isCorrect = _answered && letter == question.correct;
                  final isWrong   = _answered && letter == selectedAnswer && !isCorrect;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      // Sau khi đã chọn → vô hiệu hóa tap (onTap = null)
                      onTap: _answered ? null : () => onSelect(letter),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _optionBg(letter),
                          borderRadius: AppRadius.control,
                          border: Border.all(
                            color: _optionBorder(letter),
                            width: (isCorrect || isWrong) ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Badge chữ cái / icon đúng sai
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isCorrect
                                    ? Colors.green
                                    : isWrong
                                        ? AppColors.error
                                        : AppColors.surfaceVariant,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: isCorrect
                                    ? const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 16)
                                    : isWrong
                                        ? const Icon(Icons.close_rounded,
                                            color: Colors.white, size: 16)
                                        : Text(
                                            letter,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Nội dung option (bỏ prefix "A. " nếu API trả về)
                            Expanded(
                              child: Text(
                                optionText,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  fontWeight: (isCorrect || isWrong)
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // ── Giải thích — hiện sau khi chọn ──────────────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: _answered
                      ? Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: AppRadius.control,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  question.explanation,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: 80), // khoảng đệm cho nút bên dưới
              ],
            ),
          ),
        ),

        // ── Nút Tiếp theo / Xem kết quả ─────────────────────────────────────
        // Chỉ xuất hiện sau khi đã chọn đáp án
        AnimatedSlide(
          duration: const Duration(milliseconds: 250),
          offset: _answered ? Offset.zero : const Offset(0, 1),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _answered ? 1.0 : 0.0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.control,
                    ),
                  ),
                  child: Text(
                    isLast ? 'Xem kết quả' : 'Câu tiếp theo →',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// _ResultView — Màn hình kết quả sau khi làm xong
// =============================================================================
//
// HIỂN THỊ:
//   - Vòng tròn điểm số với màu theo ngưỡng:
//       >= 80% → xanh lá (Xuất sắc)
//       >= 60% → cam    (Khá tốt)
//       <  60% → đỏ     (Cần ôn thêm)
//   - Review từng câu: ✓ xanh / ✗ đỏ kèm đáp án đúng
//   - Nút "Làm lại" → reset state, giữ bộ câu hỏi cũ
//   - Nút "Bộ câu hỏi mới" → gọi API lại
//
class _ResultView extends StatelessWidget {
  final QuizProvider provider;
  final VoidCallback onRedo;
  final VoidCallback onNewSet;

  const _ResultView({
    super.key,
    required this.provider,
    required this.onRedo,
    required this.onNewSet,
  });

  @override
  Widget build(BuildContext context) {
    final correct = provider.correctCount;
    final total   = provider.totalQuestions;

    // Tính phần trăm, tránh chia cho 0
    final pct = total > 0 ? (correct / total * 100).round() : 0;

    // Màu + message theo ngưỡng điểm
    final Color scoreColor;
    final String scoreMsg;
    final String scoreEmoji;
    if (pct >= 80) {
      scoreColor = Colors.green;
      scoreMsg   = 'Xuất sắc!';
      scoreEmoji = '🎉';
    } else if (pct >= 60) {
      scoreColor = Colors.orange;
      scoreMsg   = 'Khá tốt!';
      scoreEmoji = '💪';
    } else {
      scoreColor = AppColors.error;
      scoreMsg   = 'Cần ôn thêm';
      scoreEmoji = '📚';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        children: [
          // ── Score circle ────────────────────────────────────────────────────
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scoreColor.withValues(alpha: 0.1),
              border: Border.all(color: scoreColor, width: 3),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$correct/$total',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: scoreColor,
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 13,
                      color: scoreColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            '$scoreMsg $scoreEmoji',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bạn trả lời đúng $correct/$total câu hỏi',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),

          // Mock notice
          if (provider.result?.isMock == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: AppRadius.control,
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đây là câu hỏi mẫu. Tải tài liệu vào notebook để nhận câu hỏi từ nội dung thực.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // ── Review từng câu ──────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Chi tiết từng câu',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          ...provider.result!.questions.asMap().entries.map((entry) {
            final i = entry.key;
            final q = entry.value;
            final userAnswer   = provider.answers[i];
            final isCorrect    = userAnswer == q.correct;
            final isUnanswered = userAnswer == null;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.control,
                border: Border.all(
                  color: isUnanswered
                      ? AppColors.border
                      : isCorrect
                          ? Colors.green.shade300
                          : AppColors.error.withValues(alpha: 0.5),
                  width: 1.2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon đúng/sai
                  Icon(
                    isUnanswered
                        ? Icons.remove_circle_outline_rounded
                        : isCorrect
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                    color: isUnanswered
                        ? AppColors.textTertiary
                        : isCorrect
                            ? Colors.green
                            : AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Câu ${i + 1}: ${q.question}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        if (!isCorrect && userAnswer != null)
                          Text(
                            'Bạn chọn: $userAnswer  |  Đúng: ${q.correct}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else if (isCorrect)
                          Text(
                            'Đúng: ${q.correct}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),

          // ── Action buttons ──────────────────────────────────────────────────
          FilledButton.icon(
            onPressed: onRedo,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Làm lại'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onNewSet,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Bộ câu hỏi mới'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
            ),
          ),
        ],
      ),
    );
  }
}
