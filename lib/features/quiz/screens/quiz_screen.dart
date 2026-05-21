// =============================================================================
// QUIZ SCREEN — Màn hình làm bài trắc nghiệm từ nội dung notebook
// =============================================================================
//
// LUỒNG MÀN HÌNH (State Machine):
//
//   [setup]  ──Bắt đầu──► [loading] ──success──► [questioning]
//     ▲                        │                       │
//     │                        │ error                 │ nextQuestion() (hết câu)
//     │                        ▼                       ▼
//     └──────────────────── [error]               [result]
//                                                    │
//                                        reset()     │   onNewSet()
//                                           ▼        │      ▼
//                                       [questioning] │  [loading]
//
// VIEWS:
//   _SetupView       → chọn số câu + độ khó trước khi bắt đầu
//   _LoadingView     → spinner khi gọi API
//   _ErrorView       → thông báo lỗi + retry
//   _QuestionView    → 1 câu hỏi + 4 options + giải thích
//   _ResultView      → điểm số + review từng câu
//
// ANIMATION:
//   AnimatedSwitcher (fade+scale 250ms) giữa các view
//   AnimatedContainer (200ms) highlight đáp án đúng/sai
//   AnimatedSlide + AnimatedOpacity cho nút Next (trượt lên từ dưới)
//   TweenAnimationBuilder cho progress bar (mượt khi chuyển câu)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../providers/quiz_provider.dart';
import '../models/quiz_model.dart';

// ── Cấu hình độ khó ──────────────────────────────────────────────────────────

/// Metadata hiển thị cho từng mức độ khó
class _DifficultyInfo {
  final String key;        // gửi lên API: "easy" | "medium" | "hard"
  final String label;      // hiển thị trong UI
  final String desc;       // mô tả ngắn
  final IconData icon;
  final Color color;

  const _DifficultyInfo({
    required this.key,
    required this.label,
    required this.desc,
    required this.icon,
    required this.color,
  });
}

const _difficulties = [
  _DifficultyInfo(
    key:   'easy',
    label: 'Dễ',
    desc:  'Nhớ & hiểu — Phù hợp ôn tập cơ bản',
    icon:  Icons.sentiment_satisfied_rounded,
    color: Color(0xFF4CAF50),
  ),
  _DifficultyInfo(
    key:   'medium',
    label: 'Trung bình',
    desc:  'Vận dụng & phân tích — Luyện đề cương',
    icon:  Icons.sentiment_neutral_rounded,
    color: Color(0xFFFFA726),
  ),
  _DifficultyInfo(
    key:   'hard',
    label: 'Khó',
    desc:  'Đánh giá & tổng hợp — Thi thử áp lực',
    icon:  Icons.sentiment_very_dissatisfied_rounded,
    color: Color(0xFFF44336),
  ),
];

// Các lựa chọn số câu hỏi
const _questionCounts = [5, 10, 15, 20];


// =============================================================================
// QuizScreen — Widget chính
// =============================================================================

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
  // Trạng thái setup (trước khi bắt đầu)
  bool _setupDone = false;

  // Cấu hình người dùng chọn trong _SetupView
  int    _selectedNum        = 5;
  String _selectedDifficulty = 'medium';

  /// Bắt đầu tạo quiz với cấu hình đã chọn
  void _startQuiz() {
    setState(() => _setupDone = true);
    context.read<QuizProvider>().generateQuiz(
      notebookId:   widget.notebookId,
      notebookName: widget.notebookName,
      numQuestions: _selectedNum,
      difficulty:   _selectedDifficulty,
    );
  }

  /// Tạo lại bộ câu hỏi mới (quay lại setup)
  void _resetToSetup() {
    context.read<QuizProvider>().clear();
    setState(() => _setupDone = false);
  }

  /// Thử lại khi gặp lỗi
  void _retry() {
    context.read<QuizProvider>().generateQuiz(
      notebookId:   widget.notebookId,
      notebookName: widget.notebookName,
      numQuestions: _selectedNum,
      difficulty:   _selectedDifficulty,
    );
  }

  /// Đóng màn hình — clear state để tránh dùng lại lần sau
  void _close() {
    context.read<QuizProvider>().clear();
    context.pop();
  }

  // Tên hiển thị của độ khó đang chọn
  String get _difficultyLabel =>
      _difficulties.firstWhere((d) => d.key == _selectedDifficulty).label;

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
          tooltip: 'Đóng',
          onPressed: _close,
        ),
        title: Text(
          widget.notebookName,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Bộ đếm câu — chỉ hiển thị khi đang làm bài
        actions: [
          if (_setupDone && !provider.isLoading &&
              provider.result != null && !provider.showResult)
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

      // AnimatedSwitcher chuyển mượt giữa các view
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve:  Curves.easeOut,
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

  // ── Switch giữa các view theo state ────────────────────────────────────────
  Widget _buildBody(QuizProvider provider) {
    // Chưa bắt đầu → màn hình setup
    if (!_setupDone) {
      return _SetupView(
        key: const ValueKey('setup'),
        notebookName:         widget.notebookName,
        selectedNum:          _selectedNum,
        selectedDifficulty:   _selectedDifficulty,
        onNumChanged:         (v) => setState(() => _selectedNum = v),
        onDifficultyChanged:  (v) => setState(() => _selectedDifficulty = v),
        onStart:              _startQuiz,
      );
    }

    if (provider.isLoading) {
      return _LoadingView(
        key: const ValueKey('loading'),
        numQuestions: _selectedNum,
        difficulty:   _difficultyLabel,
      );
    }

    if (provider.error != null) {
      return _ErrorView(
        key: const ValueKey('error'),
        message: provider.error!,
        onRetry:  _retry,
        onBack:   _resetToSetup,
      );
    }

    if (provider.showResult) {
      return _ResultView(
        key: const ValueKey('result'),
        provider:     provider,
        difficulty:   _difficultyLabel,
        notebookId:   widget.notebookId,
        notebookName: widget.notebookName,
        onRedo:       provider.reset,
        onNewSet:     _resetToSetup,
      );
    }

    final question = provider.currentQuestion;
    if (question == null) return const SizedBox.shrink(key: ValueKey('empty'));

    // Key thay đổi theo currentIndex → AnimatedSwitcher phát hiện thay đổi
    return _QuestionView(
      key: ValueKey('q_${provider.currentIndex}'),
      question:       question,
      index:          provider.currentIndex,
      total:          provider.totalQuestions,
      selectedAnswer: provider.answers[provider.currentIndex],
      onSelect:       provider.selectAnswer,
      onNext: provider.answers.containsKey(provider.currentIndex)
          ? provider.nextQuestion
          : null,
      isLast: provider.isLastQuestion,
      isMock: provider.result?.isMock ?? false,
    );
  }
}


// =============================================================================
// _SetupView — Chọn cấu hình quiz trước khi bắt đầu
// =============================================================================
//
// UI LAYOUT:
//   Header icon + tiêu đề
//   ── Số câu hỏi ──
//   Row 4 chips: 5 / 10 / 15 / 20
//   ── Độ khó ──
//   Column 3 cards: Dễ / Trung bình / Khó (mỗi card có icon + mô tả)
//   ── Nút Bắt đầu ──
//
class _SetupView extends StatelessWidget {
  final String notebookName;
  final int    selectedNum;
  final String selectedDifficulty;
  final ValueChanged<int>    onNumChanged;
  final ValueChanged<String> onDifficultyChanged;
  final VoidCallback onStart;

  const _SetupView({
    super.key,
    required this.notebookName,
    required this.selectedNum,
    required this.selectedDifficulty,
    required this.onNumChanged,
    required this.onDifficultyChanged,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.quiz_rounded,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cài đặt bài luyện thi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI sẽ tạo câu hỏi từ tài liệu trong notebook này',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Số câu hỏi ─────────────────────────────────────────────────────
          _SectionLabel(
            icon:  Icons.format_list_numbered_rounded,
            title: 'Số câu hỏi',
          ),
          const SizedBox(height: 10),
          Row(
            children: _questionCounts.map((n) {
              final isSelected = n == selectedNum;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => onNumChanged(n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceElevated,
                        borderRadius: AppRadius.control,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$n',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Độ khó ─────────────────────────────────────────────────────────
          _SectionLabel(
            icon:  Icons.bar_chart_rounded,
            title: 'Mức độ khó',
          ),
          const SizedBox(height: 10),
          ..._difficulties.map((d) {
            final isSelected = d.key == selectedDifficulty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onDifficultyChanged(d.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? d.color.withValues(alpha: 0.08)
                        : AppColors.surfaceElevated,
                    borderRadius: AppRadius.control,
                    border: Border.all(
                      color: isSelected ? d.color : AppColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Icon level
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: d.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(d.icon, size: 20, color: d.color),
                      ),
                      const SizedBox(width: 12),
                      // Label + description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? d.color : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              d.desc,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Radio indicator
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? d.color : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? d.color : AppColors.border,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 12)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 28),

          // ── Nút Bắt đầu ────────────────────────────────────────────────────
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text(
              'Bắt đầu luyện thi',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
            ),
          ),
        ],
      ),
    );
  }
}

// Tiêu đề section nhỏ dùng lại trong _SetupView
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionLabel({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}


// =============================================================================
// _LoadingView — Spinner + thông tin đang tạo
// =============================================================================
class _LoadingView extends StatelessWidget {
  final int    numQuestions;
  final String difficulty;
  const _LoadingView({
    super.key,
    required this.numQuestions,
    required this.difficulty,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'AI đang phân tích tài liệu...',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tạo $numQuestions câu · Mức $difficulty',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              'Thường mất 5-15 giây',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}


// =============================================================================
// _ErrorView — Lỗi + nút thử lại / quay lại setup
// =============================================================================
class _ErrorView extends StatelessWidget {
  final String   message;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  const _ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

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
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onBack,
              child: const Text('← Quay lại cài đặt'),
            ),
          ],
        ),
      ),
    );
  }
}


// =============================================================================
// _QuestionView — Hiển thị câu hỏi + 4 lựa chọn
// =============================================================================
//
// THUẬT TOÁN COLOR CODING (sau khi chọn đáp án):
//   letter == correct                    → xanh lá (#E8F5E9 bg + green border)
//   letter == selectedAnswer && ≠ correct → đỏ (#FFEBEE bg + error border)
//   letter còn lại                       → không đổi màu
//
// LOCK MECHANISM:
//   GestureDetector.onTap = null sau khi đã chọn → không thể đổi đáp án
//
// PROGRESS BAR:
//   TweenAnimationBuilder: animate từ (index/total) → (index+1)/total
//   Duration 400ms, curve easeOut → thanh trượt mượt giữa các câu
//
class _QuestionView extends StatelessWidget {
  final QuizQuestion question;
  final int     index;
  final int     total;
  final String? selectedAnswer;
  final ValueChanged<String> onSelect;
  final VoidCallback?        onNext;
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

  Color _optionBg(String letter) {
    if (!_answered) return AppColors.surfaceElevated;
    if (letter == question.correct) return const Color(0xFFE8F5E9);
    if (letter == selectedAnswer)   return const Color(0xFFFFEBEE);
    return AppColors.surfaceElevated;
  }

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            color: Colors.orange.shade50,
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Câu hỏi mẫu — Tải tài liệu vào notebook để nhận câu hỏi từ nội dung thực',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),

        // ── Câu hỏi + options ─────────────────────────────────────────────────
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
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
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
                const SizedBox(height: 18),

                // Options A → D
                ...question.options.asMap().entries.map((entry) {
                  final letter     = letters[entry.key];
                  final optionText = entry.value;
                  final isCorrect  = _answered && letter == question.correct;
                  final isWrong    = _answered && letter == selectedAnswer && !isCorrect;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
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
                            // Badge chữ cái / ✓ / ✗
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
                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                    : isWrong
                                        ? const Icon(Icons.close_rounded, color: Colors.white, size: 16)
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

                // ── Giải thích (xuất hiện sau khi chọn) ──────────────────────
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
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // ── Nút Tiếp theo (trượt lên từ dưới khi đã chọn) ────────────────────
        AnimatedSlide(
          duration: const Duration(milliseconds: 280),
          offset: _answered ? Offset.zero : const Offset(0, 1.2),
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
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
                  ),
                  child: Text(
                    isLast ? 'Xem kết quả  →' : 'Câu tiếp theo  →',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
// _ResultView — Kết quả sau khi hoàn thành bài
// =============================================================================
//
// SCORE COLOR LOGIC:
//   pct >= 80 → xanh lá  "Xuất sắc 🎉"
//   pct >= 60 → cam       "Khá tốt 💪"
//   pct <  60 → đỏ        "Cần ôn thêm 📚"
//
// REVIEW TABLE:
//   Mỗi câu: icon ✓/✗ + nội dung + đáp án đúng nếu sai
//
class _ResultView extends StatelessWidget {
  final QuizProvider provider;
  final String       difficulty;
  final String       notebookId;
  final String       notebookName;
  final VoidCallback onRedo;
  final VoidCallback onNewSet;

  const _ResultView({
    super.key,
    required this.provider,
    required this.difficulty,
    required this.notebookId,
    required this.notebookName,
    required this.onRedo,
    required this.onNewSet,
  });

  @override
  Widget build(BuildContext context) {
    final correct = provider.correctCount;
    final total   = provider.totalQuestions;
    final pct     = total > 0 ? (correct / total * 100).round() : 0;

    final Color  scoreColor;
    final String scoreMsg;
    final String scoreEmoji;
    if (pct >= 80) {
      scoreColor = Colors.green;  scoreMsg = 'Xuất sắc';  scoreEmoji = '🎉';
    } else if (pct >= 60) {
      scoreColor = Colors.orange; scoreMsg = 'Khá tốt';   scoreEmoji = '💪';
    } else {
      scoreColor = AppColors.error; scoreMsg = 'Cần ôn thêm'; scoreEmoji = '📚';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        children: [
          // ── Score circle ───────────────────────────────────────────────────
          Container(
            width: 128, height: 128,
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
                      fontWeight: FontWeight.w600,
                      color: scoreColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$scoreMsg $scoreEmoji',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Đúng $correct/$total câu · Mức $difficulty',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                  Icon(Icons.info_outline_rounded, size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đây là câu hỏi mẫu. Tải tài liệu vào notebook để nhận câu hỏi từ nội dung thực.',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade800, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // ── Chi tiết từng câu ──────────────────────────────────────────────
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
            final i          = entry.key;
            final q          = entry.value;
            final userAnswer = provider.answers[i];
            final isCorrect  = userAnswer == q.correct;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.control,
                border: Border.all(
                  color: userAnswer == null
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
                  Icon(
                    isCorrect
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: isCorrect ? Colors.green : AppColors.error,
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
                            'Bạn chọn: $userAnswer  ·  Đáp án đúng: ${q.correct}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else if (isCorrect)
                          Text(
                            'Đáp án đúng: ${q.correct}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
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

          // ── Saving indicator ───────────────────────────────────────────────
          if (provider.isSaving) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Đang lưu kết quả...',
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ] else if (provider.savedSessionId != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 12, color: Colors.green.shade600),
                const SizedBox(width: 6),
                Text(
                  'Đã lưu vào lịch sử',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade600),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // ── Action buttons ─────────────────────────────────────────────────
          FilledButton.icon(
            onPressed: onRedo,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Làm lại bộ này'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onNewSet,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Tạo bộ câu hỏi mới'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
            ),
          ),
          const SizedBox(height: 10),
          // Nút xem lịch sử — chỉ hiển thị khi lưu thành công
          if (provider.savedSessionId != null)
            OutlinedButton.icon(
              onPressed: () => context.push(
                '/quiz/review/${provider.savedSessionId}',
              ),
              icon: const Icon(Icons.history_edu_rounded),
              label: const Text('Xem chi tiết bài làm'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
              ),
            ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => context.push(
              '/quiz/history/$notebookId?name=${Uri.encodeComponent(notebookName)}',
            ),
            icon: const Icon(Icons.list_alt_rounded, size: 16),
            label: const Text('Xem lịch sử luyện thi'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
