import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../shared/widgets/widgets.dart';
import '../../features/chat/providers/chat_provider.dart';
import 'providers/document_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  // ── Selection state ──────────────────────────────────────────────────────────
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  // Animation controller cho selection AppBar (fade/scale)
  late final AnimationController _selectionBarAnim;

  @override
  void initState() {
    super.initState();
    _selectionBarAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DocumentProvider>().loadDocuments();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _selectionBarAnim.dispose();
    super.dispose();
  }

  // ── Selection helpers ─────────────────────────────────────────────────────────

  void _enterSelectionMode(String firstId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(firstId);
    });
    _selectionBarAnim.forward();
  }

  void _exitSelectionMode() {
    _selectionBarAnim.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isSelectionMode = false;
          _selectedIds.clear();
        });
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _exitSelectionMode();
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<Document> allDocs) {
    setState(() {
      _selectedIds.addAll(allDocs.map((d) => d.id));
    });
  }

  void _deselectAll() {
    setState(() => _selectedIds.clear());
    _exitSelectionMode();
  }

  bool _allSelected(List<Document> allDocs) =>
      allDocs.every((d) => _selectedIds.contains(d.id));

  // ── Delete action ─────────────────────────────────────────────────────────────

  Future<void> _confirmDeleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: const Text('Xoá tài liệu?'),
        content: Text(
          count == 1
              ? 'Xóa tài liệu đã chọn?\nHành động này không thể hoàn tác.'
              : 'Xóa $count tài liệu đã chọn?\nHành động này không thể hoàn tác.',
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

    if (!mounted || confirmed != true) return;

    final idsToDelete = _selectedIds.toList();
    _exitSelectionMode();

    final ok = await context
        .read<DocumentProvider>()
        .deleteDocuments(idsToDelete);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Đã xoá $count tài liệu'
            : 'Xoá thất bại, vui lòng thử lại'),
        backgroundColor: ok ? null : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docProvider  = context.watch<DocumentProvider>();
    final grouped      = docProvider.groupedDocuments;
    final allDocs      = docProvider.documents;
    final pagePadding  = AppBreakpoints.pagePadding(context);
    final groupKeys    = grouped.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.background,

      // ── Selection AppBar (slide-in khi chọn) ────────────────────────────────
      appBar: _isSelectionMode
          ? _buildSelectionAppBar(allDocs, pagePadding)
          : null,

      // ── FAB ─────────────────────────────────────────────────────────────────
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go('/upload'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text(
                'Tải lên',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ).appScaleIn(delay: const Duration(milliseconds: 320)),

      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: docProvider.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header (ẩn khi đang selection mode) ───────────────────────
              if (!_isSelectionMode)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: pagePadding.copyWith(bottom: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tài liệu',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  AppSpacing.vXs,
                                  Text(
                                    'Quản lý và học cùng tài liệu của bạn.',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            AppSpacing.hMd,
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.surface,
                              child: Icon(Icons.person_outline,
                                  color: AppColors.primary),
                            ),
                          ],
                        ).appEntrance(),

                        AppSpacing.vLg,

                        // Search bar
                        Container(
                          decoration:
                              BoxDecoration(boxShadow: AppShadows.soft),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => context
                                .read<DocumentProvider>()
                                .setSearchQuery(val),
                            decoration: InputDecoration(
                              hintText: 'Tìm kiếm tài liệu...',
                              prefixIcon: const Icon(Icons.search,
                                  color: AppColors.textSecondary),
                              suffixIcon: docProvider.searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        _searchController.clear();
                                        context
                                            .read<DocumentProvider>()
                                            .setSearchQuery('');
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                  borderRadius: AppRadius.control,
                                  borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: AppRadius.control,
                                  borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: AppRadius.control,
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 1.5),
                              ),
                              filled: true,
                              fillColor: AppColors.surfaceElevated,
                              contentPadding: AppSpacing.inputPadding,
                            ),
                          ),
                        ).appEntrance(delay: const Duration(milliseconds: 80)),

                        AppSpacing.vMd,
                      ],
                    ),
                  ),
                ),

              // ── Stats strip ─────────────────────────────────────────────────
              if (!docProvider.isLoading && !_isSelectionMode)
                SliverToBoxAdapter(
                  child: _StatsStrip(
                    docCount: allDocs.length,
                    pageCount: docProvider.totalPageCount,
                    studiedCount: docProvider.studiedCount,
                    padding: pagePadding,
                  ).appEntrance(delay: const Duration(milliseconds: 160)),
                ),

              // ── Loading skeleton ────────────────────────────────────────────
              if (docProvider.isLoading)
                SliverPadding(
                  padding: pagePadding.copyWith(top: AppSpacing.sm),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.md),
                        child: _DocTileSkeleton(),
                      ),
                      childCount: 5,
                    ),
                  ),
                )

              // ── Empty state ──────────────────────────────────────────────────
              else if (grouped.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    type: EmptyStateType.noDocuments,
                    onAction: () => context.go('/upload'),
                  ),
                )

              // ── Date-grouped list ────────────────────────────────────────────
              else
                for (int gi = 0; gi < groupKeys.length; gi++) ...[
                  SliverToBoxAdapter(
                    child: _DateSectionHeader(
                      label: groupKeys[gi],
                      padding: pagePadding,
                      isFirst: gi == 0 && !_isSelectionMode,
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                        horizontal: pagePadding.left),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) {
                          final docs = grouped[groupKeys[gi]]!;
                          final doc  = docs[index];
                          final isSelected = _selectedIds.contains(doc.id);

                          return _DocumentListTile(
                            doc:             doc,
                            studyCount:      docProvider.studyCountOf(doc.id),
                            isSelectionMode: _isSelectionMode,
                            isSelected:      isSelected,
                            onTap: _isSelectionMode
                                ? () => _toggleSelection(doc.id)
                                : () {
                                    context
                                        .read<DocumentProvider>()
                                        .incrementStudyCount(doc.id);
                                    context.read<ChatProvider>().setActiveDoc(
                                          doc.id,
                                          docTitle: doc.title,
                                        );
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (context.mounted) context.go('/chat');
                                    });
                                  },
                            onLongPress: _isSelectionMode
                                ? () => _toggleSelection(doc.id)
                                : () => _enterSelectionMode(doc.id),
                          );
                        },
                        childCount: grouped[groupKeys[gi]]!.length,
                      ),
                    ),
                  ),
                ],

              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Selection AppBar ─────────────────────────────────────────────────────────

  PreferredSizeWidget _buildSelectionAppBar(
      List<Document> allDocs, EdgeInsets padding) {
    final isAllSelected = _allSelected(allDocs);
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      shadowColor: AppColors.primary.withValues(alpha: 0.4),
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Thoát chọn',
        onPressed: _exitSelectionMode,
      ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        child: Text(
          _selectedIds.isEmpty
              ? 'Chọn tài liệu'
              : 'Đã chọn ${_selectedIds.length}',
          key: ValueKey(_selectedIds.length),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      actions: [
        // Chọn tất cả / Bỏ tất cả
        TextButton.icon(
          onPressed: () => isAllSelected
              ? _deselectAll()
              : _selectAll(allDocs),
          icon: Icon(
            isAllSelected
                ? Icons.deselect_rounded
                : Icons.select_all_rounded,
            size: 18,
            color: Colors.white,
          ),
          label: Text(
            isAllSelected ? 'Bỏ hết' : 'Tất cả',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        // Nút Xóa
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: IconButton(
            onPressed: _selectedIds.isEmpty ? null : _confirmDeleteSelected,
            tooltip: 'Xóa đã chọn',
            icon: Icon(
              Icons.delete_outline_rounded,
              color: _selectedIds.isEmpty
                  ? Colors.white54
                  : Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stats Strip ───────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  final int docCount;
  final int pageCount;
  final int studiedCount;
  final EdgeInsets padding;

  const _StatsStrip({
    required this.docCount,
    required this.pageCount,
    required this.studiedCount,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding.copyWith(top: 0, bottom: AppSpacing.sm),
      child: Row(
        children: [
          _StatChip(icon: Icons.description_outlined,
              value: '$docCount', label: 'tài liệu',
              color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          _StatChip(icon: Icons.auto_stories_outlined,
              value: '$pageCount', label: 'trang',
              color: const Color(0xFF7B61FF)),
          const SizedBox(width: AppSpacing.sm),
          _StatChip(icon: Icons.school_outlined,
              value: '$studiedCount', label: 'đã học',
              color: const Color(0xFF00897B)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.control,
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(children: [
                  TextSpan(
                    text: '$value ',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: color, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color.withValues(alpha: 0.8)),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date Section Header ───────────────────────────────────────────────────────

class _DateSectionHeader extends StatelessWidget {
  final String label;
  final EdgeInsets padding;
  final bool isFirst;

  const _DateSectionHeader({
    required this.label,
    required this.padding,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: padding.left,
        right: padding.right,
        top: isFirst ? AppSpacing.md : AppSpacing.lg,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Divider(color: AppColors.border, height: 1)),
        ],
      ),
    );
  }
}

// ── Document List Tile ────────────────────────────────────────────────────────

class _DocumentListTile extends StatelessWidget {
  final Document doc;
  final int studyCount;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _DocumentListTile({
    required this.doc,
    required this.studyCount,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isPdf     = doc.type.toLowerCase() == 'pdf';
    final iconColor = isPdf ? AppColors.documentPdf : AppColors.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.05)
            : AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected ? [] : AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.card,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: AppRadius.card,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Leading: checkbox (selection) atau file icon (normal) ──────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                  child: isSelectionMode
                      // Checkbox
                      ? Container(
                          key: const ValueKey('checkbox'),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.background,
                            borderRadius: AppRadius.control,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 22)
                              : null,
                        )
                      // File icon
                      : Container(
                          key: const ValueKey('icon'),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            borderRadius: AppRadius.control,
                          ),
                          child: Icon(
                            isPdf
                                ? Icons.picture_as_pdf_rounded
                                : Icons.description_rounded,
                            color: iconColor,
                            size: 22,
                          ),
                        ),
                ),

                const SizedBox(width: AppSpacing.md),

                // ── Content ────────────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              color: isSelected
                                  ? AppColors.primary
                                  : null,
                            ),
                      ),

                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Icon(Icons.auto_stories_outlined,
                              size: 13, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            '${doc.pageCount} trang',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textTertiary),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('·',
                                style: TextStyle(
                                    color: AppColors.textTertiary)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              doc.typeLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: iconColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Badges (ẩn khi selection mode để gọn)
                      if (!isSelectionMode) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _StatusBadge(status: doc.status),
                            const SizedBox(width: AppSpacing.sm),
                            _StudyCountBadge(count: studyCount),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: AppSpacing.xs),

                // ── Trailing ──────────────────────────────────────────────────
                if (!isSelectionMode)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        doc.shortTime,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _showDocOptions(context),
                        child: Icon(Icons.more_vert,
                            size: 18, color: AppColors.textSecondary),
                      ),
                    ],
                  )
                else
                  // Trong selection mode: chỉ hiện thời gian, gọn hơn
                  Text(
                    doc.shortTime,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDocOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Doc info header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: AppRadius.control,
                    ),
                    child: const Icon(Icons.description_rounded,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          '${doc.pageCount} trang · ${doc.typeLabel}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary),
              title: const Text('Chat với AI'),
              onTap: () {
                Navigator.pop(context);
                onTap();
              },
            ),
            ListTile(
              leading: Icon(Icons.quiz_outlined,
                  color: Colors.orange.shade700),
              title: const Text('Luyện thi'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.style_outlined,
                  color: Colors.purple.shade600),
              title: const Text('Flashcard'),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error),
              title: const Text('Xoá tài liệu',
                  style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(context);
                // Gọi single-item delete qua provider
                final ctx = context;
                if (!ctx.mounted) return;
                final ok = await ctx
                    .read<DocumentProvider>()
                    .deleteDocuments([doc.id]);
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text(ok ? 'Đã xoá tài liệu' : 'Xoá thất bại'),
                  backgroundColor: ok ? null : AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'processing':
        return _badge(
          icon: Icons.sync_rounded,
          label: 'Đang xử lý',
          bgColor: Colors.amber.shade50,
          fgColor: Colors.amber.shade800,
          border: Colors.amber.shade200,
          spin: true,
        );
      case 'failed':
        return _badge(
          icon: Icons.error_outline_rounded,
          label: 'Thất bại',
          bgColor: AppColors.error.withValues(alpha: 0.08),
          fgColor: AppColors.error,
          border: AppColors.error.withValues(alpha: 0.3),
        );
      default:
        return _badge(
          icon: Icons.check_circle_outline_rounded,
          label: 'Sẵn sàng',
          bgColor: Colors.green.shade50,
          fgColor: Colors.green.shade700,
          border: Colors.green.shade200,
        );
    }
  }

  Widget _badge({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color fgColor,
    required Color border,
    bool spin = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          spin
              ? SizedBox(
                  width: 10, height: 10,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: fgColor))
              : Icon(icon, size: 11, color: fgColor),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fgColor)),
        ],
      ),
    );
  }
}

// ── Study Count Badge ─────────────────────────────────────────────────────────

class _StudyCountBadge extends StatelessWidget {
  final int count;
  const _StudyCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final has = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: has
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: has
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.border,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            has ? Icons.school_rounded : Icons.school_outlined,
            size: 11,
            color: has ? AppColors.primary : AppColors.textTertiary,
          ),
          const SizedBox(width: 4),
          Text(
            has ? 'Đã học $count lần' : 'Chưa học',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: has ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Document Tile Skeleton ────────────────────────────────────────────────────

class _DocTileSkeleton extends StatelessWidget {
  const _DocTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skel(44, 44, radius: 10),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skel(double.infinity, 14),
                const SizedBox(height: 6),
                _skel(120, 12),
                const SizedBox(height: 8),
                Row(children: [
                  _skel(72, 20, radius: 6),
                  const SizedBox(width: 8),
                  _skel(80, 20, radius: 6),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skel(double w, double h, {double radius = 6}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}
