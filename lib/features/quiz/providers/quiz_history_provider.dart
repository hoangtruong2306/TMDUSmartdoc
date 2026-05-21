// =============================================================================
// QUIZ HISTORY PROVIDER — Tải danh sách lịch sử + chi tiết session
// =============================================================================
//
// STATE MACHINE:
//
//   History list:
//   [idle] ──loadHistory()──► [loadingList] ──► [listLoaded]
//                                                     │
//                                               [listError]
//
//   Session detail:
//   [idle] ──loadDetail()──► [loadingDetail] ──► [detailLoaded]
//                                                      │
//                                               [detailError]
//
// CÁC TRẠNG THÁI ĐỘC LẬP:
//   - List và detail quản lý trạng thái riêng biệt
//   - clearDetail() để reset màn hình review khi thoát
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';
import '../models/quiz_model.dart';

class QuizHistoryProvider extends ChangeNotifier {
  // ── History list state ─────────────────────────────────────────────────────
  List<QuizSession> _sessions = [];
  bool    _isLoadingList = false;
  String? _listError;

  // ── Session detail state ───────────────────────────────────────────────────
  QuizSessionDetail? _sessionDetail;
  bool    _isLoadingDetail = false;
  String? _detailError;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<QuizSession>  get sessions        => List.unmodifiable(_sessions);
  bool               get isLoadingList   => _isLoadingList;
  String?            get listError       => _listError;

  QuizSessionDetail? get sessionDetail   => _sessionDetail;
  bool               get isLoadingDetail => _isLoadingDetail;
  String?            get detailError     => _detailError;

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Tải danh sách lịch sử.
  /// [notebookId] nếu null → lấy tất cả session của user.
  Future<void> loadHistory({String? notebookId}) async {
    _isLoadingList = true;
    _listError     = null;
    _sessions      = [];
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Chưa đăng nhập');

      final idToken = await user.getIdToken();
      final uri = Uri.parse(
        '${AppConstants.backendBaseUrl}/quiz/history',
      ).replace(queryParameters: {
        if (notebookId != null) 'notebook_id': notebookId,
        'limit': '30',
      });

      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $idToken'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List<dynamic>;
        _sessions = list
            .map((e) => QuizSession.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Server lỗi ${response.statusCode}');
      }
    } catch (e) {
      _listError = 'Không thể tải lịch sử. Vui lòng thử lại.';
      debugPrint('[QuizHistoryProvider] loadHistory error: $e');
    } finally {
      _isLoadingList = false;
      notifyListeners();
    }
  }

  /// Tải chi tiết 1 session (kèm toàn bộ câu hỏi + đáp án).
  Future<void> loadSessionDetail(String sessionId) async {
    _isLoadingDetail = true;
    _detailError     = null;
    _sessionDetail   = null;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Chưa đăng nhập');

      final idToken = await user.getIdToken();
      final response = await http
          .get(
            Uri.parse('${AppConstants.backendBaseUrl}/quiz/session/$sessionId'),
            headers: {'Authorization': 'Bearer $idToken'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _sessionDetail = QuizSessionDetail.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      } else if (response.statusCode == 404) {
        throw Exception('Session không tồn tại');
      } else {
        throw Exception('Server lỗi ${response.statusCode}');
      }
    } catch (e) {
      _detailError = 'Không thể tải chi tiết. Vui lòng thử lại.';
      debugPrint('[QuizHistoryProvider] loadSessionDetail error: $e');
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
  }

  /// Xóa trạng thái danh sách khi rời màn hình history.
  void clearHistory() {
    _sessions      = [];
    _listError     = null;
    _isLoadingList = false;
    notifyListeners();
  }

  /// Xóa trạng thái detail khi rời màn hình review.
  void clearDetail() {
    _sessionDetail   = null;
    _detailError     = null;
    _isLoadingDetail = false;
    notifyListeners();
  }
}
