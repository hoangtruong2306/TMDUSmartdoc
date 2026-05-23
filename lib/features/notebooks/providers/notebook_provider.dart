import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants.dart';

class Notebook {
  final String id;
  final String name;
  final String color;
  final String icon;
  final String summary;
  final List<String> suggestions;
  final DateTime updatedAt;

  Notebook({
    required this.id,
    required this.name,
    required this.color,
    this.icon = 'school',
    this.summary = '',
    this.suggestions = const [],
    required this.updatedAt,
  });

  Color get flutterColor {
    try {
      final hex = color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF6750A4);
    }
  }
}

class NotebookProvider extends ChangeNotifier {
  final List<Notebook> _notebooks = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  // ── Auth isolation ────────────────────────────────────────────────────────
  String? _currentUid;
  // ignore: unused_field  (subscription kept alive in memory)
  late final StreamSubscription<User?> _authSub;

  NotebookProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      final newUid = user?.uid;
      if (newUid != _currentUid) {
        _currentUid = newUid;
        clear();
      }
    });
  }

  List<Notebook> get notebooks => _notebooks;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  Future<void> loadNotebooks() async {
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
        Uri.parse('${AppConstants.backendBaseUrl}/notebooks'),
        headers: {'Authorization': 'Bearer $idToken'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _notebooks.clear();
        for (var nb in data) {
          final rawSuggestions = nb['suggestions'];
          final suggestions = rawSuggestions is List
              ? rawSuggestions.map((s) => s.toString()).toList()
              : <String>[];
          _notebooks.add(Notebook(
            id: nb['id'] ?? '',
            name: nb['name'] ?? 'Notebook',
            color: nb['color'] ?? '#6750A4',
            icon: nb['icon'] ?? 'school',
            summary: nb['summary'] ?? '',
            suggestions: suggestions,
            updatedAt: DateTime.tryParse(nb['updated_at'] ?? '') ?? DateTime.now(),
          ));
        }
      }
      _hasLoaded = true;
    } catch (e) {
      debugPrint('Lỗi tải notebooks: $e');
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Notebook?> createNotebook(String name, String color, String icon) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse('${AppConstants.backendBaseUrl}/notebooks'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'name': name, 'color': color, 'icon': icon}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final nb = Notebook(
          id: data['id'] ?? '',
          name: data['name'] ?? name,
          color: data['color'] ?? color,
          icon: data['icon'] ?? icon,
          updatedAt: DateTime.now(),
        );
        _notebooks.insert(0, nb);
        notifyListeners();
        return nb;
      }
    } catch (e) {
      debugPrint('Lỗi tạo notebook: $e');
    }
    return null;
  }

  Future<bool> deleteNotebook(String id) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();

      final response = await http.delete(
        Uri.parse('${AppConstants.backendBaseUrl}/notebooks/$id'),
        headers: {'Authorization': 'Bearer $idToken'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _notebooks.removeWhere((nb) => nb.id == id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Lỗi xóa notebook: $e');
    }
    return false;
  }

  Future<bool> deleteNotebooks(List<String> ids) async {
    if (ids.isEmpty) return true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();

      // Thử gọi batch API trước
      try {
        final response = await http.delete(
          Uri.parse('${AppConstants.backendBaseUrl}/notebooks/batch'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({'ids': ids}),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          _notebooks.removeWhere((nb) => ids.contains(nb.id));
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
            Uri.parse('${AppConstants.backendBaseUrl}/notebooks/$id'),
            headers: {'Authorization': 'Bearer $idToken'},
          ).timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) anySuccess = true;
        } catch (_) {
          // Ignore single delete error
        }
      }
      _notebooks.removeWhere((nb) => ids.contains(nb.id));
      notifyListeners();
      return anySuccess;
    } catch (e) {
      debugPrint('Lỗi xóa nhiều notebook: $e');
      return false;
    }
  }

  Future<void> refresh() async {
    _hasLoaded = false;
    await loadNotebooks();
  }

  void clear() {
    _notebooks.clear();
    _hasLoaded = false;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
