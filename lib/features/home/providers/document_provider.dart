// =============================================================================
// DOCUMENT PROVIDER — Bộ quản lý danh sách tài liệu ở HomeScreen
// =============================================================================
// MODEL:
//   Document — đại diện một tài liệu với đầy đủ metadata:
//     id, title, pageCount, createdAt (DateTime), type, status,
//     notebookId, studyCount (in-memory session counter)
//
// GROUPING ALGORITHM:
//   groupedDocuments → LinkedHashMap<String, List<Document>>
//   Key là nhãn ngày (theo thứ tự: Hôm nay → Hôm qua → Tuần này → Tháng M/YYYY)
//   Docs được sort theo createdAt desc trước khi nhóm.
//
// STUDY COUNT:
//   In-memory Map<docId, count>. Tăng khi user mở Chat/Quiz từ HomeScreen.
//   Sau khi có backend session tracking, thay Map này = API call.
// =============================================================================

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class Document {
  final String id;
  final String title;
  final int pageCount;
  final DateTime createdAt;
  final String type;       // 'pdf' | 'txt'
  final String status;     // 'processing' | 'ready' | 'failed'
  final String? notebookId;

  Document({
    required this.id,
    required this.title,
    required this.pageCount,
    required this.createdAt,
    required this.type,
    this.status = 'ready',
    this.notebookId,
  });

  /// Nhãn thời gian ngắn gọn hiển thị bên góc phải card.
  /// - Cùng ngày hôm nay → "HH:mm"
  /// - Trong vòng 7 ngày → "dd/MM"
  /// - Cũ hơn → "dd/MM/yy"
  String get shortTime {
    final now = DateTime.now();
    final diff = now.difference(createdAt).inDays;
    if (diff == 0) return DateFormat('HH:mm').format(createdAt);
    if (diff < 7)  return DateFormat('dd/MM').format(createdAt);
    return DateFormat('dd/MM/yy').format(createdAt);
  }

  /// Label loại file
  String get typeLabel => type.toUpperCase();
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Tính nhãn nhóm ngày cho một DateTime.
/// Thứ tự ưu tiên: Hôm nay > Hôm qua > Tuần này > Tháng M/YYYY
String _dateGroupLabel(DateTime dt) {
  final now   = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final docDay = DateTime(dt.year, dt.month, dt.day);
  final diff  = today.difference(docDay).inDays;

  if (diff == 0) return 'Hôm nay';
  if (diff == 1) return 'Hôm qua';
  if (diff < 7)  return 'Tuần này';

  // Nhóm theo tháng/năm — dùng hardcode tiếng Việt vì intl vi locale chưa init
  const viMonths = [
    '', 'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4',
    'Tháng 5', 'Tháng 6', 'Tháng 7', 'Tháng 8',
    'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12',
  ];
  return '${viMonths[dt.month]} ${dt.year}';
}

// ── Provider ──────────────────────────────────────────────────────────────────

class DocumentProvider extends ChangeNotifier {
  String _searchQuery = '';
  bool _isLoading = false;
  bool _hasLoaded = false;

  // In-memory session study counter: docId → count
  // Tăng khi user mở Chat/Quiz từ HomeScreen. Reset khi khởi động lại app.
  final Map<String, int> _studyCounts = {};

  // ── Status polling ────────────────────────────────────────────────────────
  Timer? _statusPollTimer;

  bool get hasProcessingDocuments =>
      _allDocs.any((d) => d.status == 'processing');

  // Danh sách đầy đủ — bắt đầu rỗng, load từ backend theo user đã đăng nhập
  final List<Document> _allDocs = [];

  // ── Auth isolation ────────────────────────────────────────────────────────
  // Theo dõi uid hiện tại để phát hiện khi user đổi (login/logout/switch)
  String? _currentUid;

  DocumentProvider() {
    // Lắng nghe thay đổi auth state — tự động clear data khi user đổi
    FirebaseAuth.instance.authStateChanges().listen((user) {
      final newUid = user?.uid;
      if (newUid != _currentUid) {
        _currentUid = newUid;
        _clearUserData();
      }
    });
  }

  // ── Getters ──────────────────────────────────────────────────────────────────

  String get searchQuery => _searchQuery;
  bool   get isLoading   => _isLoading;

  /// Danh sách sau khi lọc theo searchQuery.
  List<Document> get documents {
    if (_isLoading) return [];
    if (_searchQuery.isEmpty) return List.unmodifiable(_allDocs);
    final q = _searchQuery.toLowerCase();
    return _allDocs.where((d) => d.title.toLowerCase().contains(q)).toList();
  }

  /// Tổng số trang của tất cả tài liệu.
  int get totalPageCount => _allDocs.fold(0, (sum, d) => sum + d.pageCount);

  /// Số tài liệu đã được học ít nhất 1 lần.
  int get studiedCount => _studyCounts.values.where((v) => v > 0).length;

  /// Study count của một document cụ thể.
  int studyCountOf(String docId) => _studyCounts[docId] ?? 0;

  /// Danh sách được nhóm theo ngày — trả về LinkedHashMap để giữ thứ tự chèn.
  ///
  /// Thuật toán:
  ///   1. Sắp xếp docs theo createdAt giảm dần (mới nhất trước)
  ///   2. Với mỗi doc, tính _dateGroupLabel(doc.createdAt)
  ///   3. Chèn vào LinkedHashMap[label] — key xuất hiện theo đúng thứ tự gặp đầu tiên
  LinkedHashMap<String, List<Document>> get groupedDocuments {
    final filtered = documents; // đã lọc searchQuery
    final sorted   = [...filtered]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // ignore: prefer_collection_literals — LinkedHashMap preserves insertion order (required for date groups)
    final map = LinkedHashMap<String, List<Document>>();
    for (final doc in sorted) {
      final label = _dateGroupLabel(doc.createdAt);
      map.putIfAbsent(label, () => []).add(doc);
    }
    return map;
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  /// Tăng số lần học của một tài liệu (gọi khi user mở Chat/Quiz từ Home).
  void incrementStudyCount(String docId) {
    _studyCounts[docId] = (_studyCounts[docId] ?? 0) + 1;
    notifyListeners();
  }

  /// Cập nhật từ khoá tìm kiếm và rebuild danh sách ngay lập tức.
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // ── Auth clear ────────────────────────────────────────────────────────────────

  /// Xóa toàn bộ data của user cũ. Gọi khi uid thay đổi (login/logout/switch).
  void _clearUserData() {
    _statusPollTimer?.cancel();
    _allDocs.clear();
    _studyCounts.clear();
    _hasLoaded   = false;
    _isLoading   = false;
    _searchQuery = '';
    notifyListeners();
  }

  // ── Delete ────────────────────────────────────────────────────────────────────

  /// Xóa nhiều tài liệu — thử batch API trước, fallback tuần tự.
  /// Optimistic: xóa khỏi danh sách local trước khi nhận xác nhận từ server.
  Future<bool> deleteDocuments(List<String> ids) async {
    if (ids.isEmpty) return true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();

      // Thử batch endpoint
      try {
        final res = await http.delete(
          Uri.parse('${AppConstants.backendBaseUrl}/documents/batch'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({'ids': ids}),
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          _allDocs.removeWhere((d) => ids.contains(d.id));
          notifyListeners();
          return true;
        }
      } catch (_) {
        // Batch không có → fallback từng cái
      }

      // Fallback: xóa tuần tự
      bool anyOk = false;
      for (final id in ids) {
        try {
          final res = await http.delete(
            Uri.parse('${AppConstants.backendBaseUrl}/documents/$id'),
            headers: {'Authorization': 'Bearer $idToken'},
          ).timeout(const Duration(seconds: 8));
          if (res.statusCode == 200) anyOk = true;
        } catch (_) {}
      }
      _allDocs.removeWhere((d) => ids.contains(d.id));
      notifyListeners();
      return anyOk;
    } catch (e) {
      debugPrint('Lỗi xóa tài liệu: $e');
      return false;
    }
  }

  // ── Load / Refresh ────────────────────────────────────────────────────────────

  Future<void> loadDocuments() async {
    if (_hasLoaded || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    if (AppConstants.backendBaseUrl.contains('your-backend')) {
      await Future.delayed(const Duration(milliseconds: 900));
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('${AppConstants.backendBaseUrl}/documents'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _allDocs.clear();

        for (final doc in data) {
          // Parse createdAt — backend trả về ISO 8601 (UTC), convert sang local
          DateTime createdAt;
          try {
            createdAt = DateTime.parse(
              doc['created_at'] ?? '',
            ).toLocal();
          } catch (_) {
            createdAt = DateTime.now();
          }

          _allDocs.add(Document(
            id:         doc['id']?.toString() ?? '',
            title:      doc['title'] ?? 'Không có tiêu đề',
            pageCount:  doc['page_count'] ?? 0,
            createdAt:  createdAt,
            type:       doc['type'] ?? 'pdf',
            status:     doc['status'] ?? 'ready',
            notebookId: doc['notebook_id']?.toString(),
          ));
        }
        _hasLoaded = true;
      } else {
        debugPrint('Tải tài liệu thất bại: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Lỗi tải tài liệu (dùng mock fallback): $e');
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
      // Tự động poll nếu có tài liệu đang xử lý
      _startPollingIfNeeded();
    }
  }

  Future<void> refresh() async {
    _statusPollTimer?.cancel();
    _hasLoaded = false;
    await loadDocuments();
  }

  // ── Status polling ────────────────────────────────────────────────────────

  void _startPollingIfNeeded() {
    if (!hasProcessingDocuments) return;
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!hasProcessingDocuments) {
        _statusPollTimer?.cancel();
        return;
      }
      _pollStatuses();
    });
  }

  /// Chỉ cập nhật field status — không reset toàn bộ danh sách.
  Future<void> _pollStatuses() async {
    if (AppConstants.backendBaseUrl.contains('your-backend')) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final idToken = await user.getIdToken();
      final res = await http.get(
        Uri.parse('${AppConstants.backendBaseUrl}/documents'),
        headers: {'Authorization': 'Bearer $idToken'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return;

      final data = json.decode(res.body) as List<dynamic>;
      bool changed = false;

      for (final raw in data) {
        final id        = raw['id']?.toString() ?? '';
        final newStatus = raw['status'] as String? ?? 'ready';
        final idx = _allDocs.indexWhere((d) => d.id == id);
        if (idx >= 0 && _allDocs[idx].status != newStatus) {
          final old = _allDocs[idx];
          _allDocs[idx] = Document(
            id: old.id, title: old.title,
            pageCount: old.pageCount, createdAt: old.createdAt,
            type: old.type, status: newStatus,
            notebookId: old.notebookId,
          );
          changed = true;
        }
      }

      if (changed) notifyListeners();
      if (!hasProcessingDocuments) _statusPollTimer?.cancel();
    } catch (_) {}
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    super.dispose();
  }
}
