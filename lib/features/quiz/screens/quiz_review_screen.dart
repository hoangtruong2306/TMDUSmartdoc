// =============================================================================
// QUIZ REVIEW SCREEN — Xem lại chi tiết bài làm + giải thích câu sai
// =============================================================================
//
// LAYOUT:
//   AppBar: "Xem lại bài làm"
//   Body:
//     [loading]  → spinner
//     [error]    → error message + retry
//     [loaded]   → 2 tabs + danh sách câu hỏi
//
// HEADER (trên TabBar):
//   ┌───────────────────────────────────────────────────┐
//   │  Score: X/N câu  ·  Y%                            │
//   │  Notebook · Mức khó · Ngày làm                    │
//   └───────────────────────────────────────────────────┘
//
// TABS:
//   [Tất cả N câu]  [Câu sai M câu]
//
// QUESTION CARD:
//   ┌─────────────────────────────────────────────────────┐
//   │  Câu K: [text câu hỏi]                             │
//   │                                                     │
//   │  [A] option A  ← màu xanh nếu đúng                 │
//   │  [B] option B  ← màu đỏ nếu user chọn sai          │
//   │  [C] option C                                       │
//   │  [D] option D                                       │
//   │                                                     │
//   │  💡 Giải thích: ...                                 │
//   └─────────────────────────────────────────────────────┘
//
// COLOR CODING:
//   Đáp án đúng   → nền xanh nhạt (#E8F5E9) + viền xanh
//   User chọn sai → nền đỏ nhạt (#FFEBEE) + viền đỏ
//   Không chọn    → màu mặc định
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../providers/quiz_history_provider.dart';
import '../models/quiz_model.dart';


// =============================================================================
// QuizReviewScreen
// =============================================================================

class QuizReviewScreen extends StatefulWidget {
  final String sessionId;

  const QuizReviewScreen({super.key, required this.sessionId});

  @override
  State<QuizReviewScreen> createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends State<QuizReviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizHistoryProvider>().loadSessionDetail(widget.sessionId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Dùng Provider.of với listen:false để tránh lỗi context-after-deactivate
    Provider.of<QuizHistoryProvider>(context, listen: false).clearDetail();
    super.dispose();
  }

  void _retry() {
    context.read<QuizHistoryProvider>().loadSessionDetail(widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuizHistoryProvider>();

    // ── Loaded: _DetailView dùng NestedScrollView + SliverAppBar bên trong.
    //    Outer Scaffold không có AppBar riêng để tránh double header.
    final detail = provider.sessionDetail;
    if (!provider.isLoadingDetail &&
        provider.detailError == null && detail != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _DetailView(
          detail:        detail,
          tabController: _tabController,
          onBack:        () => context.pop(),
        ),
      );
    }

    // ── Loading / Error: dùng Scaffold đơn giản với AppBar tĩnh
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Xem lại bài làm',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: provider.detailError != null
          ? _ErrorBody(
              message: provider.detailError!,
              onRetry: _retry,
            )
          : const _LoadingBody(),
    );
  }
}


// =============================================================================
// _DetailView — Màn hình chính sau khi load xong
// =============================================================================

class _DetailView extends StatelessWidget {
  final QuizSessionDetail detail;
  final TabController     tabController;
  final VoidCallback      onBack;

  const _DetailView({
    required this.detail,
    required this.tabController,
    required this.onBack,
  });

  String get _diffLabel => switch (detail.difficulty) {
    'easy'   => 'Dễ',
    'medium' => 'Trung bình',
    'hard'   => 'Khó',
    _        => detail.difficulty,
  };

  Color get _scoreColor => Color(detail.scoreColor);

  @override
  Widget build(BuildContext context) {
    final wrongCount  = detail.wrongQuestions.length;
    final dateStr     = DateFormat('dd/MM/yyyy HH:mm').format(
      detail.createdAt.toLocal(),
    );

    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        // ── SliverAppBar ────────────────────────────────────────────────────
        SliverAppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: onBack,
          ),
          title: const Text(
            'Xem lại bài làm',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          // ── Score summary expandable ────────────────────────────────────
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(130),
            child: Column(
              children: [
                // Summary card
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _scoreColor.withValues(alpha: 0.07),
                    borderRadius: AppRadius.card,
                    border: Border.all(
                      color: _scoreColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Score circle
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _scoreColor.withValues(alpha: 0.12),
                          border: Border.all(color: _scoreColor, width: 2),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${detail.correctCount}/${detail.totalQuestions}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _scoreColor,
                                ),
                              ),
                              Text(
                                '${detail.scorePct}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _scoreColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.notebookName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                _Badge(label: _diffLabel, color: _scoreColor),
                                const SizedBox(width: 6),
                                _Badge(
                                  label: detail.scoreLabel,
                                  color: _scoreColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── TabBar ──────────────────────────────────────────────────
                TabBar(
                  controller: tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: AppColors.border,
                  tabs: [
                    Tab(text: 'Tất cả  ${detail.totalQuestions} câu'),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (wrongCount > 0)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$wrongCount',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          Text('Câu sai  $wrongCount câu'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],

      // ── Tab views ─────────────────────────────────────────────────────────
      body: TabBarView(
        controller: tabController,
        children: [
          // Tab 1: tất cả câu
          _QuestionList(questions: detail.questionRecords),
          // Tab 2: câu sai
          detail.wrongQuestions.isEmpty
              ? _NoWrongQuestions()
              : _QuestionList(questions: detail.wrongQuestions),
        ],
      ),
    );
  }
}

// ── Helper badge ──────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}


// =============================================================================
// _QuestionList — ListView các câu hỏi
// =============================================================================

class _QuestionList extends StatelessWidget {
  final List<QuizQuestionRecord> questions;
  const _QuestionList({required this.questions});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: questions.length,
      itemBuilder: (_, i) => _QuestionCard(
        record: questions[i],
        displayIndex: i + 1,
      ),
    );
  }
}


// =============================================================================
// _QuestionCard — 1 câu hỏi trong màn hình review
// =============================================================================
//
// COLOR CODING:
//   letter == correct                    → xanh lá
//   letter == userAnswer && ≠ correct    → đỏ
//   (không chọn) letter == correct       → xanh lá highlight đáp án đúng
//   còn lại                              → không đổi
//
class _QuestionCard extends StatelessWidget {
  final QuizQuestionRecord record;
  final int                displayIndex;

  const _QuestionCard({required this.record, required this.displayIndex});

  Color _optionBg(String letter) {
    if (letter == record.correct) return const Color(0xFFE8F5E9);
    if (letter == record.userAnswer && letter != record.correct) {
      return const Color(0xFFFFEBEE);
    }
    return AppColors.surfaceElevated;
  }

  Color _optionBorder(String letter) {
    if (letter == record.correct) return Colors.green.shade400;
    if (letter == record.userAnswer && letter != record.correct) {
      return AppColors.error;
    }
    return AppColors.border;
  }

  bool get _isCorrect => record.isCorrect;

  @override
  Widget build(BuildContext context) {
    const letters = ['A', 'B', 'C', 'D'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: _isCorrect
              ? Colors.green.shade200
              : record.userAnswer == null
                  ? AppColors.border
                  : AppColors.error.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: số câu + trạng thái ────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _isCorrect
                  ? Colors.green.shade50
                  : record.userAnswer == null
                      ? AppColors.surfaceVariant
                      : AppColors.error.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft:  Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isCorrect
                      ? Icons.check_circle_rounded
                      : record.userAnswer == null
                          ? Icons.remove_circle_outline_rounded
                          : Icons.cancel_rounded,
                  size: 16,
                  color: _isCorrect
                      ? Colors.green
                      : record.userAnswer == null
                          ? AppColors.textTertiary
                          : AppColors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Câu $displayIndex',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _isCorrect
                          ? Colors.green.shade700
                          : record.userAnswer == null
                              ? AppColors.textTertiary
                              : AppColors.error,
                    ),
                  ),
                ),
                // Badge: user chọn gì
                if (record.userAnswer != null)
                  _AnswerBadge(
                    label: 'Bạn chọn: ${record.userAnswer}',
                    isCorrect: _isCorrect,
                  ),
                if (record.userAnswer == null)
                  _AnswerBadge(label: 'Bỏ qua', isCorrect: false, isSkipped: true),
              ],
            ),
          ),

          // ── Nội dung câu hỏi ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              record.question,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.55,
              ),
            ),
          ),

          // ── Options ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Column(
              children: record.options.asMap().entries.map((entry) {
                final letter     = letters[entry.key];
                final optionText = entry.value;
                final isCorrect  = letter == record.correct;
                final isWrong    = letter == record.userAnswer && !isCorrect;

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color:  _optionBg(letter),
                    borderRadius: AppRadius.control,
                    border: Border.all(
                      color: _optionBorder(letter),
                      width: (isCorrect || isWrong) ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Badge chữ cái / ✓ / ✗
                      Container(
                        width: 26, height: 26,
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
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                              : isWrong
                                  ? const Icon(Icons.close_rounded, color: Colors.white, size: 14)
                                  : Text(
                                      letter,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          optionText,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: (isCorrect || isWrong)
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isCorrect
                                ? Colors.green.shade800
                                : isWrong
                                    ? AppColors.error
                                    : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Giải thích ────────────────────────────────────────────────
          if (record.explanation.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: AppRadius.control,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.explanation,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.55,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Answer badge ──────────────────────────────────────────────────────────────
class _AnswerBadge extends StatelessWidget {
  final String label;
  final bool   isCorrect;
  final bool   isSkipped;
  const _AnswerBadge({required this.label, required this.isCorrect, this.isSkipped = false});

  @override
  Widget build(BuildContext context) {
    final color = isSkipped
        ? AppColors.textTertiary
        : isCorrect
            ? Colors.green
            : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}


// =============================================================================
// _NoWrongQuestions — Khi không có câu sai
// =============================================================================

class _NoWrongQuestions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'Không có câu sai!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đã trả lời đúng tất cả các câu hỏi.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


// =============================================================================
// _LoadingBody / _ErrorBody — Nội dung body (không phải Scaffold) cho các state
// =============================================================================

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Đang tải...',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 52, color: AppColors.error),
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
              style: FilledButton.styleFrom(
                minimumSize: const Size(160, 48),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
