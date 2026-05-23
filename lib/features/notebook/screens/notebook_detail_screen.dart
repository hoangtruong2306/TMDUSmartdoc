import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../shared/widgets/widgets.dart';
import '../../notebooks/providers/notebook_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../flashcards/models/flashcard_model.dart';
import '../../quiz/models/quiz_model.dart';
import '../providers/notebook_documents_provider.dart';

// ── Summary state ─────────────────────────────────────────────────────────────
// idle      : chưa có tài liệu nào / chưa bao giờ tóm tắt
// processing: vừa upload / gán tài liệu — đang chờ AI tóm tắt
// justDone  : tóm tắt vừa hoàn thành (hiển thị banner 3 giây)
// ready     : đã có tóm tắt, hiển thị bình thường
enum _SummaryState { idle, processing, justDone, ready }

// ── Icon data helpers ─────────────────────────────────────────────────────────

final _iconMap = <String, IconData>{
  'school': Icons.school_rounded,
  'book': Icons.menu_book_rounded,
  'science': Icons.science_rounded,
  'math': Icons.calculate_rounded,
  'economics': Icons.trending_up_rounded,
  'computer': Icons.computer_rounded,
  'medical': Icons.medical_services_rounded,
  'history': Icons.history_edu_rounded,
  'art': Icons.palette_rounded,
  'language': Icons.translate_rounded,
  'law': Icons.gavel_rounded,
  'idea': Icons.lightbulb_rounded,
};

IconData _iconForKey(String key) =>
    _iconMap[key] ?? Icons.auto_stories_rounded;

Color _parseHex(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return const Color(0xFF6750A4);
  }
}

// ── Notebook Detail Screen ────────────────────────────────────────────────────

class NotebookDetailScreen extends StatefulWidget {
  final String notebookId;

  const NotebookDetailScreen({super.key, required this.notebookId});

  @override
  State<NotebookDetailScreen> createState() => _NotebookDetailScreenState();
}

class _NotebookDetailScreenState extends State<NotebookDetailScreen> {
  late final NotebookDocumentsProvider _docsProvider;
  bool _isSelectionMode = false;
  final Set<String> _selectedDocIds = {};
  Timer? _pollTimer;

  // ── Summary state machine ──────────────────────────────────────────────────
  _SummaryState _summaryState = _SummaryState.idle;
  String _prevSummary = ''; // dùng để detect khi summary thay đổi

  @override
  void initState() {
    super.initState();
    _docsProvider = NotebookDocumentsProvider(notebookId: widget.notebookId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _docsProvider.loadDocuments();
      // Khởi tạo state dựa vào summary hiện tại
      final nbs = context.read<NotebookProvider>().notebooks;
      final idx = nbs.indexWhere((n) => n.id == widget.notebookId);
      if (idx >= 0) {
        _prevSummary  = nbs[idx].summary;
        _summaryState = nbs[idx].summary.isNotEmpty
            ? _SummaryState.ready
            : _SummaryState.idle;
      }
      _startSummaryPolling();
    });
  }

  /// Bắt đầu / restart vòng polling summary mỗi 4 giây.
  ///
  /// [forceProcessing] = true → ngay lập tức hiển thị "đang tóm tắt"
  /// (gọi sau khi upload hoặc gán thêm tài liệu vào notebook).
  void _startSummaryPolling({bool forceProcessing = false}) {
    if (forceProcessing) {
      setState(() => _summaryState = _SummaryState.processing);
    } else {
      // Nếu đã có summary và không force → không cần poll
      final nbs = context.read<NotebookProvider>().notebooks;
      final idx = nbs.indexWhere((n) => n.id == widget.notebookId);
      if (idx >= 0 && nbs[idx].summary.isNotEmpty) return;
    }

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) { _pollTimer?.cancel(); return; }

      await context.read<NotebookProvider>().refresh();
      if (!mounted) return;

      final updated   = context.read<NotebookProvider>().notebooks;
      final updatedIdx = updated.indexWhere((n) => n.id == widget.notebookId);
      if (updatedIdx < 0) return;

      final newSummary = updated[updatedIdx].summary;

      // Phát hiện summary vừa xuất hiện hoặc thay đổi
      if (newSummary.isNotEmpty && newSummary != _prevSummary) {
        _prevSummary = newSummary;
        _pollTimer?.cancel();

        // Hiển thị banner "Tóm tắt xong!" trong 3 giây rồi chuyển sang ready
        setState(() => _summaryState = _SummaryState.justDone);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _summaryState = _SummaryState.ready);
        });
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _toggleDocSelection(String id) {
    setState(() {
      if (_selectedDocIds.contains(id)) {
        _selectedDocIds.remove(id);
        if (_selectedDocIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedDocIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _clearDocSelection() {
    setState(() {
      _selectedDocIds.clear();
      _isSelectionMode = false;
    });
  }

  /// Gỡ tài liệu đã chọn khỏi notebook (giữ file, đặt notebook_id = null).
  Future<void> _confirmUnassignSelectedDocs() async {
    if (_selectedDocIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: const Text('Gỡ khỏi notebook?'),
        content: Text(
          'Gỡ ${_selectedDocIds.length} tài liệu ra khỏi notebook này.\n'
          'File vẫn được giữ lại, bạn có thể thêm vào notebook khác sau.',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Gỡ ra'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final count = await _docsProvider.unassignDocuments(_selectedDocIds.toList());
    if (!mounted) return;
    if (count > 0) {
      _clearDocSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã gỡ $count tài liệu khỏi notebook'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gỡ thất bại, thử lại'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDeleteSelectedDocs() async {
    if (_selectedDocIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: const Text('Xoá nhiều tài liệu?'),
        content: Text(
          'Bạn có chắc muốn xoá ${_selectedDocIds.length} tài liệu đã chọn?',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      final success = await _docsProvider.deleteDocuments(_selectedDocIds.toList());
      if (mounted && success) {
        _clearDocSelection();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xóa thất bại'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _onSuggestionTap(String question) {
    final notebookProvider = context.read<NotebookProvider>();
    final notebook = notebookProvider.notebooks.firstWhere(
      (nb) => nb.id == widget.notebookId,
      orElse: () => notebookProvider.notebooks.isNotEmpty
          ? notebookProvider.notebooks.first
          : throw Exception('Notebook not found'),
    );

    if (!context.mounted) return;
    
    final chatProvider = context.read<ChatProvider>();
    try {
      chatProvider.setActiveNotebook(
        widget.notebookId,
        notebookName: notebook.name,
      );
      chatProvider.sendMessage(question);
    } catch (_) {}
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/chat');
    });
  }

  void _onChatTap() {
    final notebookProvider = context.read<NotebookProvider>();
    final notebook = notebookProvider.notebooks.firstWhere(
      (nb) => nb.id == widget.notebookId,
      orElse: () => notebookProvider.notebooks.isNotEmpty
          ? notebookProvider.notebooks.first
          : throw Exception('Notebook not found'),
    );

    if (!context.mounted) return;
    try {
      context.read<ChatProvider>().setActiveNotebook(
        widget.notebookId,
        notebookName: notebook.name,
      );
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/chat');
    });
  }

  void _navigateToUpload() {
    // Dùng route riêng ngoài ShellRoute để tránh duplicate GlobalKey crash.
    // .then() chạy khi user pop về:
    //   • refresh danh sách tài liệu ngay lập tức
    //   • bật trạng thái "đang tóm tắt" + restart polling summary
    context.push('/notebook/${widget.notebookId}/upload').then((_) {
      if (!mounted) return;
      _docsProvider.refresh();
      _startSummaryPolling(forceProcessing: true);
    });
  }

  /// Mở bottom sheet lịch sử học (Flashcard + Luyện thi) cho notebook này.
  void _showHistorySheet(
    BuildContext context, {
    required String notebookId,
    required String notebookName,
    required Color accent,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NotebookHistorySheet(
        notebookId: notebookId,
        notebookName: notebookName,
        accent: accent,
      ),
    );
  }

  /// Mở bottom sheet cho phép user chọn tài liệu đã upload để thêm vào notebook.
  void _showAddSheet() {
    final notebookProvider = context.read<NotebookProvider>();
    final nb = notebookProvider.notebooks.firstWhere(
      (n) => n.id == widget.notebookId,
      orElse: () => notebookProvider.notebooks.isNotEmpty
          ? notebookProvider.notebooks.first
          : Notebook(
              id: widget.notebookId,
              name: 'Notebook',
              color: '#6750A4',
              updatedAt: DateTime.now(),
            ),
    );
    final accent = _parseHex(nb.color);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DocumentPickerSheet(
        notebookId: widget.notebookId,
        alreadyInNotebook: _docsProvider.documents.map((d) => d.id).toSet(),
        accent: accent,
        onUpload: () {
          Navigator.pop(ctx);
          _navigateToUpload();
        },
        onAssigned: () {
          _docsProvider.refresh();
          // Tài liệu mới được gán → backend sẽ tóm tắt lại
          _startSummaryPolling(forceProcessing: true);
        },
      ),
    );
  }

  // ── Summary section widgets ────────────────────────────────────────────────

  Widget _buildSummarySection(Notebook nb, Color accent, BuildContext context) {
    // Guard: nếu state = ready nhưng summary bị xóa → lùi về idle
    final effectiveState = (_summaryState == _SummaryState.ready ||
            _summaryState == _SummaryState.justDone) &&
        nb.summary.isEmpty
        ? _SummaryState.idle
        : _summaryState;

    switch (effectiveState) {
      case _SummaryState.processing:
        return _buildSummarizingState(accent, context);
      case _SummaryState.justDone:
        return _buildSummaryJustDone(nb.summary, accent, context);
      case _SummaryState.ready:
        return _buildSummaryReady(nb.summary, accent, context);
      case _SummaryState.idle:
        return _buildSummaryIdle(accent, context);
    }
  }

  // ── State: đang tóm tắt ───────────────────────────────────────────────────
  Widget _buildSummarizingState(Color accent, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI đang tóm tắt nội dung...',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: accent, fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Vui lòng đợi trong khi AI phân tích tài liệu',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Shimmer placeholder lines
        _ShimmerLine(color: accent),
        const SizedBox(height: 8),
        _ShimmerLine(color: accent),
        const SizedBox(height: 8),
        _ShimmerLine(color: accent, widthFactor: 0.65),
      ],
    );
  }

  // ── State: tóm tắt vừa xong ───────────────────────────────────────────────
  Widget _buildSummaryJustDone(String summary, Color accent, BuildContext context) {
    const green = Color(0xFF4CAF50);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner xanh "Tóm tắt xong!"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: green.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, size: 15, color: green),
              const SizedBox(width: 6),
              Text(
                'Tóm tắt xong! AI đã phân tích xong tài liệu.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: green, fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSummaryRow(summary, accent, context),
      ],
    );
  }

  // ── State: đã có tóm tắt bình thường ─────────────────────────────────────
  Widget _buildSummaryReady(String summary, Color accent, BuildContext context) {
    return _buildSummaryRow(summary, accent, context);
  }

  // ── State: chưa có tóm tắt / chưa có tài liệu ────────────────────────────
  Widget _buildSummaryIdle(Color accent, BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 40,
            color: accent.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Chưa có tóm tắt AI',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textTertiary, fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Thêm tài liệu để nhận tóm tắt thông minh từ AI',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    ).appEntrance();
  }

  // ── Shared summary row (icon + text) ──────────────────────────────────────
  Widget _buildSummaryRow(String summary, Color accent, BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.auto_awesome, size: 16, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tóm tắt AI',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: accent, fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary, height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ).appEntrance();
  }

  @override
  Widget build(BuildContext context) {
    final notebookProvider = context.watch<NotebookProvider>();
    final nb = notebookProvider.notebooks.firstWhere(
      (n) => n.id == widget.notebookId,
      orElse: () => notebookProvider.notebooks.isNotEmpty
          ? notebookProvider.notebooks.first
          : Notebook(
              id: widget.notebookId,
              name: 'Notebook',
              color: '#6750A4',
              updatedAt: DateTime.now(),
            ),
    );

    final accent = _parseHex(nb.color);
    final pagePadding = AppBreakpoints.pagePadding(context);

    return ChangeNotifierProvider.value(
      value: _docsProvider,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _isSelectionMode
            ? AppBar(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearDocSelection,
                ),
                title: Text('Đã chọn ${_selectedDocIds.length}'),
                actions: [
                  // Gỡ khỏi notebook (giữ file)
                  TextButton.icon(
                    onPressed: _selectedDocIds.isEmpty
                        ? null
                        : _confirmUnassignSelectedDocs,
                    icon: Icon(
                      Icons.folder_off_outlined,
                      size: 16,
                      color: _selectedDocIds.isEmpty
                          ? AppColors.textTertiary
                          : AppColors.textSecondary,
                    ),
                    label: Text(
                      'Gỡ ra',
                      style: TextStyle(
                        color: _selectedDocIds.isEmpty
                            ? AppColors.textTertiary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  // Xóa vĩnh viễn
                  TextButton(
                    onPressed: _selectedDocIds.isEmpty
                        ? null
                        : _confirmDeleteSelectedDocs,
                    child: Text(
                      'Xóa',
                      style: TextStyle(
                        color: _selectedDocIds.isEmpty
                            ? AppColors.textTertiary
                            : AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              )
            : AppBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.primary),
                  onPressed: () => context.pop(),
                ),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_iconForKey(nb.icon), size: 17, color: accent),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        nb.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.history_rounded, color: accent),
                    tooltip: 'Lịch sử học',
                    onPressed: () => _showHistorySheet(
                      context,
                      notebookId: widget.notebookId,
                      notebookName: nb.name,
                      accent: accent,
                    ),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: AppColors.border),
                ),
              ),
        // ── Bottom action bar: Chat với AI + Luyện thi ────────────────────────
        // ── Bottom action bar: Chat AI | Flashcard | Luyện thi ─────────────────
        // 3 nút bằng nhau (flex: 1). Padding bottom dùng MediaQuery tránh gesture bar.
        bottomNavigationBar: _isSelectionMode
            ? null
            : Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(
                  14, 10, 14,
                  MediaQuery.of(context).padding.bottom + 10,
                ),
                child: Row(
                  children: [
                    // ── Chat với AI — gradient fill ────────────────────────
                    Expanded(
                      flex: 5,
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1565C0)
                                  .withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _onChatTap,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_rounded,
                                    size: 15, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Chat AI',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ── Flashcard ────────────────────────────────────────────
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(
                          '/flashcards/${widget.notebookId}'
                          '?name=${Uri.encodeComponent(nb.name)}',
                        ),
                        icon: Icon(Icons.style_rounded, size: 15, color: accent),
                        label: Text(
                          'Flashcard',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: accent,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          foregroundColor: accent,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          side: BorderSide(
                              color: accent.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ── Luyện thi ────────────────────────────────────────────
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(
                          '/quiz/${widget.notebookId}'
                          '?name=${Uri.encodeComponent(nb.name)}',
                        ),
                        icon: Icon(Icons.quiz_rounded, size: 15, color: accent),
                        label: Text(
                          'Luyện thi',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: accent,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          foregroundColor: accent,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          side: BorderSide(
                              color: accent.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        body: SafeArea(
          bottom: false, // bottom đã được bottomNavigationBar xử lý
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Hero Banner ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomCenter,
                      colors: [
                        accent,
                        Color.lerp(accent, Colors.black, 0.18)!,
                      ],
                    ),
                  ),
                  padding: pagePadding.copyWith(
                    top: AppSpacing.lg,
                    bottom: AppSpacing.lg,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Large icon
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Icon(
                          _iconForKey(nb.icon),
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nb.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Consumer<NotebookDocumentsProvider>(
                              builder: (ctx, docs, _) => Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.article_outlined,
                                            size: 12, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${docs.documents.length} tài liệu',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (nb.summary.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.auto_awesome,
                                              size: 11, color: Colors.white),
                                          SizedBox(width: 4),
                                          Text(
                                            'AI đã tóm tắt',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Summary Card ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: pagePadding.copyWith(
                    top: AppSpacing.md,
                    bottom: 0,
                  ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border(
                          left: BorderSide(color: accent, width: 4),
                          top: BorderSide(
                              color: AppColors.border, width: 1),
                          right: BorderSide(
                              color: AppColors.border, width: 1),
                          bottom: BorderSide(
                              color: AppColors.border, width: 1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: _buildSummarySection(nb, accent, context),
                    ),
                  ),
                ),
              ),

              // ── Suggestion Chips ─────────────────────────────────────────────
              if (nb.suggestions.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: pagePadding.copyWith(
                      top: AppSpacing.lg,
                      bottom: AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 3, height: 14,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Hỏi AI nhanh',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: nb.suggestions.take(4).map((s) {
                            return ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.80,
                              ),
                              child: GestureDetector(
                                onTap: () => _onSuggestionTap(s),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.30),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.04),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 13,
                                          color: accent),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          s,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: accent,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ).appEntrance(
                            delay: const Duration(milliseconds: 100)),
                      ],
                    ),
                  ),
                ),

              // ── Documents Header ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: pagePadding.left,
                    right: pagePadding.right,
                    top: AppSpacing.lg,
                    bottom: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3, height: 14,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tài liệu',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (!_isSelectionMode)
                        TextButton.icon(
                          onPressed: _showAddSheet,
                          icon: Icon(Icons.add, size: 16, color: accent),
                          label:
                              Text('Thêm', style: TextStyle(color: accent)),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Documents List ──────────────────────────────────────────────
              Consumer<NotebookDocumentsProvider>(
                builder: (context, docsProvider, child) {
                  if (docsProvider.isLoading) {
                    return SliverPadding(
                      padding: pagePadding,
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => const Padding(
                            padding: EdgeInsets.only(bottom: AppSpacing.md),
                            child: DocumentCardSkeleton(),
                          ),
                          childCount: 3,
                        ),
                      ),
                    );
                  }

                  if (docsProvider.documents.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyNotebookDocs(
                        accent: accent,
                        onUpload: _showAddSheet,
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: pagePadding.copyWith(bottom: 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final doc = docsProvider.documents[index];
                          final isSelected = _selectedDocIds.contains(doc.id);
                          return _DocListTile(
                            doc: doc,
                            accent: accent,
                            index: index,
                            isSelectionMode: _isSelectionMode,
                            isSelected: isSelected,
                            onTap: _isSelectionMode
                                ? () => _toggleDocSelection(doc.id)
                                : () {},
                            onLongPress: () => _toggleDocSelection(doc.id),
                          );
                        },
                        childCount: docsProvider.documents.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shimmer Line (dùng trong summary "đang xử lý") ───────────────────────────

class _ShimmerLine extends StatefulWidget {
  final Color color;
  /// Tỷ lệ chiều rộng so với parent (0.0 – 1.0). Mặc định 1.0 (full width).
  final double widthFactor;

  const _ShimmerLine({required this.color, this.widthFactor = 1.0});

  @override
  State<_ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<_ShimmerLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => FractionallySizedBox(
        widthFactor: widget.widthFactor,
        alignment: Alignment.centerLeft,
        child: Container(
          height: 11,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.06 + 0.09 * _ctrl.value),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

// ── Document List Tile ───────────────────────────────────────────────────────

class _DocListTile extends StatelessWidget {
  final NotebookDocument doc;
  final Color accent;
  final int index;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _DocListTile({
    required this.doc,
    required this.accent,
    required this.index,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isPdf = doc.type.toLowerCase() == 'pdf';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: isSelected
            ? accent.withValues(alpha: 0.04)
            : AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: isSelected ? accent : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: AppShadows.card,
      ),
      // ClipRRect + IntrinsicHeight + Row để tạo left accent bar
      // mà không vi phạm quy tắc borderRadius + non-uniform border
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          AppRadius.card.topLeft.x - 1,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(width: 3, color: accent),
              // Main content
              Expanded(
                child: ListTile(
        contentPadding: AppSpacing.cardPaddingCompact,
        onTap: onTap,
        onLongPress: onLongPress,
        selected: isSelected,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: AppRadius.control,
          ),
          child: Icon(
            isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
            color: accent,
            size: 20,
          ),
        ),
        title: Text(
          doc.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: doc.isProcessing
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10, height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.orange.shade600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Đang xử lý...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : doc.isFailed
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 12, color: AppColors.error),
                      const SizedBox(width: 4),
                      Text(
                        'Xử lý thất bại',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  )
                : Text(
                    isPdf ? '${doc.pageCount} trang · PDF' : 'Tài liệu văn bản',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
        trailing: isSelectionMode
            ? Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                size: 24,
                color: isSelected ? accent : AppColors.border,
              )
            : doc.isProcessing
                ? Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        'Đang xử lý',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    color: AppColors.textSecondary,
                    onPressed: () {
                      // TODO: Open document viewer
                    },
                  ),
              ),   // closes ListTile
            ),     // closes Expanded
          ],       // closes Row children
        ),         // closes Row
      ),           // closes IntrinsicHeight
    ),             // closes ClipRRect
  ).appEntrance(delay: AppMotion.stagger(index));
  }
}

// ── Empty State for Documents ─────────────────────────────────────────────────

class _EmptyNotebookDocs extends StatelessWidget {
  final Color accent;
  final VoidCallback onUpload;

  const _EmptyNotebookDocs({required this.accent, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_outlined,
                size: 48,
                color: accent.withValues(alpha: 0.6),
              ),
            ).appScaleIn(),
            AppSpacing.vLg,
            Text(
              'Chưa có tài liệu',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ).appEntrance(delay: const Duration(milliseconds: 100)),
            AppSpacing.vSm,
            Text(
              'Thêm tài liệu vào notebook này\nđể nhận tóm tắt thông minh từ AI.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ).appEntrance(delay: const Duration(milliseconds: 160)),
            AppSpacing.vXl,
            CustomButton(
              label: 'Thêm tài liệu',
              onPressed: onUpload,
              icon: Icons.add_rounded,
            ).appEntrance(delay: const Duration(milliseconds: 220)),
          ],
        ),
      ),
    );
  }
}

// ── Document Picker Sheet ────────────────────────────────────────────────────
// Hiển thị tất cả tài liệu của user (chưa thuộc notebook này).
// User tick chọn → nhấn "Thêm" → gọi POST /documents/assign.

class _DocumentPickerSheet extends StatefulWidget {
  final String notebookId;
  final Set<String> alreadyInNotebook; // IDs đã có trong notebook → ẩn
  final Color accent;
  final VoidCallback onUpload;   // Khi user chọn upload tài liệu mới
  final VoidCallback onAssigned; // Callback sau khi gán thành công

  const _DocumentPickerSheet({
    required this.notebookId,
    required this.alreadyInNotebook,
    required this.accent,
    required this.onUpload,
    required this.onAssigned,
  });

  @override
  State<_DocumentPickerSheet> createState() => _DocumentPickerSheetState();
}

class _DocumentPickerSheetState extends State<_DocumentPickerSheet> {
  // Tất cả tài liệu của user (không lọc notebook)
  List<NotebookDocument> _allDocs = [];
  bool _isLoading = true;
  bool _isAssigning = false;
  // Tập IDs user đã tick chọn trong sheet này
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadAllDocs();
  }

  Future<void> _loadAllDocs() async {
    final docs = await NotebookDocumentsProvider.fetchAllUserDocuments();
    if (!mounted) return;
    setState(() {
      // Lọc bỏ những tài liệu đã thuộc notebook này
      _allDocs = docs
          .where((d) => !widget.alreadyInNotebook.contains(d.id))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _confirmAssign() async {
    if (_selected.isEmpty || _isAssigning) return;
    setState(() => _isAssigning = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse('${AppConstants.backendBaseUrl}/documents/assign'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'doc_ids': _selected.toList(),
          'notebook_id': widget.notebookId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final count = result['assigned_count'] as int? ?? _selected.length;

        widget.onAssigned(); // Reload danh sách notebook
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm $count tài liệu vào notebook'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _isAssigning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi: Không thể thêm tài liệu'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAssigning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi kết nối'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── Handle & Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Thêm tài liệu',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_selected.isNotEmpty)
                        Text(
                          'Đã chọn ${_selected.length}',
                          style: TextStyle(
                            color: widget.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Divider(color: AppColors.border, height: 1),

            // ── Upload mới option ────────────────────────────────────────────
            ListTile(
              onTap: widget.onUpload,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.1),
                  borderRadius: AppRadius.control,
                ),
                child: Icon(
                  Icons.upload_file_rounded,
                  color: widget.accent,
                  size: 20,
                ),
              ),
              title: Text(
                'Upload tài liệu mới',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.accent,
                ),
              ),
              subtitle: Text(
                'Tải lên file PDF hoặc TXT mới',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: widget.accent,
              ),
            ),

            Divider(color: AppColors.border, height: 1),

            // ── List tiêu đề ─────────────────────────────────────────────────
            if (!_isLoading)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _allDocs.isEmpty
                        ? 'Tài liệu đã có trong notebook'
                        : 'Chọn từ tài liệu đã upload',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // ── Documents list ───────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _allDocs.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          itemCount: _allDocs.length,
                          itemBuilder: (ctx, index) {
                            final doc = _allDocs[index];
                            final isSelected = _selected.contains(doc.id);
                            final isPdf = doc.type.toLowerCase() == 'pdf';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? widget.accent.withValues(alpha: 0.05)
                                    : AppColors.surfaceElevated,
                                borderRadius: AppRadius.card,
                                border: Border.all(
                                  color: isSelected
                                      ? widget.accent
                                      : AppColors.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: AppSpacing.cardPaddingCompact,
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selected.remove(doc.id);
                                    } else {
                                      _selected.add(doc.id);
                                    }
                                  });
                                },
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: widget.accent.withValues(alpha: 0.1),
                                    borderRadius: AppRadius.control,
                                  ),
                                  child: Icon(
                                    isPdf
                                        ? Icons.picture_as_pdf_rounded
                                        : Icons.description_rounded,
                                    color: widget.accent,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  doc.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                subtitle: Text(
                                  isPdf
                                      ? '${doc.pageCount} trang · PDF'
                                      : 'Tài liệu văn bản',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.textTertiary,
                                      ),
                                ),
                                trailing: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    key: ValueKey(isSelected),
                                    color: isSelected
                                        ? widget.accent
                                        : AppColors.border,
                                    size: 24,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // ── Confirm button ───────────────────────────────────────────────
            if (_allDocs.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding + 16),
                child: FilledButton(
                  onPressed: _selected.isEmpty || _isAssigning
                      ? null
                      : _confirmAssign,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: widget.accent,
                    disabledBackgroundColor:
                        widget.accent.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.control,
                    ),
                  ),
                  child: _isAssigning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _selected.isEmpty
                              ? 'Chọn tài liệu để thêm'
                              : 'Thêm ${_selected.length} tài liệu vào notebook',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 56,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Tất cả tài liệu đã có\ntrong notebook này',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload tài liệu mới để thêm vào notebook.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: widget.onUpload,
            icon: const Icon(Icons.upload_file_rounded, size: 16),
            label: const Text('Upload tài liệu mới'),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.accent,
              side: BorderSide(color: widget.accent),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.control,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _NotebookHistorySheet — Bottom sheet lịch sử học của notebook
// =============================================================================
// 2 tab: Flashcard | Luyện thi
// Mỗi tab load session list từ backend (hoặc mock nếu chưa có).
// Tap vào session quiz → navigate đến QuizHistoryScreen để xem chi tiết.

class _NotebookHistorySheet extends StatefulWidget {
  final String notebookId;
  final String notebookName;
  final Color  accent;

  const _NotebookHistorySheet({
    required this.notebookId,
    required this.notebookName,
    required this.accent,
  });

  @override
  State<_NotebookHistorySheet> createState() => _NotebookHistorySheetState();
}

class _NotebookHistorySheetState extends State<_NotebookHistorySheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // ── Flashcard history state ─────────────────────────────────────────────────
  List<FlashCardSession> _flashSessions = [];
  bool    _flashLoading = true;

  // ── Quiz history state ──────────────────────────────────────────────────────
  List<QuizSession> _quizSessions = [];
  bool    _quizLoading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadFlashHistory();
    _loadQuizHistory();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Load flashcard history ──────────────────────────────────────────────────

  Future<void> _loadFlashHistory() async {
    setState(() => _flashLoading = true);
    try {
      if (AppConstants.backendBaseUrl.contains('your-backend') ||
          !AppConstants.backendBaseUrl.contains('onrender.com')) {
        await Future.delayed(const Duration(milliseconds: 600));
        _flashSessions = _mockFlashSessions();
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('Chưa đăng nhập');
        final idToken = await user.getIdToken();
        final res = await http.get(
          Uri.parse('${AppConstants.backendBaseUrl}/flashcards/history/${widget.notebookId}'),
          headers: {'Authorization': 'Bearer $idToken'},
        ).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = json.decode(res.body) as List;
          _flashSessions = data
              .map((e) => FlashCardSession.fromJson(e as Map<String, dynamic>))
              .toList();
        } else {
          _flashSessions = _mockFlashSessions();
        }
      }
    } catch (_) {
      _flashSessions = _mockFlashSessions();
    } finally {
      if (mounted) setState(() => _flashLoading = false);
    }
  }

  Future<void> _loadQuizHistory() async {
    setState(() => _quizLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Chưa đăng nhập');
      final idToken = await user.getIdToken();
      final uri = Uri.parse('${AppConstants.backendBaseUrl}/quiz/history')
          .replace(queryParameters: {
        'notebook_id': widget.notebookId,
        'limit': '20',
      });
      final res = await http
          .get(uri, headers: {'Authorization': 'Bearer $idToken'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        _quizSessions = data
            .map((e) => QuizSession.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _quizSessions = _mockQuizSessions();
      }
    } catch (_) {
      _quizSessions = _mockQuizSessions();
    } finally {
      if (mounted) setState(() => _quizLoading = false);
    }
  }

  // ── Mock data ───────────────────────────────────────────────────────────────

  List<FlashCardSession> _mockFlashSessions() => [
    FlashCardSession(
      id: 'f1', notebookId: widget.notebookId,
      notebookName: widget.notebookName,
      deckTitle: 'Flashcards: ${widget.notebookName}',
      totalCards: 20, masteredCount: 14,
      reviewCount: 4, skippedCount: 2,
      scorePct: 70, isMock: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    FlashCardSession(
      id: 'f2', notebookId: widget.notebookId,
      notebookName: widget.notebookName,
      deckTitle: 'Flashcards: ${widget.notebookName}',
      totalCards: 10, masteredCount: 6,
      reviewCount: 3, skippedCount: 1,
      scorePct: 60, isMock: true,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  List<QuizSession> _mockQuizSessions() => [
    QuizSession(
      id: 'q1', notebookId: widget.notebookId,
      notebookName: widget.notebookName,
      difficulty: 'medium', totalQuestions: 10,
      correctCount: 8, scorePct: 80, isMock: true,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    QuizSession(
      id: 'q2', notebookId: widget.notebookId,
      notebookName: widget.notebookName,
      difficulty: 'hard', totalQuestions: 15,
      correctCount: 9, scorePct: 60, isMock: true,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // ── Handle ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.1),
                    borderRadius: AppRadius.control,
                  ),
                  child: Icon(Icons.history_rounded, color: widget.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lịch sử học',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        widget.notebookName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tab bar ─────────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicatorColor: widget.accent,
              labelColor: widget.accent,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [
                Tab(icon: Icon(Icons.style_rounded, size: 16), text: 'Flashcard'),
                Tab(icon: Icon(Icons.quiz_rounded, size: 16), text: 'Luyện thi'),
              ],
            ),
          ),

          // ── Tab views ───────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // ── Tab 1: Flashcard history ───────────────────────────────
                _flashLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _flashSessions.isEmpty
                        ? _EmptyHistoryTab(
                            icon: Icons.style_rounded,
                            label: 'Chưa có lịch sử Flashcard',
                            hint: 'Hoàn thành bộ thẻ đầu tiên\nđể xem kết quả tại đây.',
                          )
                        : RefreshIndicator(
                            onRefresh: _loadFlashHistory,
                            child: ListView.builder(
                              controller: scrollController,
                              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 16),
                              itemCount: _flashSessions.length,
                              itemBuilder: (_, i) => _FlashSessionCard(
                                session: _flashSessions[i],
                                accent: widget.accent,
                              ),
                            ),
                          ),

                // ── Tab 2: Quiz history ────────────────────────────────────
                _quizLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _quizSessions.isEmpty
                        ? _EmptyHistoryTab(
                            icon: Icons.quiz_rounded,
                            label: 'Chưa có lịch sử Luyện thi',
                            hint: 'Hoàn thành bài kiểm tra đầu tiên\nđể xem kết quả tại đây.',
                          )
                        : RefreshIndicator(
                            onRefresh: _loadQuizHistory,
                            child: ListView.builder(
                              controller: scrollController,
                              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 16),
                              itemCount: _quizSessions.length,
                              itemBuilder: (_, i) => _QuizSessionCard(
                                session: _quizSessions[i],
                                accent: widget.accent,
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push(
                                    '/quiz/history/${widget.notebookId}'
                                    '?name=${Uri.encodeComponent(widget.notebookName)}',
                                  );
                                },
                              ),
                            ),
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Flash Session Card ────────────────────────────────────────────────────────

class _FlashSessionCard extends StatelessWidget {
  final FlashCardSession session;
  final Color accent;
  const _FlashSessionCard({required this.session, required this.accent});

  Color get _scoreColor {
    if (session.scorePct >= 80) return const Color(0xFF4CAF50);
    if (session.scorePct >= 60) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }

  String get _scoreLabel {
    if (session.scorePct >= 80) return 'Xuất sắc';
    if (session.scorePct >= 60) return 'Khá tốt';
    return 'Cần ôn thêm';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.control,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Score circle
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _scoreColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _scoreColor.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Center(
              child: Text(
                '${session.scorePct}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _scoreColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.deckTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _scoreColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _scoreLabel,
                        style: TextStyle(fontSize: 10, color: _scoreColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.totalCards} thẻ · ✓ ${session.masteredCount} thuộc · ↺ ${session.reviewCount} ôn lại',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(session.createdAt),
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quiz Session Card ─────────────────────────────────────────────────────────

class _QuizSessionCard extends StatelessWidget {
  final QuizSession session;
  final Color accent;
  final VoidCallback onTap;
  const _QuizSessionCard({
    required this.session,
    required this.accent,
    required this.onTap,
  });

  Color get _scoreColor {
    if (session.scorePct >= 80) return const Color(0xFF4CAF50);
    if (session.scorePct >= 60) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }

  String get _scoreLabel {
    if (session.scorePct >= 80) return 'Xuất sắc';
    if (session.scorePct >= 60) return 'Khá tốt';
    return 'Cần ôn thêm';
  }

  String get _difficultyLabel {
    switch (session.difficulty) {
      case 'easy':   return 'Dễ';
      case 'hard':   return 'Khó';
      default:       return 'Trung bình';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.control,
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.control,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Score circle
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _scoreColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: _scoreColor.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '${session.scorePct}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _scoreColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.notebookName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _scoreColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _scoreLabel,
                            style: TextStyle(fontSize: 10, color: _scoreColor, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.correctCount}/${session.totalQuestions} câu · $_difficultyLabel',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(session.createdAt),
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty History Tab ─────────────────────────────────────────────────────────

class _EmptyHistoryTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  const _EmptyHistoryTab({
    required this.icon,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.textTertiary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
