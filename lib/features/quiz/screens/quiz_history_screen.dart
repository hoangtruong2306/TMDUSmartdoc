// =============================================================================
// QUIZ HISTORY SCREEN — Lịch sử các lần luyện thi
// =============================================================================
//
// LAYOUT:
//   AppBar: "Lịch sử luyện thi" + tên notebook
//   Body:
//     [loading]  → skeleton 3 cards
//     [error]    → icon + message + nút retry
//     [empty]    → illustration + text hướng dẫn
//     [loaded]   → ListView các QuizSessionCard
//
// SESSION CARD:
//   ┌─────────────────────────────────────────────────────┐
//   │  [Score Circle]  Notebook name · Difficulty         │
//   │                  Đúng X/N câu                       │
//   │                  dd/MM/yyyy HH:mm        [→ icon]   │
//   └─────────────────────────────────────────────────────┘
//
// SCORE COLOR:
//   ≥ 80% → xanh lá    "Xuất sắc"
//   ≥ 60% → cam        "Khá tốt"
//   < 60% → đỏ         "Cần ôn thêm"
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../providers/quiz_history_provider.dart';
import '../models/quiz_model.dart';


// =============================================================================
// QuizHistoryScreen
// =============================================================================

class QuizHistoryScreen extends StatefulWidget {
  final String  notebookId;
  final String  notebookName;

  const QuizHistoryScreen({
    super.key,
    required this.notebookId,
    required this.notebookName,
  });

  @override
  State<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends State<QuizHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Tải dữ liệu ngay khi vào màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizHistoryProvider>().loadHistory(
        notebookId: widget.notebookId,
      );
    });
  }

  @override
  void dispose() {
    // Không clear ở đây để tránh bị clear khi push màn hình review
    super.dispose();
  }

  void _retry() {
    context.read<QuizHistoryProvider>().loadHistory(
      notebookId: widget.notebookId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuizHistoryProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lịch sử luyện thi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.notebookName,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Nút refresh
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: provider.isLoadingList ? null : _retry,
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(QuizHistoryProvider provider) {
    if (provider.isLoadingList) {
      return _buildSkeleton();
    }

    if (provider.listError != null) {
      return _buildError(provider.listError!);
    }

    if (provider.sessions.isEmpty) {
      return _buildEmpty();
    }

    return _buildList(provider.sessions);
  }

  // ── Loading skeleton ────────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return ListView.builder(
      key: const ValueKey('skeleton'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 5,
      itemBuilder: (_, __) => const _SessionCardSkeleton(),
    );
  }

  // ── Error state ─────────────────────────────────────────────────────────────
  Widget _buildError(String message) {
    return Center(
      key: const ValueKey('error'),
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
              onPressed: _retry,
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

  // ── Empty state ─────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      key: const ValueKey('empty'),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_edu_rounded, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa có lần luyện thi nào',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Hoàn thành một bài quiz để kết quả hiển thị ở đây.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── List of sessions ────────────────────────────────────────────────────────
  Widget _buildList(List<QuizSession> sessions) {
    return ListView.builder(
      key: const ValueKey('list'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: sessions.length,
      itemBuilder: (context, i) => _SessionCard(
        session: sessions[i],
        onTap: () => context.push('/quiz/review/${sessions[i].id}'),
      ),
    );
  }
}


// =============================================================================
// _SessionCard — Card hiển thị tóm tắt 1 lần làm bài
// =============================================================================

class _SessionCard extends StatelessWidget {
  final QuizSession session;
  final VoidCallback onTap;

  const _SessionCard({required this.session, required this.onTap});

  // Màu điểm
  Color get _scoreColor => Color(session.scoreColor);

  // Label độ khó tiếng Việt
  String get _diffLabel => switch (session.difficulty) {
    'easy'   => 'Dễ',
    'medium' => 'Trung bình',
    'hard'   => 'Khó',
    _        => session.difficulty,
  };

  // Màu badge độ khó
  Color get _diffColor => switch (session.difficulty) {
    'easy'   => const Color(0xFF4CAF50),
    'medium' => const Color(0xFFFFA726),
    'hard'   => const Color(0xFFF44336),
    _        => const Color(0xFF9E9E9E),
  };

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(
      session.createdAt.toLocal(),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // ── Score circle ───────────────────────────────────────────────
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _scoreColor.withValues(alpha: 0.1),
                border: Border.all(color: _scoreColor, width: 2),
              ),
              child: Center(
                child: Text(
                  '${session.scorePct}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _scoreColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // ── Info ───────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notebook name + mock badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.notebookName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (session.isMock)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            'Mẫu',
                            style: TextStyle(fontSize: 9, color: Colors.orange.shade700, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Difficulty badge + score
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _diffColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _diffLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _diffColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Đúng ${session.correctCount}/${session.totalQuestions} câu  ·  ${session.scoreLabel}',
                        style: TextStyle(
                          fontSize: 11,
                          color: _scoreColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),

            // ── Arrow ──────────────────────────────────────────────────────
            Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}


// =============================================================================
// _SessionCardSkeleton — Placeholder khi đang tải
// =============================================================================

class _SessionCardSkeleton extends StatelessWidget {
  const _SessionCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Score circle skeleton
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 140, height: 13),
                const SizedBox(height: 6),
                _SkeletonBox(width: 200, height: 11),
                const SizedBox(height: 5),
                _SkeletonBox(width: 100, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  const _SkeletonBox({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
