import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants.dart';
import '../../../shared/widgets/widgets.dart';
import '../../notebooks/providers/notebook_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../providers/notebook_documents_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _docsProvider = NotebookDocumentsProvider(notebookId: widget.notebookId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _docsProvider.loadDocuments();
      _startPollingIfNeeded();
    });
  }

  void _startPollingIfNeeded() {
    final nbs = context.read<NotebookProvider>().notebooks;
    final idx = nbs.indexWhere((n) => n.id == widget.notebookId);
    if (idx < 0 || nbs[idx].summary.isNotEmpty) return;

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) {
        _pollTimer?.cancel();
        return;
      }
      await context.read<NotebookProvider>().refresh();
      if (!mounted) return;
      final updated = context.read<NotebookProvider>().notebooks;
      final updatedIdx = updated.indexWhere((n) => n.id == widget.notebookId);
      if (updatedIdx >= 0 && updated[updatedIdx].summary.isNotEmpty) {
        _pollTimer?.cancel();
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
    // Dùng route riêng ngoài ShellRoute để tránh duplicate GlobalKey crash
    context.push('/notebook/${widget.notebookId}/upload');
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
        onAssigned: () => _docsProvider.refresh(),
      ),
    );
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
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.pop(),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: AppRadius.control,
                      ),
                      child: Icon(_iconForKey(nb.icon), size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nb.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
        // ── Bottom action bar: Chat với AI + Luyện thi ────────────────────────
        // ── Bottom action bar: Chat AI | Flashcard | Luyện thi ─────────────────
        // 3 nút bằng nhau (flex: 1). Padding bottom dùng MediaQuery tránh gesture bar.
        bottomNavigationBar: _isSelectionMode
            ? null
            : Container(
                color: AppColors.surface,
                padding: EdgeInsets.fromLTRB(
                  12,
                  10,
                  12,
                  MediaQuery.of(context).padding.bottom + 10,
                ),
                child: Row(
                  children: [
                    // ── Chat với AI ──────────────────────────────────────────
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _onChatTap,
                        icon: const Icon(Icons.chat_bubble_rounded, size: 15),
                        label: const Text(
                          'Chat AI',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.control,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ── Flashcard ────────────────────────────────────────────
                    Expanded(
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
                          side: BorderSide(color: accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.control,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ── Luyện thi ────────────────────────────────────────────
                    Expanded(
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
                          side: BorderSide(color: accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.control,
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
              // ── Summary Section ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  color: accent.withValues(alpha: 0.06),
                  child: Padding(
                    padding: pagePadding.copyWith(
                      top: AppSpacing.lg,
                      bottom: AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (nb.summary.isNotEmpty) ...[
                          Row(
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
                                        color: accent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      nb.summary,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppColors.textSecondary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ).appEntrance(),
                        ] else ...[
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 40,
                                  color: accent.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Chua co tom tat AI',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ).appEntrance(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ── Suggestion Chips ────────────────────────────────────────────
              if (nb.suggestions.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: pagePadding.copyWith(
                      top: AppSpacing.lg,
                      bottom: AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hỏi AI',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: nb.suggestions.take(4).map((s) {
                            return ActionChip(
                              avatar: Icon(Icons.chat_bubble_outline_rounded,
                                  size: 14, color: accent),
                              label: Text(
                                s,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: accent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              backgroundColor: accent.withValues(alpha: 0.06),
                              side: BorderSide(
                                color: accent.withValues(alpha: 0.2),
                                width: 1,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              onPressed: () => _onSuggestionTap(s),
                            );
                          }).toList(),
                        ).appEntrance(delay: const Duration(milliseconds: 100)),
                      ],
                    ),
                  ),
                ),

              // ── Documents Header ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: pagePadding.left,
                    right: pagePadding.right,
                    top: AppSpacing.md,
                    bottom: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tài liệu',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!_isSelectionMode)
                        TextButton.icon(
                          onPressed: _showAddSheet,
                          icon: Icon(Icons.add, size: 16, color: accent),
                          label: Text('Thêm', style: TextStyle(color: accent)),
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
        color: isSelected ? accent.withValues(alpha: 0.05) : AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: isSelected ? accent : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: AppShadows.card,
      ),
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
        subtitle: Text(
          isPdf ? '${doc.pageCount} trang - PDF' : 'Tai lieu',
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
            : IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                color: AppColors.textSecondary,
                onPressed: () {
                  // TODO: Open document viewer
                },
              ),
      ),
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
