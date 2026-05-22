// =============================================================================
// FLASHCARD MODELS — Data classes cho Flash Card học tập từ tài liệu
// =============================================================================
//
// CẤU TRÚC:
//   FlashCard       — 1 thẻ (mặt trước / mặt sau)
//   FlashCardDeck   — Bộ thẻ do AI generate (response POST /flashcards/generate)
//   FlashCardResult — Kết quả sau khi user học xong 1 bộ thẻ
//   FlashCardSession— Phiên học lưu trong lịch sử
//
// =============================================================================

import 'package:flutter/material.dart';

/// 1 flashcard đơn lẻ.
class FlashCard {
  final String id;
  final String front;      // Câu hỏi / thuật ngữ (mặt trước)
  final String back;       // Đáp án / giải thích (mặt sau)
  final String? hint;      // Gợi ý tuỳ chọn
  final String? category;  // Phân loại: "Concept", "Term", "Question"...

  const FlashCard({
    required this.id,
    required this.front,
    required this.back,
    this.hint,
    this.category,
  });

  factory FlashCard.fromJson(Map<String, dynamic> json) => FlashCard(
    id:       json['id']?.toString() ?? '',
    front:    json['front']    as String? ?? '',
    back:     json['back']     as String? ?? '',
    hint:     json['hint']     as String?,
    category: json['category'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id':       id,
    'front':    front,
    'back':     back,
    'hint':     hint,
    'category': category,
  };
}

/// Response từ POST /flashcards/generate.
class FlashCardDeck {
  final String id;
  final String notebookId;
  final String notebookName;
  final String title;
  final List<FlashCard> cards;
  final bool isMock;       // true = câu hỏi mẫu (notebook rỗng / AI lỗi)
  final DateTime createdAt;

  const FlashCardDeck({
    required this.id,
    required this.notebookId,
    required this.notebookName,
    required this.title,
    required this.cards,
    this.isMock = false,
    required this.createdAt,
  });

  factory FlashCardDeck.fromJson(Map<String, dynamic> json, {required String notebookId}) {
    final rawCards = json['cards'] as List? ?? [];
    return FlashCardDeck(
      id:          json['deck_id']?.toString() ?? json['id']?.toString() ?? '',
      notebookId:  json['notebook_id']?.toString() ?? notebookId,
      notebookName: json['notebook_name'] as String? ?? 'Notebook',
      title:       json['title']       as String? ?? 'Flashcards',
      cards:       rawCards.map((c) => FlashCard.fromJson(c as Map<String, dynamic>)).toList(),
      isMock:      json['is_mock']     as bool? ?? false,
      createdAt:   DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Trạng thái học của 1 thẻ trong phiên hiện tại.
enum CardResult { mastered, review, skipped }

/// Kết quả tổng hợp sau khi hoàn thành 1 deck.
class FlashCardResult {
  final List<FlashCard> cards;
  final Map<int, CardResult?> answers;   // index → kết quả

  const FlashCardResult({required this.cards, required this.answers});

  int get masteredCount =>
      answers.values.where((r) => r == CardResult.mastered).length;
  int get reviewCount =>
      answers.values.where((r) => r == CardResult.review).length;
  int get skippedCount =>
      answers.values.where((r) => r == CardResult.skipped).length;
  int get total => cards.length;
  int get completedCount => answers.values.where((r) => r != null).length;
  int get scorePct => total > 0 ? (masteredCount / total * 100).round() : 0;
}

/// Tóm tắt 1 phiên học — dùng trong danh sách lịch sử.
class FlashCardSession {
  final String id;
  final String? notebookId;
  final String notebookName;
  final String deckTitle;
  final int totalCards;
  final int masteredCount;
  final int reviewCount;
  final int skippedCount;
  final int scorePct;
  final bool isMock;
  final DateTime createdAt;

  const FlashCardSession({
    required this.id,
    this.notebookId,
    required this.notebookName,
    required this.deckTitle,
    required this.totalCards,
    required this.masteredCount,
    required this.reviewCount,
    required this.skippedCount,
    required this.scorePct,
    required this.isMock,
    required this.createdAt,
  });

  factory FlashCardSession.fromJson(Map<String, dynamic> json) => FlashCardSession(
    id:            json['id']              as String,
    notebookId:    json['notebook_id']     as String?,
    notebookName:  json['notebook_name']   as String? ?? 'Notebook',
    deckTitle:     json['deck_title']      as String? ?? 'Flashcards',
    totalCards:    json['total_cards']     as int? ?? 0,
    masteredCount: json['mastered_count']  as int? ?? 0,
    reviewCount:   json['review_count']    as int? ?? 0,
    skippedCount:  json['skipped_count']   as int? ?? 0,
    scorePct:      json['score_pct']       as int? ?? 0,
    isMock:        json['is_mock']         as bool? ?? false,
    createdAt:     DateTime.parse(json['created_at'] as String),
  );

  Color get scoreColor {
    if (scorePct >= 80) return const Color(0xFF4CAF50);
    if (scorePct >= 50) return const Color(0xFFFFA726);
    return const Color(0xFFF44336);
  }

  String get scoreLabel {
    if (scorePct >= 80) return 'Xuất sắc';
    if (scorePct >= 50) return 'Đang tiến bộ';
    return 'Cần ôn thêm';
  }
}
