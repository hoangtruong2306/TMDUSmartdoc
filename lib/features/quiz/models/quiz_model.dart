// =============================================================================
// QUIZ MODEL — Data classes cho Quiz AI + Lịch sử
// =============================================================================
//
// CẤU TRÚC:
//
//   ── Generate quiz ──────────────────────────────────────────────
//   QuizQuestion   : 1 câu hỏi (question, options, correct, explanation)
//   QuizResult     : response từ POST /quiz/generate
//
//   ── History / Review ───────────────────────────────────────────
//   QuizSession        : 1 lần làm bài (tóm tắt) — từ GET /quiz/history
//   QuizQuestionRecord : 1 câu hỏi kèm đáp án user — từ GET /quiz/session/:id
//   QuizSessionDetail  : QuizSession + danh sách QuizQuestionRecord
// =============================================================================

// ─────────────────────────────────────────────────────────────────────────────
// GENERATE MODELS
// ─────────────────────────────────────────────────────────────────────────────

/// Một câu hỏi trắc nghiệm từ API generate.
class QuizQuestion {
  final String question;
  final List<String> options;   // 4 phần tử: ["A. ...", "B. ...", ...]
  final String correct;         // "A" | "B" | "C" | "D"
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correct,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    question:    json['question']    as String? ?? '',
    options:     List<String>.from(json['options'] ?? []),
    correct:     json['correct']     as String? ?? 'A',
    explanation: json['explanation'] as String? ?? '',
  );

  /// Chuyển sang Map để gửi lên API /quiz/save
  Map<String, dynamic> toJson() => {
    'question':    question,
    'options':     options,
    'correct':     correct,
    'explanation': explanation,
  };
}

/// Response từ POST /quiz/generate.
class QuizResult {
  final List<QuizQuestion> questions;
  final String notebookName;
  final bool isMock; // true = câu hỏi mẫu (notebook rỗng / Gemini lỗi)

  const QuizResult({
    required this.questions,
    required this.notebookName,
    required this.isMock,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
    questions:    (json['questions'] as List? ?? [])
        .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
        .toList(),
    notebookName: json['notebook_name'] as String? ?? 'Notebook',
    isMock:       json['is_mock']       as bool?   ?? false,
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// HISTORY / REVIEW MODELS
// ─────────────────────────────────────────────────────────────────────────────

/// Tóm tắt 1 lần làm bài — dùng trong danh sách lịch sử.
/// Maps với bảng quiz_sessions (không có chi tiết câu hỏi).
class QuizSession {
  final String  id;
  final String? notebookId;
  final String  notebookName;
  final String  difficulty;     // "easy" | "medium" | "hard"
  final int     totalQuestions;
  final int     correctCount;
  final int     scorePct;       // 0-100
  final bool    isMock;
  final DateTime createdAt;

  const QuizSession({
    required this.id,
    this.notebookId,
    required this.notebookName,
    required this.difficulty,
    required this.totalQuestions,
    required this.correctCount,
    required this.scorePct,
    required this.isMock,
    required this.createdAt,
  });

  factory QuizSession.fromJson(Map<String, dynamic> json) => QuizSession(
    id:             json['id']             as String,
    notebookId:     json['notebook_id']    as String?,
    notebookName:   json['notebook_name']  as String? ?? 'Notebook',
    difficulty:     json['difficulty']     as String? ?? 'medium',
    totalQuestions: json['total_questions'] as int? ?? 0,
    correctCount:   json['correct_count']  as int? ?? 0,
    scorePct:       json['score_pct']      as int? ?? 0,
    isMock:         json['is_mock']        as bool? ?? false,
    createdAt:      DateTime.parse(json['created_at'] as String),
  );

  /// Màu điểm theo ngưỡng
  static const _green  = 0xFF4CAF50;
  static const _orange = 0xFFFFA726;
  static const _red    = 0xFFF44336;

  int get scoreColor => scorePct >= 80 ? _green : scorePct >= 60 ? _orange : _red;

  String get scoreLabel =>
    scorePct >= 80 ? 'Xuất sắc' : scorePct >= 60 ? 'Khá tốt' : 'Cần ôn thêm';
}


/// Một câu hỏi kèm đáp án người dùng đã chọn — trong màn hình review.
/// Maps với bảng quiz_questions.
class QuizQuestionRecord {
  final String       id;
  final int          questionIndex;
  final String       question;
  final List<String> options;
  final String       correct;
  final String       explanation;
  final String?      userAnswer;  // null = không chọn
  final bool         isCorrect;

  const QuizQuestionRecord({
    required this.id,
    required this.questionIndex,
    required this.question,
    required this.options,
    required this.correct,
    required this.explanation,
    this.userAnswer,
    required this.isCorrect,
  });

  factory QuizQuestionRecord.fromJson(Map<String, dynamic> json) =>
      QuizQuestionRecord(
        id:            json['id']             as String,
        questionIndex: json['question_index'] as int? ?? 0,
        question:      json['question']       as String? ?? '',
        options:       List<String>.from(json['options'] ?? []),
        correct:       json['correct']        as String? ?? 'A',
        explanation:   json['explanation']    as String? ?? '',
        userAnswer:    json['user_answer']    as String?,
        isCorrect:     json['is_correct']     as bool? ?? false,
      );
}


/// Chi tiết đầy đủ 1 session — dùng trong màn hình review.
/// = QuizSession + list QuizQuestionRecord từ GET /quiz/session/:id
class QuizSessionDetail extends QuizSession {
  final List<QuizQuestionRecord> questionRecords;

  const QuizSessionDetail({
    required super.id,
    super.notebookId,
    required super.notebookName,
    required super.difficulty,
    required super.totalQuestions,
    required super.correctCount,
    required super.scorePct,
    required super.isMock,
    required super.createdAt,
    required this.questionRecords,
  });

  factory QuizSessionDetail.fromJson(Map<String, dynamic> json) {
    final base = QuizSession.fromJson(json);
    return QuizSessionDetail(
      id:              base.id,
      notebookId:      base.notebookId,
      notebookName:    base.notebookName,
      difficulty:      base.difficulty,
      totalQuestions:  base.totalQuestions,
      correctCount:    base.correctCount,
      scorePct:        base.scorePct,
      isMock:          base.isMock,
      createdAt:       base.createdAt,
      questionRecords: (json['questions'] as List? ?? [])
          .map((q) => QuizQuestionRecord.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Chỉ những câu sai (để hiển thị trong review tab "Câu sai")
  List<QuizQuestionRecord> get wrongQuestions =>
      questionRecords.where((q) => !q.isCorrect).toList();
}
