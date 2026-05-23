import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants.dart';

/// Tài liệu thuộc về một notebook.
class NotebookDocument {
  final String id;
  final String title;
  final String type;
  final int pageCount;
  final DateTime createdAt;
  final String? notebookId; // null nếu chưa được gán vào notebook nào
  final String status;      // 'processing' | 'ready' | 'failed'

  NotebookDocument({
    required this.id,
    required this.title,
    required this.type,
    this.pageCount = 0,
    required this.createdAt,
    this.notebookId,
    this.status = 'ready',
  });

  bool get isProcessing => status == 'processing';
  bool get isFailed     => status == 'failed';
  bool get isReady      => status == 'ready';

  NotebookDocument copyWithStatus(String newStatus) => NotebookDocument(
    id: id, title: title, type: type,
    pageCount: pageCount, createdAt: createdAt,
    notebookId: notebookId, status: newStatus,
  );
}

/// Bộ quản lý danh sách tài liệu trong notebook.
class NotebookDocumentsProvider extends ChangeNotifier {
  final String notebookId;
  NotebookDocumentsProvider({required this.notebookId});

  final List<NotebookDocument> _documents = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  // ── Status polling ────────────────────────────────────────────────────────
  Timer? _statusPollTimer;

  List<NotebookDocument> get documents => _documents;
  bool get isLoading => _isLoading;

  /// true khi có ít nhất 1 tài liệu chưa xử lý xong.
  bool get hasProcessingDocuments => _documents.any((d) => d.isProcessing);

  Future<void> loadDocuments() async {
    if (_hasLoaded || _isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || AppConstants.backendBaseUrl.contains('your-backend')) {
        _isLoading = false;
        _hasLoaded = true;
        notifyListeners();
        return;
      }

      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('${AppConstants.backendBaseUrl}/documents?notebook_id=$notebookId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _documents.clear();
        for (var doc in data) {
          _documents.add(NotebookDocument(
            id:         doc['id']?.toString() ?? '',
            title:      doc['title'] ?? 'Không có tiêu đề',
            type:       doc['type'] ?? 'pdf',
            pageCount:  doc['page_count'] ?? 0,
            createdAt:  DateTime.tryParse(doc['created_at'] ?? '') ?? DateTime.now(),
            notebookId: doc['notebook_id']?.toString(),
            status:     doc['status'] as String? ?? 'ready',
          ));
        }
      }
      _hasLoaded = true;
    } catch (e) {
      debugPrint('Lỗi tải documents notebook: $e');
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
      // Tự động poll nếu có tài liệu đang xử lý
      _startPollingIfNeeded();
    }
  }

  // ── Status polling ────────────────────────────────────────────────────────

  /// Bắt đầu polling mỗi 4 giây khi có tài liệu đang xử lý.
  /// Tự dừng khi tất cả đã sẵn sàng.
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

  /// Fetch nhẹ — chỉ cập nhật field `status`, không reset loading state.
  Future<void> _pollStatuses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final idToken = await user.getIdToken();
      final res = await http.get(
        Uri.parse('${AppConstants.backendBaseUrl}/documents?notebook_id=$notebookId'),
        headers: {'Authorization': 'Bearer $idToken'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return;

      final data = json.decode(res.body) as List<dynamic>;
      bool changed = false;

      for (final raw in data) {
        final id        = raw['id']?.toString() ?? '';
        final newStatus = raw['status'] as String? ?? 'ready';
        final idx = _documents.indexWhere((d) => d.id == id);
        if (idx >= 0 && _documents[idx].status != newStatus) {
          _documents[idx] = _documents[idx].copyWithStatus(newStatus);
          changed = true;
        }
      }

      if (changed) notifyListeners();
      if (!hasProcessingDocuments) _statusPollTimer?.cancel();
    } catch (_) {
      // Ignore poll errors — will retry on next tick
    }
  }

  Future<bool> deleteDocument(String id) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();

      final response = await http.delete(
        Uri.parse('${AppConstants.backendBaseUrl}/documents/$id'),
        headers: {'Authorization': 'Bearer $idToken'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _documents.removeWhere((d) => d.id == id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Lỗi xóa tài liệu: $e');
    }
    return false;
  }

  Future<bool> deleteDocuments(List<String> ids) async {
    if (ids.isEmpty) return true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();

      // Thử gọi batch API trước
      try {
        final response = await http.delete(
          Uri.parse('${AppConstants.backendBaseUrl}/documents/batch'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({'ids': ids}),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          _documents.removeWhere((d) => ids.contains(d.id));
          notifyListeners();
          return true;
        }
      } catch (_) {
        // Batch API không có → fallback xóa tuần tự
      }

      // Fallback: xóa từng cái một
      bool anySuccess = false;
      for (final id in ids) {
        try {
          final response = await http.delete(
            Uri.parse('${AppConstants.backendBaseUrl}/documents/$id'),
            headers: {'Authorization': 'Bearer $idToken'},
          ).timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) anySuccess = true;
        } catch (_) {
          // Ignore single delete error
        }
      }
      _documents.removeWhere((d) => ids.contains(d.id));
      notifyListeners();
      return anySuccess;
    } catch (e) {
      debugPrint('Lỗi xóa nhiều tài liệu: $e');
      return false;
    }
  }

  /// Lấy toàn bộ tài liệu của user (không lọc theo notebook).
  /// Dùng cho Document Picker Sheet khi user muốn gán tài liệu vào notebook.
  static Future<List<NotebookDocument>> fetchAllUserDocuments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
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
        return data.map((doc) => NotebookDocument(
          id: doc['id']?.toString() ?? '',
          title: doc['title'] ?? 'Không có tiêu đề',
          type: doc['type'] ?? 'pdf',
          pageCount: doc['page_count'] ?? 0,
          createdAt: DateTime.tryParse(doc['created_at'] ?? '') ?? DateTime.now(),
          notebookId: doc['notebook_id']?.toString(),
        )).where((d) => d.id.isNotEmpty).toList();
      }
    } catch (e) {
      debugPrint('Lỗi tải tất cả documents: $e');
    }
    return [];
  }

  /// Gỡ tài liệu khỏi notebook (notebook_id → NULL), giữ file trong hệ thống.
  /// Trả về số lượng gỡ thành công.
  Future<int> unassignDocuments(List<String> docIds) async {
    if (docIds.isEmpty) return 0;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;
      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse('${AppConstants.backendBaseUrl}/documents/unassign'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'doc_ids': docIds}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final count = result['unassigned_count'] as int? ?? 0;
        if (count > 0) {
          // Xóa khỏi danh sách hiển thị ngay lập tức (optimistic update)
          _documents.removeWhere((d) => docIds.contains(d.id));
          _hasLoaded = true; // đánh dấu đã load để không gọi lại
          notifyListeners();
        }
        return count;
      }
    } catch (e) {
      debugPrint('Lỗi gỡ tài liệu khỏi notebook: $e');
    }
    return 0;
  }

  /// Gán danh sách documents vào notebook này.
  /// Trả về số lượng tài liệu được gán thành công.
  Future<int> assignDocumentsToNotebook(List<String> docIds) async {
    if (docIds.isEmpty) return 0;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;
      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse('${AppConstants.backendBaseUrl}/documents/assign'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'doc_ids': docIds,
          'notebook_id': notebookId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final assignedCount = result['assigned_count'] as int? ?? 0;
        if (assignedCount > 0) {
          // Reload để cập nhật danh sách
          await refresh();
        }
        return assignedCount;
      }
    } catch (e) {
      debugPrint('Lỗi gán tài liệu vào notebook: $e');
    }
    return 0;
  }

  Future<void> refresh() async {
    _statusPollTimer?.cancel();
    _hasLoaded = false;
    await loadDocuments();
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    super.dispose();
  }
}
