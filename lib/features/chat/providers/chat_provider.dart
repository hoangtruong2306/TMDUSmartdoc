import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants.dart';
import '../../../shared/widgets/widgets.dart';

class ChatMessage {
  final String text;
  final bool isAi;
  final List<CitationData> citations;

  ChatMessage({
    required this.text,
    required this.isAi,
    this.citations = const [],
  });
}

/// Metadata của một cuộc hội thoại — 1 tài liệu = 1 cuộc hội thoại.
/// docId = ID tài liệu từ backend, dùng làm Firestore document ID.
class Conversation {
  final String docId;
  final String title;
  final String lastMessage;
  final DateTime updatedAt;

  Conversation({
    required this.docId,
    required this.title,
    this.lastMessage = '',
    required this.updatedAt,
  });
}

// =============================================================================
// THIẾT KẾ KIẾN TRÚC
//
// Firestore path:
//   users/{uid}/conversations/{docId}           ← metadata cuộc hội thoại
//     title, lastMessage, createdAt, updatedAt
//
//   users/{uid}/conversations/{docId}/messages/{msgId}  ← nội dung tin nhắn
//     text, isAi, timestamp, citations
//
// Quy tắc:
//   - docId (UUID từ backend) = conversationId → 1 doc = 1 hội thoại duy nhất
//   - Lịch sử luôn được bảo toàn khi mở lại cùng tài liệu
//   - Mỗi user có namespace riêng biệt qua {uid}
//
// RAG pipeline (sendMessage):
//   embed(question) → pgvector search → Gemini 2.5 Flash → {answer, citations}
// =============================================================================

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isLoadingHistory = false;
  bool _hasLoadedHistory = false;
  Timer? _responseTimer;

  String? _activeDocId;
  String? _activeDocTitle;
  String? _activeNotebookId;
  String? _activeNotebookName;

  final List<Conversation> _conversations = [];
  bool _isLoadingConversations = false;

  String? get activeDocId => _activeDocId;
  String? get activeDocTitle => _activeDocTitle;
  String? get activeNotebookId => _activeNotebookId;
  String? get activeNotebookName => _activeNotebookName;
  List<ChatMessage> get messages => _messages;
  bool get isTyping => _isTyping;
  bool get isLoadingHistory => _isLoadingHistory;
  List<Conversation> get conversations => _conversations;
  bool get isLoadingConversations => _isLoadingConversations;

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference? get _messagesRef {
    final uid = _userId;
    final docId = _activeDocId;
    if (uid == null || docId == null) return null;
    return FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('conversations').doc(docId)
        .collection('messages');
  }

  CollectionReference? _conversationsRef([String? uid]) {
    final id = uid ?? _userId;
    if (id == null) return null;
    return FirebaseFirestore.instance
        .collection('users').doc(id)
        .collection('conversations');
  }

  ChatProvider() {
    _messages.add(ChatMessage(
      text: 'Xin chào! Nhấn nút + để chọn tài liệu hoặc notebook cần hỏi.',
      isAi: true,
    ));
    // Tải danh sách hội thoại ngay khi user đăng nhập
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        loadConversations();
      } else {
        _conversations.clear();
        _messages.clear();
        _activeDocId = null;
        _activeDocTitle = null;
        _hasLoadedHistory = false;
        notifyListeners();
      }
    });
  }

  /// Chuyển sang hội thoại của tài liệu [docId].
  /// Nếu cùng docId và lịch sử đã tải → bỏ qua (tránh reload không cần thiết).
  void setActiveDoc(String? docId, {String? docTitle}) {
    if (docId == _activeDocId && _hasLoadedHistory) return;

    _activeDocId = docId;
    _activeDocTitle = docTitle;
    _messages.clear();
    _hasLoadedHistory = false;

    final greeting = docTitle != null
        ? 'Xin chào! Tôi sẵn sàng trả lời câu hỏi về tài liệu "$docTitle".'
        : 'Xin chào! Tôi sẵn sàng trả lời câu hỏi của bạn.';
    _messages.add(ChatMessage(text: greeting, isAi: true));
    notifyListeners();

    if (docId != null) {
      _upsertConversationMeta(docId, docTitle ?? 'Tài liệu');
      loadHistory();
    }
  }

  // Giữ tương thích với các nơi đang gọi startNewConversation
  void startNewConversation({String? docId, String? docTitle}) {
    setActiveDoc(docId, docTitle: docTitle);
  }

  /// Xoá ngữ cảnh — trở về chế độ chưa chọn tài liệu/notebook.
  void clearActiveContext() {
    _activeDocId = null;
    _activeDocTitle = null;
    _activeNotebookId = null;
    _activeNotebookName = null;
    _messages.clear();
    _hasLoadedHistory = false;
    _messages.add(ChatMessage(
      text: 'Xin chào! Nhấn nút + để chọn tài liệu hoặc notebook cần hỏi.',
      isAi: true,
    ));
    notifyListeners();
  }

  /// Chuyển sang chế độ chat theo notebook — tìm kiếm xuyên suốt tất cả docs trong notebook.
  void setActiveNotebook(String? notebookId, {String? notebookName}) {
    _activeNotebookId = notebookId;
    _activeNotebookName = notebookName;
    _activeDocId = null;
    _activeDocTitle = null;
    _messages.clear();
    _hasLoadedHistory = false;

    final greeting = notebookName != null
        ? 'Xin chào! Tôi sẵn sàng trả lời câu hỏi về notebook "$notebookName".'
        : 'Xin chào! Tôi sẵn sàng trả lời câu hỏi của bạn.';
    _messages.add(ChatMessage(text: greeting, isAi: true));
    notifyListeners();
  }

  /// Tạo conversation metadata trong Firestore nếu chưa tồn tại.
  Future<void> _upsertConversationMeta(String docId, String title) async {
    final ref = _conversationsRef()?.doc(docId);
    if (ref == null) return;
    try {
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'docId': docId,
          'title': title,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
        });
        loadConversations(); // Cập nhật danh sách trong drawer
      }
    } catch (e) {
      debugPrint('Lỗi tạo conversation meta: $e');
    }
  }

  /// Cập nhật tin nhắn cuối và thời gian vào metadata.
  Future<void> _updateLastMessage(String text) async {
    if (_activeDocId == null) return;
    final ref = _conversationsRef()?.doc(_activeDocId);
    if (ref == null) return;
    final preview = text.length > 80 ? '${text.substring(0, 80)}...' : text;
    try {
      await ref.update({
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': preview,
      });
      // Cập nhật luôn danh sách local
      final idx = _conversations.indexWhere((c) => c.docId == _activeDocId);
      if (idx >= 0) {
        final c = _conversations[idx];
        _conversations[idx] = Conversation(
          docId: c.docId,
          title: c.title,
          lastMessage: preview,
          updatedAt: DateTime.now(),
        );
        // Đưa hội thoại này lên đầu danh sách
        if (idx > 0) {
          final updated = _conversations.removeAt(idx);
          _conversations.insert(0, updated);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Lỗi cập nhật lastMessage: $e');
    }
  }

  /// Tải danh sách tất cả hội thoại của user, sắp xếp theo thời gian mới nhất.
  Future<void> loadConversations() async {
    final ref = _conversationsRef();
    if (ref == null || _isLoadingConversations) return;

    _isLoadingConversations = true;
    notifyListeners();

    try {
      final snapshot = await ref
          .orderBy('updatedAt', descending: true)
          .get();

      _conversations.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _conversations.add(Conversation(
          docId: data['docId']?.toString() ?? doc.id,
          title: data['title'] ?? 'Tài liệu',
          lastMessage: data['lastMessage'] ?? '',
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }
    } catch (e) {
      debugPrint('Lỗi tải danh sách hội thoại: $e');
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  /// Tải lịch sử tin nhắn của hội thoại đang active.
  Future<void> loadHistory() async {
    if (_hasLoadedHistory || _isLoadingHistory) return;
    final ref = _messagesRef;
    if (ref == null) return;

    _isLoadingHistory = true;
    notifyListeners();

    try {
      final snapshot = await ref
          .orderBy('timestamp', descending: false)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _messages.clear();
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final List<dynamic> citData = data['citations'] ?? [];
          final citations = citData
              .map((c) => CitationData(
                    c['label'] ?? '',
                    c['value'] ?? '',
                    snippet: c['snippet'] ?? '',
                    filename: c['filename'] ?? '',
                  ))
              .toList();
          _messages.add(ChatMessage(
            text: data['text'] ?? '',
            isAi: data['isAi'] ?? false,
            citations: citations,
          ));
        }
      }
      _hasLoadedHistory = true;
    } catch (e) {
      debugPrint('Lỗi tải lịch sử chat: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Xoá toàn bộ state — gọi trước khi đăng xuất.
  void clearAll() {
    _messages.clear();
    _conversations.clear();
    _activeDocId = null;
    _activeDocTitle = null;
    _activeNotebookId = null;
    _activeNotebookName = null;
    _hasLoadedHistory = false;
    notifyListeners();
  }

  /// Gửi tin nhắn qua RAG pipeline (SSE streaming).
  void sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _messages.add(ChatMessage(text: text, isAi: false));
    _isTyping = true;
    notifyListeners();

    final uid = _userId;
    final user = FirebaseAuth.instance.currentUser;
    final ref = _messagesRef;

    // Lưu tin nhắn user vào Firestore
    if (uid != null && ref != null) {
      try {
        await ref.add({
          'text': text,
          'isAi': false,
          'timestamp': FieldValue.serverTimestamp(),
          'citations': [],
        });
        _updateLastMessage(text);
      } catch (e) {
        debugPrint('Lỗi lưu tin nhắn user: $e');
      }
    }

    // Mock fallback khi chưa có backend URL hoặc chưa đăng nhập
    if (AppConstants.backendBaseUrl.contains('your-backend-railway-url') || user == null) {
      _responseTimer?.cancel();
      _responseTimer = Timer(const Duration(milliseconds: 1500), () async {
        _isTyping = false;
        final mockMsg = ChatMessage(
          text: 'Dựa trên tài liệu, AI đang áp dụng kiến trúc đa phương thức để cải thiện hiểu biết ngữ cảnh.',
          isAi: true,
          citations: [CitationData('Trang', '12'), CitationData('Trang', '20')],
        );
        _messages.add(mockMsg);
        if (uid != null && ref != null) {
          try {
            await ref.add({
              'text': mockMsg.text,
              'isAi': true,
              'timestamp': FieldValue.serverTimestamp(),
              'citations': mockMsg.citations
                  .map((c) => {'label': c.label, 'value': c.value, 'snippet': c.snippet, 'filename': c.filename})
                  .toList(),
            });
            _updateLastMessage(mockMsg.text);
          } catch (e) {
            debugPrint('Lỗi lưu mock response: $e');
          }
        }
        notifyListeners();
      });
      return;
    }

    try {
      final idToken = await user.getIdToken();

      final history = _messages
          .where((m) => !m.text.startsWith('Xin chào!'))
          .toList()
          .reversed
          .take(8)
          .toList()
          .reversed
          .map((m) => {'role': m.isAi ? 'model' : 'user', 'content': m.text})
          .toList();

      final body = <String, dynamic>{'message': text, 'history': history};
      if (_activeNotebookId != null) {
        body['notebook_id'] = _activeNotebookId;
      } else if (_activeDocId != null) {
        body['doc_id'] = _activeDocId;
      }

      final request = http.Request(
        'POST',
        Uri.parse('${AppConstants.backendBaseUrl}/chat/stream'),
      );
      request.headers['Authorization'] = 'Bearer $idToken';
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode(body);

      final streamedResponse = await http.Client()
          .send(request)
          .timeout(const Duration(seconds: 30));

      if (streamedResponse.statusCode != 200) {
        throw Exception('Lỗi server: ${streamedResponse.statusCode}');
      }

      // bubbleIdx null cho đến khi token đầu tiên đến
      // → typing indicator giữ nguyên trong khi server đang embed/Supabase/Gemini
      int? bubbleIdx;
      String fullText = '';
      List<CitationData> citations = [];

      await for (final line in streamedResponse.stream
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        final raw = line.substring(6).trim();
        if (raw.isEmpty) continue;
        try {
          final event = json.decode(raw) as Map<String, dynamic>;
          final type = event['type'] as String? ?? '';

          if (type == 'processing' || type == 'ping') {
            // Server đang xử lý — giữ nguyên typing indicator
          } else if (type == 'citations') {
            final citData = event['citations'] as List? ?? [];
            citations = citData
                .map((c) => CitationData(
                      c['label'] ?? 'Nguồn',
                      c['value']?.toString() ?? '',
                      snippet: c['snippet'] ?? '',
                      filename: c['filename'] ?? '',
                    ))
                .toList();
          } else if (type == 'token') {
            final token = event['text'] as String? ?? '';
            if (token.isEmpty) continue;
            fullText += token;
            if (bubbleIdx == null) {
              // Token đầu tiên — thêm bubble, ẩn typing indicator
              _messages.add(ChatMessage(
                  text: fullText, isAi: true, citations: citations));
              bubbleIdx = _messages.length - 1;
              _isTyping = false;
            } else {
              _messages[bubbleIdx] = ChatMessage(
                  text: fullText, isAi: true, citations: citations);
            }
            notifyListeners();
          } else if (type == 'done' || type == 'error') {
            if (type == 'error' && fullText.isEmpty) {
              final msg = event['message'] as String? ??
                  'Có lỗi xảy ra. Vui lòng thử lại.';
              _isTyping = false;
              _messages.add(ChatMessage(text: msg, isAi: true));
              notifyListeners();
            }
            if (uid != null && ref != null && fullText.isNotEmpty) {
              try {
                await ref.add({
                  'text': fullText,
                  'isAi': true,
                  'timestamp': FieldValue.serverTimestamp(),
                  'citations': citations
                      .map((c) => {
                            'label': c.label,
                            'value': c.value,
                            'snippet': c.snippet,
                            'filename': c.filename,
                          })
                      .toList(),
                });
                _updateLastMessage(fullText);
              } catch (e) {
                debugPrint('Lỗi lưu AI response: $e');
              }
            }
          }
        } catch (_) {}
      }

      // Stream kết thúc nhưng chưa nhận được token nào
      if (bubbleIdx == null) {
        _isTyping = false;
        _messages.add(ChatMessage(
            text: 'Không nhận được phản hồi. Vui lòng thử lại.', isAi: true));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Chat stream error: $e');
      _isTyping = false;
      final errorMsg = e.toString().contains('TimeoutException')
          ? 'Kết nối tới máy chủ quá chậm, vui lòng thử lại.'
          : 'Không kết nối được máy chủ AI. Kiểm tra mạng và thử lại.';
      _messages.add(ChatMessage(text: errorMsg, isAi: true));
      if (uid != null && ref != null) {
        try {
          await ref.add({
            'text': errorMsg,
            'isAi': true,
            'timestamp': FieldValue.serverTimestamp(),
            'citations': [],
          });
        } catch (_) {}
      }
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _responseTimer?.cancel();
    super.dispose();
  }
}
