// =============================================================================
// FLASHCARD PROVIDER — State management cho chức năng Flash Card
// =============================================================================
//
// STATE MACHINE:
//   [idle] ──generateDeck()──► [loading] ──success──► [studying]
//                                  │                       │ markCard()
//               ┌──────────────────┤                       ▼
//               │ error            │                 [studying]
//               ▼                  │                       │ done
//            [error]               │                  [saving] ──► [result]
//                                  │
//                              reset() / clear() → [idle]
//
// AUTO-SAVE: khi hoàn thành deck → tự động POST /flashcards/save
// =============================================================================

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';
import '../models/flashcard_model.dart';

class FlashCardProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  FlashCardDeck? _deck;
  bool        _isLoading  = false;
  String?     _error;
  int         _currentIndex = 0;
  final Map<int, CardResult?> _answers = {};
  bool _showResult = false;
  bool _showAnswer = false;   // true = mặt sau (back) đang hiển thị

  // ── Session metadata ───────────────────────────────────────────────────────
  String? _notebookId;
  String  _notebookName = '';
  int     _numCards     = 10;

  // ── Save state ─────────────────────────────────────────────────────────────
  bool    _isSaving       = false;
  String? _savedSessionId;

  // ── Getters ────────────────────────────────────────────────────────────────
  FlashCardDeck?   get deck           => _deck;
  bool             get isLoading      => _isLoading;
  String?          get error          => _error;
  int              get currentIndex   => _currentIndex;
  Map<int, CardResult?> get answers   => Map.unmodifiable(_answers);
  bool             get showResult     => _showResult;
  bool             get showAnswer     => _showAnswer;
  bool             get isSaving       => _isSaving;
  String?          get savedSessionId => _savedSessionId;
  int              get numCards       => _numCards;

  FlashCard? get currentCard {
    if (_deck == null || _currentIndex >= _deck!.cards.length) return null;
    return _deck!.cards[_currentIndex];
  }

  bool get isLastCard =>
      _deck != null && _currentIndex == _deck!.cards.length - 1;

  int get totalCards => _deck?.cards.length ?? 0;

  bool get isCompleted => _deck != null &&
      _answers.length == _deck!.cards.length &&
      _answers.values.every((v) => v != null);

  /// Số thẻ đã hoàn thành trong phiên hiện tại.
  int get completedCount =>
      _answers.values.where((r) => r != null).length;

  /// Tính % mastered hiện tại.
  int get currentScorePct {
    if (_deck == null || _deck!.cards.isEmpty) return 0;
    final m = _answers.values.where((r) => r == CardResult.mastered).length;
    return (m / _deck!.cards.length * 100).round();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Gọi POST /flashcards/generate để tạo bộ thẻ từ tài liệu.
  Future<void> generateDeck({
    required String notebookId,
    required String notebookName,
    int    numCards = 10,
  }) async {
    _isLoading    = true;
    _error        = null;
    _deck         = null;
    _currentIndex = 0;
    _answers.clear();
    _showResult   = false;
    _showAnswer   = false;
    _isSaving     = false;
    _savedSessionId = null;
    _notebookId   = notebookId;
    _notebookName = notebookName;
    _numCards     = numCards;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Chưa đăng nhập');

      // ── MOCK DATA MODE ──
      // Nếu backend chưa sẵn, dùng mock data để test UI.
      if (AppConstants.backendBaseUrl.contains('your-backend') ||
          AppConstants.backendBaseUrl.contains('onrender.com') == false) {
        await Future.delayed(const Duration(seconds: 2));
        _deck = _generateMockDeck(notebookId, notebookName, numCards);
      } else {
        final idToken = await user.getIdToken();
        final response = await http
            .post(
              Uri.parse('${AppConstants.backendBaseUrl}/flashcards/generate'),
              headers: {
                'Authorization': 'Bearer $idToken',
                'Content-Type':  'application/json',
              },
              body: json.encode({
                'notebook_id': notebookId,
                'num_cards':   numCards,
              }),
            )
            .timeout(const Duration(seconds: 40));

        if (response.statusCode == 200) {
          _deck = FlashCardDeck.fromJson(
            json.decode(response.body) as Map<String, dynamic>,
            notebookId: notebookId,
          );
        } else if (response.statusCode == 404) {
          // Endpoint chưa có → fallback mock
          _deck = _generateMockDeck(notebookId, notebookName, numCards);
        } else {
          throw Exception('Server lỗi ${response.statusCode}');
        }
      }
    } catch (e) {
      _error = 'Không thể tạo flashcards. Vui lòng thử lại.';
      debugPrint('[FlashCardProvider] generateDeck error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Đánh dấu kết quả cho thẻ hiện tại và chuyển sang thẻ tiếp theo.
  void markCard(CardResult result) {
    if (_deck == null) return;
    if (_currentIndex >= _deck!.cards.length) return;
    _answers[_currentIndex] = result;
    _showAnswer = false; // reset về mặt trước

    if (isLastCard) {
      _showResult = true;
      notifyListeners();
      _saveSession();
    } else {
      _currentIndex++;
      notifyListeners();
    }
  }

  /// Bỏ qua thẻ hiện tại (không đánh dấu kết quả, chỉ next).
  void skipCard() {
    markCard(CardResult.skipped);
  }

  /// Lật thẻ hiện tại (front ↔ back).
  void flipCard() {
    _showAnswer = !_showAnswer;
    notifyListeners();
  }

  /// Quay lại thẻ trước (nếu đang ở index > 0).
  void previousCard() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _showAnswer = false;
      notifyListeners();
    }
  }

  /// Reset phiên học hiện tại (làm lại từ thẻ 1).
  void resetSession() {
    _currentIndex = 0;
    _answers.clear();
    _showResult = false;
    _showAnswer = false;
    _savedSessionId = null;
    notifyListeners();
  }

  /// Xóa toàn bộ state khi rời màn hình.
  void clear() {
    _deck         = null;
    _error        = null;
    _currentIndex = 0;
    _answers.clear();
    _showResult   = false;
    _showAnswer   = false;
    _isSaving     = false;
    _savedSessionId = null;
    notifyListeners();
  }

  // ── Private: auto-save ─────────────────────────────────────────────────────

  Future<void> _saveSession() async {
    if (_deck == null) return;

    _isSaving = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      final resultsList = List.generate(
        _deck!.cards.length,
        (i) => {
          'card_id': _deck!.cards[i].id,
          'result':  (_answers[i] ?? CardResult.skipped).name,
        },
      );

      final response = await http
          .post(
            Uri.parse('${AppConstants.backendBaseUrl}/flashcards/save'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type':  'application/json',
            },
            body: json.encode({
              'deck_id':        _deck!.id,
              'notebook_id':    _notebookId,
              'notebook_name':  _notebookName,
              'deck_title':     _deck!.title,
              'card_results':   resultsList,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _savedSessionId = data['session_id'] as String?;
        debugPrint('[FlashCardProvider] Saved session: $_savedSessionId');
      } else {
        debugPrint('[FlashCardProvider] Save failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FlashCardProvider] _saveSession error: $e');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ── Mock data generator ────────────────────────────────────────────────────

  FlashCardDeck _generateMockDeck(String notebookId, String notebookName, int numCards) {
    final mockTerms = [
      ('Đạo hàm', 'Đạo hàm của hàm số f(x) tại điểm x là giới hạn của tỉ số sai phân khi khoảng cách tiến đến 0.'),
      ('Tích phân', 'Tích phân là phép toán ngược của đạo hàm, dùng để tính diện tích, thể tích và nhiều đại lượng khác.'),
      ('Ma trận', 'Ma trận là một mảng hình chữ nhật các số, được dùng rộng rãi trong đại số tuyến tính.'),
      ('Vectơ', 'Vectơ là đại lượng có cả độ lớn và hướng, biểu diễn bằng mũi tên trong không gian.'),
      ('Giới hạn', 'Giới hạn của một hàm số tại một điểm là giá trị mà hàm số tiến gần khi biến độc lập tiến gần điểm đó.'),
      ('Chuỗi số', 'Chuỗi số là tổng vô hạn của một dãy số; chuỗi hội tụ nếu tổng tiến đến một giá trị hữu hạn.'),
      ('Hàm số liên tục', 'Hàm số liên tục tại x₀ nếu lim(x→x₀) f(x) = f(x₀), tức đồ thị không có điểm đứt gãy.'),
      ('Định lý Lagrange', 'Nếu f(x) liên tục trên [a,b] và khả vi trên (a,b), thì tồn tại c thuộc (a,b) sao cho f\'(c) = [f(b)-f(a)]/(b-a).'),
      ('Phương trình vi phân', 'Phương trình liên hệ giữa một hàm số và các đạo hàm của nó, thường dùng mô tả quá trình vật lý.'),
      ('Không gian vector', 'Tập các vector cùng kích thước với hai phép toán cộng vector và nhân vô hướng thỏa mãn 8 tiên đề.'),
      ('Định thức', 'Một hàm số gán cho mỗi ma trận vuông một số thực; det(A)=0 khi và chỉ khi A suy biến.'),
      ('Giá trị riêng', 'Số λ là giá trị riêng của ma trận A nếu tồn tại vector v ≠ 0 sao cho Av = λv.'),
      ('Hội tụ tuyệt đối', 'Chuỗi Σaₙ hội tụ tuyệt đối nếu chuỗi Σ|aₙ| hội tụ; khi đó chuỗi gốc cũng hội tụ.'),
      ('Quy nạp toán học', 'Phương pháp chứng minh: chứng minh cơ sở P(1) đúng, rồi giả sử P(k) đúng chứng minh P(k+1).'),
      ('Tập hợp số thực', 'ℝ = (−∞,+∞) là một trường đầy đủ, được dùng để định nghĩa giới hạn và liên tục.'),
    ];

    final cards = <FlashCard>[];
    final used = <int>{};
    final random = Random();
    while (cards.length < numCards && used.length < mockTerms.length) {
      final i = random.nextInt(mockTerms.length);
      if (used.add(i)) {
        final (front, back) = mockTerms[i];
        cards.add(FlashCard(
          id: '${cards.length + 1}',
          front: front,
          back: back,
          hint: 'Hãy nhớ các tính chất cơ bản.',
          category: cards.length % 3 == 0 ? 'Concept' : cards.length % 3 == 1 ? 'Theorem' : 'Term',
        ));
      }
    }

    return FlashCardDeck(
      id: 'mock-deck-${DateTime.now().millisecondsSinceEpoch}',
      notebookId: notebookId,
      notebookName: notebookName,
      title: 'Flashcards: $notebookName',
      cards: cards,
      isMock: true,
      createdAt: DateTime.now(),
    );
  }
}
