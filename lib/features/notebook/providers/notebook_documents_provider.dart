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

  NotebookDocument({
    required this.id,
    required this.title,
    required this.type,
    this.pageCount = 0,
    required this.createdAt,
  });
}

/// Bộ quản lý danh sách tài liệu trong notebook.
class NotebookDocumentsProvider extends ChangeNotifier {
  final String notebookId;
  NotebookDocumentsProvider({required this.notebookId});

  final List<NotebookDocument> _documents = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  List<NotebookDocument> get documents => _documents;
  bool get isLoading => _isLoading;

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
            id: doc['id']?.toString() ?? '',
            title: doc['title'] ?? 'Không có tiêu đề',
            type: doc['type'] ?? 'pdf',
            pageCount: doc['page_count'] ?? 0,
            createdAt: DateTime.tryParse(doc['created_at'] ?? '') ?? DateTime.now(),
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

  Future<void> refresh() async {
    _hasLoaded = false;
    await loadDocuments();
  }
}
