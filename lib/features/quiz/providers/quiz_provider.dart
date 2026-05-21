// =============================================================================
// QUIZ PROVIDER — Quản lý trạng thái toàn bộ luồng làm quiz
// =============================================================================
//
// STATE MACHINE (trạng thái chuyển đổi):
//
//   [idle] ──generateQuiz()──► [loading]
//                                  │
//               ┌──────────────────┤
//               │ success          │ error
//               ▼                  ▼
//         [questioning]        [error]
//               │
//         selectAnswer(letter)
//               │  (lock answer — không cho chọn lại)
//               ▼
//         [answered — hiện explanation]
//               │
//         nextQuestion()
//               │
//      ┌────────┴────────┐
//      │ còn câu         │ câu cuối
//      ▼                 ▼
//  [questioning]     [showResult]
//                        │
//              reset() / clear()
//                        ▼
//                     [idle]
//
// KEY DESIGN DECISIONS:
//   - _answers: Map<int, String> — index câu → letter đã chọn
//     Dùng Map thay List để O(1) lookup và tránh out-of-bound
//   - selectAnswer() idempotent: gọi lại sau khi đã chọn → no-op
//   - correctCount tính lazy từ _answers (không lưu sẵn)
//   - clear() dùng khi rời màn hình để giải phóng bộ nhớ
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';
import '../models/quiz_model.dart';

class QuizProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  QuizResult? _result;
  bool _isLoading = false;
  String? _error;

  // Chỉ số câu hỏi hiện tại (0-indexed)
  int _currentIndex = 0;

  // Map: câu index → letter đã chọn ("A"|"B"|"C"|"D")
  // Dùng Map để O(1) kiểm tra "đã trả lời chưa" và tránh array out-of-bound
  final Map<int, String> _answers = {};

  // Cờ: đang hiển thị màn hình kết quả hay không
  bool _showResult = false;

  // ── Getters ────────────────────────────────────────────────────────────────
  QuizResult? get result      => _result;
  bool        get isLoading   => _isLoading;
  String?     get error       => _error;
  int         get currentIndex => _currentIndex;
  Map<int, String> get answers => Map.unmodifiable(_answers);
  bool        get showResult  => _showResult;

  /// Câu hỏi đang hiển thị (null nếu chưa có quiz hoặc index vượt bounds)
  QuizQuestion? get currentQuestion {
    if (_result == null) return null;
    if (_currentIndex >= _result!.questions.length) return null;
    return _result!.questions[_currentIndex];
  }

  /// true nếu câu hiện tại là câu cuối cùng
  bool get isLastQuestion =>
      _result != null &&
      _currentIndex == _result!.questions.length - 1;

  int get totalQuestions => _result?.questions.length ?? 0;

  /// Tính số câu đúng từ _answers.
  ///
  /// THUẬT TOÁN:
  ///   Duyệt từng entry trong _answers, so sánh với correct của câu tương ứng.
  ///   Độ phức tạp: O(n) với n = số câu đã trả lời.
  int get correctCount {
    if (_result == null) return 0;
    int count = 0;
    for (final entry in _answers.entries) {
      final idx = entry.key;
      final chosen = entry.value;
      if (idx < _result!.questions.length &&
          chosen == _result!.questions[idx].correct) {
        count++;
      }
    }
    return count;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Gọi API /quiz/generate và cập nhật state.
  ///
  /// THUẬT TOÁN:
  ///   1. Reset toàn bộ state → notify (UI hiện loading spinner)
  ///   2. Lấy Firebase ID token (refresh nếu hết hạn — getIdToken() tự lo)
  ///   3. POST request với timeout 30s (Gemini thường mất 5-15s)
  ///   4. Parse response → QuizResult
  ///   5. Bất kỳ exception → set _error message thân thiện
  ///   6. finally: tắt loading → notify
  Future<void> generateQuiz({
    required String notebookId,
    int numQuestions = 5,
    String difficulty = 'medium',
  }) async {
    // Reset state đầy đủ trước khi bắt đầu
    _isLoading = true;
    _error = null;
    _result = null;
    _currentIndex = 0;
    _answers.clear();
    _showResult = false;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Chưa đăng nhập');

      // getIdToken() tự động refresh token nếu sắp hết hạn
      final idToken = await user.getIdToken();

      final response = await http
          .post(
            Uri.parse('${AppConstants.backendBaseUrl}/quiz/generate'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'notebook_id':    notebookId,
              'num_questions':  numQuestions,
              'difficulty':     difficulty,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        _result = QuizResult.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      } else {
        throw Exception('Server trả về lỗi ${response.statusCode}');
      }
    } catch (e) {
      _error = 'Không thể tạo quiz. Vui lòng thử lại.';
      debugPrint('[QuizProvider] generateQuiz error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lưu đáp án của câu hiện tại.
  ///
  /// Idempotent: nếu câu đã có đáp án → bỏ qua (tránh chọn lại sau khi xem kết quả)
  void selectAnswer(String letter) {
    if (_answers.containsKey(_currentIndex)) return; // lock: không chọn lại
    _answers[_currentIndex] = letter;
    notifyListeners();
  }

  /// Chuyển sang câu tiếp theo hoặc hiện màn hình kết quả nếu là câu cuối.
  ///
  /// Chỉ cho phép gọi khi câu hiện tại đã được trả lời
  /// (UI kiểm soát bằng cách ẩn nút nếu chưa chọn).
  void nextQuestion() {
    if (_result == null) return;
    if (_currentIndex < _result!.questions.length - 1) {
      _currentIndex++;
    } else {
      // Câu cuối → chuyển sang màn hình kết quả
      _showResult = true;
    }
    notifyListeners();
  }

  /// Làm lại từ đầu với cùng bộ câu hỏi (không gọi API).
  void reset() {
    _currentIndex = 0;
    _answers.clear();
    _showResult = false;
    notifyListeners();
  }

  /// Xóa toàn bộ state khi rời màn hình quiz.
  /// Gọi trong close button và dispose để tránh state cũ hiện ra lần sau.
  void clear() {
    _result      = null;
    _error       = null;
    _currentIndex = 0;
    _answers.clear();
    _showResult  = false;
    notifyListeners();
  }
}
