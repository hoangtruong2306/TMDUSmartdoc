// =============================================================================
// QUIZ PROVIDER — Quản lý trạng thái làm quiz + tự động lưu kết quả
// =============================================================================
//
// STATE MACHINE:
//
//   [idle] ──generateQuiz()──► [loading] ──success──► [questioning]
//                                  │                       │ selectAnswer()
//               ┌──────────────────┤                       ▼
//               │ error            │               [answered — xem giải thích]
//               ▼                  │                       │ nextQuestion()
//            [error]               │               ┌───────┴────────┐
//                                  │               │ còn câu        │ câu cuối
//                                  │               ▼                ▼
//                                  │         [questioning]    [saving] ──► [result]
//                                  │
//                              reset() / clear() → [idle]
//
// AUTO-SAVE (khi câu cuối → _showResult = true):
//   nextQuestion() gọi _saveSession() trong background
//   _isSaving flag để UI hiển thị indicator nhỏ
//   Lỗi save → không crash, chỉ log
//
// STATE LƯU ĐỂ SAVE:
//   _notebookId, _notebookName, _difficulty — set trong generateQuiz()
//   _answers: Map<int, String> — index câu → letter đã chọn
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';
import '../models/quiz_model.dart';

class QuizProvider extends ChangeNotifier {
  // ── Quiz state ─────────────────────────────────────────────────────────────
  QuizResult? _result;
  bool        _isLoading  = false;
  String?     _error;
  int         _currentIndex = 0;
  final Map<int, String> _answers = {};
  bool _showResult = false;

  // ── Session metadata (cần để save) ────────────────────────────────────────
  String? _notebookId;
  String  _notebookName = '';
  String  _difficulty   = 'medium';

  // ── Save state ─────────────────────────────────────────────────────────────
  bool    _isSaving       = false;
  String? _savedSessionId; // session_id sau khi save thành công

  // ── Getters ────────────────────────────────────────────────────────────────
  QuizResult?      get result          => _result;
  bool             get isLoading       => _isLoading;
  String?          get error           => _error;
  int              get currentIndex    => _currentIndex;
  Map<int, String> get answers         => Map.unmodifiable(_answers);
  bool             get showResult      => _showResult;
  bool             get isSaving        => _isSaving;
  String?          get savedSessionId  => _savedSessionId;
  String?          get notebookId      => _notebookId;
  String           get notebookName    => _notebookName;

  QuizQuestion? get currentQuestion {
    if (_result == null || _currentIndex >= _result!.questions.length) return null;
    return _result!.questions[_currentIndex];
  }

  bool get isLastQuestion =>
      _result != null && _currentIndex == _result!.questions.length - 1;

  int get totalQuestions => _result?.questions.length ?? 0;

  /// Tính số câu đúng — lazy từ _answers (O(n))
  int get correctCount {
    if (_result == null) return 0;
    int count = 0;
    for (final e in _answers.entries) {
      if (e.key < _result!.questions.length &&
          e.value == _result!.questions[e.key].correct) {
        count++;
      }
    }
    return count;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Gọi POST /quiz/generate, lưu metadata để dùng khi save.
  Future<void> generateQuiz({
    required String notebookId,
    required String notebookName,
    int    numQuestions = 5,
    String difficulty   = 'medium',
  }) async {
    _isLoading      = true;
    _error          = null;
    _result         = null;
    _currentIndex   = 0;
    _answers.clear();
    _showResult     = false;
    _isSaving       = false;
    _savedSessionId = null;
    // Lưu metadata cho save
    _notebookId   = notebookId;
    _notebookName = notebookName;
    _difficulty   = difficulty;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Chưa đăng nhập');

      final idToken = await user.getIdToken();
      final response = await http
          .post(
            Uri.parse('${AppConstants.backendBaseUrl}/quiz/generate'),
            headers: {
              'Authorization':  'Bearer $idToken',
              'Content-Type':   'application/json',
            },
            body: json.encode({
              'notebook_id':   notebookId,
              'num_questions': numQuestions,
              'difficulty':    difficulty,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        _result = QuizResult.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      } else {
        throw Exception('Server lỗi ${response.statusCode}');
      }
    } catch (e) {
      _error = 'Không thể tạo quiz. Vui lòng thử lại.';
      debugPrint('[QuizProvider] generateQuiz error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lưu đáp án câu hiện tại (idempotent — gọi lại không thay đổi gì).
  void selectAnswer(String letter) {
    if (_answers.containsKey(_currentIndex)) return;
    _answers[_currentIndex] = letter;
    notifyListeners();
  }

  /// Chuyển câu tiếp theo.
  /// Câu cuối → _showResult = true và tự động save session.
  void nextQuestion() {
    if (_result == null) return;
    if (_currentIndex < _result!.questions.length - 1) {
      _currentIndex++;
      notifyListeners();
    } else {
      _showResult = true;
      notifyListeners();
      _saveSession(); // background — không await để không block UI
    }
  }

  /// Làm lại từ câu 1 với cùng bộ câu hỏi.
  void reset() {
    _currentIndex   = 0;
    _answers.clear();
    _showResult     = false;
    _savedSessionId = null;
    notifyListeners();
  }

  /// Xóa toàn bộ state khi rời màn hình.
  void clear() {
    _result         = null;
    _error          = null;
    _currentIndex   = 0;
    _answers.clear();
    _showResult     = false;
    _isSaving       = false;
    _savedSessionId = null;
    notifyListeners();
  }

  // ── Private: auto-save khi hoàn thành bài ─────────────────────────────────
  //
  // THUẬT TOÁN:
  //   1. Build danh sách answers: List<{question_index, user_answer}>
  //   2. Build danh sách questions: List<{question, options, correct, explanation}>
  //   3. POST /quiz/save với toàn bộ data
  //   4. Lưu session_id trả về → dùng để navigate sang review screen
  //   5. Bất kỳ lỗi → chỉ log, không throw (tránh crash UX)
  //
  Future<void> _saveSession() async {
    if (_result == null) return;

    _isSaving = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      // Build answers list
      final answersList = List.generate(
        _result!.questions.length,
        (i) => {
          'question_index': i,
          'user_answer':    _answers[i],  // null nếu bỏ qua
        },
      );

      // Build questions list (dùng toJson() để serialize đúng)
      final questionsList = _result!.questions.map((q) => q.toJson()).toList();

      final response = await http
          .post(
            Uri.parse('${AppConstants.backendBaseUrl}/quiz/save'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type':  'application/json',
            },
            body: json.encode({
              'notebook_id':   _notebookId,
              'notebook_name': _notebookName,
              'difficulty':    _difficulty,
              'is_mock':       _result!.isMock,
              'questions':     questionsList,
              'answers':       answersList,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _savedSessionId = data['session_id'] as String?;
        debugPrint('[QuizProvider] Saved session: $_savedSessionId');
      } else {
        debugPrint('[QuizProvider] Save failed: ${response.statusCode}');
      }
    } catch (e) {
      // Lỗi save không crash app — chỉ log
      debugPrint('[QuizProvider] _saveSession error: $e');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
