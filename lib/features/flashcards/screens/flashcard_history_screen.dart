// =============================================================================
// FLASHCARD HISTORY SCREEN — Lịch sử các phiên học flashcards
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';
import '../../flashcards/models/flashcard_model.dart';

class FlashCardHistoryScreen extends StatefulWidget {
  final String notebookId;
  final String notebookName;

  const FlashCardHistoryScreen({
    super.key,
    required this.notebookId,
    required this.notebookName,
  });

  @override
  State<FlashCardHistoryScreen> createState() => _FlashCardHistoryScreenState();
}

class _FlashCardHistoryScreenState extends State<FlashCardHistoryScreen> {
  List<FlashCardSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      // Nếu backend chưa có endpoint → dùng mock data
      if (AppConstants.backendBaseUrl.contains('your-backend') ||
          AppConstants.backendBaseUrl.contains('onrender.com') == false) {
        await Future.delayed(const Duration(seconds: 1));
        _sessions = _mockHistory();
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final idToken = await user.getIdToken();
          final res = await http.get(
            Uri.parse('${AppConstants.backendBaseUrl}/flashcards/history/${widget.notebookId}'),
            headers: {'Authorization': 'Bearer $idToken'},
          ).timeout(const Duration(seconds: 8));
          if (res.statusCode == 200) {
            final data = json.decode(res.body) as List;
            _sessions = data.map((e) => FlashCardSession.fromJson(e as Map<String, dynamic>)).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('[FlashCardHistory] load error: $e');
      _sessions = _mockHistory();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<FlashCardSession> _mockHistory() => [
    FlashCardSession(
      id: '1',
      notebookId: widget.notebookId,
      notebookName: widget.notebookName,
      deckTitle: 'Flashcards: ${widget.notebookName}',
      totalCards: 20,
      masteredCount: 14,
      reviewCount: 4,
      skippedCount: 2,
      scorePct: 70,
      isMock: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    FlashCardSession(
      id: '2',
      notebookId: widget.notebookId,
      notebookName: widget.notebookName,
      deckTitle: 'Flashcards: ${widget.notebookName}',
      totalCards: 10,
      masteredCount: 6,
      reviewCount: 3,
      skippedCount: 1,
      scorePct: 60,
      isMock: true,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Lịch sử Flashcards',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _sessions.isEmpty
                ? _EmptyHistory(notebookName: widget.notebookName)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sessions.length,
                    itemBuilder: (context, i) {
                      final s = _sessions[i];
                      return _SessionCard(session: s);
                    },
                  ),
      ),
    );
  }
}

// ── Session Card ─────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final FlashCardSession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.control,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: session.scoreColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${session.scorePct}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: session.scoreColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.deckTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.totalCards} thẻ · ${session.masteredCount} mastered · ${_formatDate(session.createdAt)}',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            ],
          ),
          if (session.isMock) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Dữ liệu mẫu',
                style: TextStyle(fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty History ────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  final String notebookName;
  const _EmptyHistory({required this.notebookName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          const Text(
            'Chưa có lịch sử',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Hoàn thành bộ flashcards đầu tiên\nđể xem kết quả tại đây.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime d) {
  return '${d.day}/${d.month}';
}
