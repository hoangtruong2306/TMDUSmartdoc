// =============================================================================
// DOCUMENT PROVIDER — Bộ quản lý danh sách tài liệu ở HomeScreen
// =============================================================================
// LUỒNG THUẬT TOÁN:
//
//   HomeScreen.initState() → loadDocuments()
//         ↓
//   [Kiểm tra: URL là placeholder?] → Dùng mock data ngay
//         ↓ (URL hợp lệ)
//   [Lấy Firebase ID Token]
//         ↓
//   [Gọi GET /documents với Bearer token]
//         ↓
//   Backend trả về: [{id, title, page_count, created_at, type}, ...]
//         ↓
//   [Map JSON → MockDocument objects]
//         ↓
//   [Lọc theo searchQuery (tìm kiếm real-time)]
//
// FALLBACK: Nếu backend lỗi → giữ nguyên mock data (không crash app)
//
// TÌM KIẾM: Lọc theo title.contains(query) — so sánh không phân biệt hoa/thường
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants.dart';

/// Model đại diện cho một tài liệu trong danh sách.
class MockDocument {
  final String id;
  final String title;
  final int pageCount;
  final String date;
  final String type; // "pdf" hoặc "ppt"

  MockDocument({
    required this.id,
    required this.title,
    required this.pageCount,
    required this.date,
    required this.type,
  });
}

class DocumentProvider extends ChangeNotifier {
  // Từ khoá tìm kiếm hiện tại (cập nhật real-time khi người dùng gõ)
  String _searchQuery = '';

  // _isLoading = true → đang gọi API (hiển thị skeleton loading)
  bool _isLoading = false;

  // _hasLoaded = true → đã tải xong, không gọi API lại khi rebuild
  bool _hasLoaded = false;

  // Danh sách đầy đủ — khởi tạo sẵn mock data làm fallback
  final List<MockDocument> _allDocs = [
    MockDocument(
      id: '1',
      title: 'Chương 1: Giới thiệu về AI',
      pageCount: 24,
      date: '2 ngày trước',
      type: 'pdf',
    ),
    MockDocument(
      id: '2',
      title: 'Cơ bản về Học máy (Machine Learning)',
      pageCount: 45,
      date: '3 ngày trước',
      type: 'pdf',
    ),
    MockDocument(
      id: '3',
      title: 'Kiến trúc Mạng Nơ-ron',
      pageCount: 12,
      date: '1 tuần trước',
      type: 'ppt',
    ),
    MockDocument(
      id: '4',
      title: 'Tổng quan về Thị giác Máy tính',
      pageCount: 30,
      date: '2 tuần trước',
      type: 'pdf',
    ),
    MockDocument(
      id: '5',
      title: 'Xử lý Ngôn ngữ Tự nhiên',
      pageCount: 56,
      date: '3 tuần trước',
      type: 'pdf',
    ),
    MockDocument(
      id: '6',
      title: 'Học tăng cường',
      pageCount: 18,
      date: '1 tháng trước',
      type: 'pdf',
    ),
  ];

  /// Getter danh sách tài liệu — tự động lọc theo searchQuery.
  ///
  /// Thuật toán lọc:
  ///   - Nếu đang tải → trả về [] (UI hiển thị skeleton)
  ///   - Nếu searchQuery rỗng → trả về toàn bộ danh sách
  ///   - Ngược lại → lọc: title.toLowerCase().contains(query.toLowerCase())
  ///     Dùng toLowerCase() để so sánh không phân biệt chữ hoa/thường
  List<MockDocument> get documents {
    if (_isLoading) return [];
    if (_searchQuery.isEmpty) return _allDocs;
    return _allDocs
        .where(
          (doc) => doc.title.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  /// Tải danh sách tài liệu từ backend FastAPI.
  ///
  /// Guard condition: chỉ tải 1 lần (_hasLoaded) và không tải song song (_isLoading).
  /// Lý do: HomeScreen có thể rebuild nhiều lần, không muốn gọi API lặp lại.
  Future<void> loadDocuments() async {
    if (_hasLoaded || _isLoading) return; // Guard: tránh gọi trùng

    _isLoading = true;
    notifyListeners();

    // Kiểm tra URL placeholder → dùng mock data ngay không cần HTTP call
    if (AppConstants.backendBaseUrl.contains('your-backend-railway-url')) {
      await Future.delayed(const Duration(milliseconds: 900)); // Delay giả lập network
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
      return;
    }

    try {
      // Lấy Firebase user hiện tại
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Lấy JWT ID Token để xác thực với backend
      // Backend sẽ decode token → lấy uid → truy vấn tài liệu của user đó
      final idToken = await user.getIdToken();

      // Gọi GET /documents với timeout 5 giây (danh sách không cần lâu)
      final response = await http.get(
        Uri.parse('${AppConstants.backendBaseUrl}/documents'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // Parse JSON array → List<MockDocument>
        // Backend trả về: [{"id": "uuid", "title": "...", "page_count": 24, ...}]
        final List<dynamic> data = json.decode(response.body);
        _allDocs.clear(); // Xóa mock data, thay bằng dữ liệu thật
        for (var doc in data) {
          _allDocs.add(
            MockDocument(
              id: doc['id']?.toString() ?? '',
              title: doc['title'] ?? 'Không có tiêu đề',
              pageCount: doc['page_count'] ?? 0,
              date: doc['created_at'] ?? 'Vừa xong',
              type: doc['type'] ?? 'pdf',
            ),
          );
        }
        _hasLoaded = true;
      } else {
        debugPrint('Failed to load documents: ${response.statusCode}');
        // Không clear _allDocs → mock data vẫn hiển thị
      }
    } catch (e) {
      // Lỗi mạng/timeout → giữ mock data làm fallback thay vì crash
      debugPrint('Error loading documents from backend (using mock fallback): $e');
      _hasLoaded = true; // Đánh dấu đã "tải" để không retry liên tục
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Buộc tải lại danh sách từ backend — bypass guard _hasLoaded.
  /// Gọi khi: pull-to-refresh, sau khi upload file mới.
  Future<void> refresh() async {
    _hasLoaded = false;
    await loadDocuments();
  }

  /// Cập nhật từ khoá tìm kiếm và rebuild danh sách ngay lập tức.
  /// Được gọi mỗi khi người dùng gõ một ký tự vào ô search.
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners(); // Trigger rebuild → getter documents tự lọc lại
  }
}
