// =============================================================================
// QUIZ MODEL — Data classes cho Quiz AI
// =============================================================================
//
// CẤU TRÚC DỮ LIỆU:
//
//   QuizResult  (root response từ API)
//   ├── notebook_name  : tên notebook nguồn
//   ├── is_mock        : true nếu dùng fallback mock (notebook rỗng/Gemini lỗi)
//   └── questions[]    : danh sách câu hỏi
//         ├── question    : nội dung câu hỏi
//         ├── options[]   : 4 lựa chọn ["A. ...", "B. ...", "C. ...", "D. ..."]
//         ├── correct     : đáp án đúng "A" | "B" | "C" | "D"
//         └── explanation : giải thích tại sao đáp án đúng
//
// PARSING:
//   Cả hai class dùng factory fromJson() — tránh null crash bằng ?? fallback
// =============================================================================

/// Một câu hỏi trắc nghiệm từ API.
class QuizQuestion {
  final String question;
  final List<String> options;  // Luôn có đúng 4 phần tử: A, B, C, D
  final String correct;        // "A" | "B" | "C" | "D"
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correct,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question:    json['question']    as String? ?? '',
      options:     List<String>.from(json['options'] ?? []),
      correct:     json['correct']     as String? ?? 'A',
      explanation: json['explanation'] as String? ?? '',
    );
  }
}

/// Root response từ POST /quiz/generate.
class QuizResult {
  final List<QuizQuestion> questions;
  final String notebookName;

  /// true  → Gemini lỗi hoặc notebook rỗng → quiz là ví dụ minh họa
  /// false → câu hỏi được sinh từ nội dung tài liệu thực
  final bool isMock;

  const QuizResult({
    required this.questions,
    required this.notebookName,
    required this.isMock,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      questions: (json['questions'] as List? ?? [])
          .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      notebookName: json['notebook_name'] as String? ?? 'Notebook',
      isMock:       json['is_mock']       as bool?   ?? false,
    );
  }
}
