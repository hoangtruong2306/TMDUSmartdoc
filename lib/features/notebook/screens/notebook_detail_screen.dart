import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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

  void _showUploadSheet() {
    context.push('/upload', extra: {'notebook_id': widget.notebookId});
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
                title: Text('${_selectedDocIds.length} da chon'),
                actions: [
                  TextButton(
                    onPressed: _selectedDocIds.isEmpty ? null : _confirmDeleteSelectedDocs,
                    child: Text(
                      'Xoa',
                      style: TextStyle(
                        color: _selectedDocIds.isEmpty
                            ? AppColors.textTertiary
                            : AppColors.error,
                        fontWeight: FontWeight.w600,
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
        // Dùng bottomNavigationBar thay FAB để có đủ chỗ cho 2 nút
        // Chỉ hiển thị khi không ở chế độ selection
        bottomNavigationBar: _isSelectionMode
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      // Nút Chat với AI (primary — chiếm nhiều không gian hơn)
                      Expanded(
                        flex: 3,
                        child: FilledButton.icon(
                          onPressed: _onChatTap,
                          icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                          label: const Text(
                            'Chat với AI',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.control,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Nút Luyện thi (outlined — phụ)
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(
                            '/quiz/${widget.notebookId}'
                            '?name=${Uri.encodeComponent(nb.name)}',
                          ),
                          icon: Icon(Icons.quiz_rounded, size: 18, color: accent),
                          label: Text(
                            'Luyện thi',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: accent,
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
              ),
        body: SafeArea(
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
                                      'Tom tat AI',
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
                          'Hoi AI',
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
                        'Tai lieu',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!_isSelectionMode)
                        TextButton.icon(
                          onPressed: _showUploadSheet,
                          icon: Icon(Icons.add, size: 16, color: accent),
                          label: Text('Them', style: TextStyle(color: accent)),
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
                        onUpload: _showUploadSheet,
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
              'Chua co tai lieu',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ).appEntrance(delay: const Duration(milliseconds: 100)),
            AppSpacing.vSm,
            Text(
              'Tai len tai lieu PDF de nh vao notebook nay\nva nhan tom tat thong minh tu AI.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ).appEntrance(delay: const Duration(milliseconds: 160)),
            AppSpacing.vXl,
            CustomButton(
              label: 'Tai tai lieu len',
              onPressed: onUpload,
              icon: Icons.upload_file_rounded,
            ).appEntrance(delay: const Duration(milliseconds: 220)),
          ],
        ),
      ),
    );
  }
}
