import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../shared/widgets/widgets.dart';
import 'providers/notebook_provider.dart';
import '../chat/providers/chat_provider.dart';

// =============================================================================
// NOTEBOOKS SCREEN — TDMU SmartDoc redesign
// Màu chủ đạo: TDMU Blue #1565C0
// Card: gradient header (accent) + body trắng, footer badge AI + gợi ý
// AppBar: trắng, brand icon gradient, nút "Tạo mới" pill xanh
// =============================================================================

// ── Icon palette ──────────────────────────────────────────────────────────────

const _nbIcons = <(String, IconData, String)>[
  ('school',    Icons.school_rounded,             'Tổng quát'),
  ('book',      Icons.menu_book_rounded,           'Văn học'),
  ('science',   Icons.science_rounded,             'Khoa học'),
  ('math',      Icons.calculate_rounded,           'Toán'),
  ('economics', Icons.trending_up_rounded,         'Kinh tế'),
  ('computer',  Icons.computer_rounded,            'Công nghệ'),
  ('medical',   Icons.medical_services_rounded,    'Y tế'),
  ('history',   Icons.history_edu_rounded,         'Lịch sử'),
  ('art',       Icons.palette_rounded,             'Nghệ thuật'),
  ('language',  Icons.translate_rounded,           'Ngoại ngữ'),
  ('law',       Icons.gavel_rounded,               'Pháp luật'),
  ('idea',      Icons.lightbulb_rounded,           'Ý tưởng'),
];

IconData _iconFromKey(String key) =>
    _nbIcons.firstWhere((e) => e.$1 == key, orElse: () => _nbIcons.first).$2;

Color _parseColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return const Color(0xFF1565C0);
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class NotebooksScreen extends StatefulWidget {
  const NotebooksScreen({super.key});

  @override
  State<NotebooksScreen> createState() => _NotebooksScreenState();
}

class _NotebooksScreenState extends State<NotebooksScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotebookProvider>().loadNotebooks();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _confirmDeleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: const Text('Xoá nhiều notebook?'),
        content: Text(
          'Bạn có chắc muốn xoá ${_selectedIds.length} notebook đã chọn?',
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
      final provider = context.read<NotebookProvider>();
      final success = await provider.deleteNotebooks(_selectedIds.toList());
      if (mounted && success) {
        _clearSelection();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Xóa thất bại'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
          ),
        );
      }
    }
  }

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    String selectedColor = '#1565C0'; // TDMU Blue mặc định
    String selectedIcon = 'school';
    const colors = [
      '#1565C0', '#006874', '#7D5260',
      '#B1416B', '#386A20', '#984716',
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        void submit() async {
          final name = nameController.text.trim();
          if (name.isEmpty) return;
          final provider = context.read<NotebookProvider>();
          final messenger = ScaffoldMessenger.of(context);
          Navigator.of(ctx).pop();
          final nb = await provider.createNotebook(
              name, selectedColor, selectedIcon);
          if (nb == null && context.mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: const Text('Tạo notebook thất bại'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape:
                    RoundedRectangleBorder(borderRadius: AppRadius.control),
                margin: const EdgeInsets.all(AppSpacing.md),
              ),
            );
          }
        }

        return StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding:
                const EdgeInsets.fromLTRB(20, 16, 20, 0),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.create_new_folder_rounded,
                      size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Tạo notebook mới',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  // ── Tên notebook ────────────────────────────────────
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      hintText: 'Tên notebook...',
                      prefixIcon: const Icon(
                        Icons.drive_file_rename_outline_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      border: OutlineInputBorder(
                          borderRadius: AppRadius.control),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.control,
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.control,
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      contentPadding: AppSpacing.inputPadding,
                    ),
                  ),
                  AppSpacing.vMd,

                  // ── Màu sắc ─────────────────────────────────────────
                  Text(
                    'Màu sắc',
                    style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  AppSpacing.vSm,
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: colors.map((hex) {
                      final color = _parseColor(hex);
                      final selected = hex == selectedColor;
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedColor = hex),
                        child: AnimatedContainer(
                          duration: AppMotion.fast,
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? AppColors.textPrimary
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color:
                                          color.withValues(alpha: 0.45),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  AppSpacing.vMd,

                  // ── Biểu tượng ──────────────────────────────────────
                  Text(
                    'Biểu tượng',
                    style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  AppSpacing.vSm,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _nbIcons.map((entry) {
                      final selected = entry.$1 == selectedIcon;
                      final accent = _parseColor(selectedColor);
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedIcon = entry.$1),
                        child: Tooltip(
                          message: entry.$3,
                          child: AnimatedContainer(
                            duration: AppMotion.fast,
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: selected
                                  ? accent
                                  : AppColors.surfaceVariant,
                              borderRadius: AppRadius.control,
                              border: Border.all(
                                color: selected ? accent : AppColors.border,
                                width: 1.5,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.30),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              entry.$2,
                              size: 22,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.control),
                ),
                child: const Text(
                  'Tạo notebook',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
    });
  }

  Future<void> _confirmDelete(Notebook nb) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: const Text('Xoá notebook?'),
        content: Text(
          'Notebook "${nb.name}" sẽ bị xoá. Các tài liệu bên trong vẫn được giữ lại.',
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
    if (confirmed == true && mounted) {
      await context.read<NotebookProvider>().deleteNotebook(nb.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotebookProvider>();
    final pagePadding = AppBreakpoints.pagePadding(context);
    final nbCount = provider.notebooks.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FE),

      // ── AppBar ────────────────────────────────────────────────────────────
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              ),
              title: Text(
                '${_selectedIds.length} đã chọn',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              actions: [
                TextButton(
                  onPressed:
                      _selectedIds.isEmpty ? null : _confirmDeleteSelected,
                  child: Text(
                    'Xoá',
                    style: TextStyle(
                      color: _selectedIds.isEmpty
                          ? AppColors.textTertiary
                          : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: AppColors.border),
              ),
            )
          : AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleSpacing: 16,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brand icon gradient
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_stories_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Notebooks',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (nbCount > 0)
                        Text(
                          '$nbCount notebook',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: FilledButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text(
                      'Tạo mới',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: AppColors.border),
              ),
            ),

      // ── Body ─────────────────────────────────────────────────────────────
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => provider.refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (provider.isLoading)
                _buildSkeletonGrid(pagePadding)
              else if (provider.notebooks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyNotebooks(onCreate: _showCreateDialog),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    pagePadding.left,
                    16,
                    pagePadding.right,
                    AppSpacing.xxl * 2,
                  ),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final cols = AppBreakpoints.documentGridColumns(
                          constraints.crossAxisExtent);
                      return SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.88,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final nb = provider.notebooks[index];
                            final isSelected =
                                _selectedIds.contains(nb.id);
                            return _NotebookCard(
                              notebook: nb,
                              index: index,
                              isSelectionMode: _isSelectionMode,
                              isSelected: isSelected,
                              onTap: _isSelectionMode
                                  ? () => _toggleSelection(nb.id)
                                  : () => context
                                      .push('/notebook/${nb.id}'),
                              onLongPress: () =>
                                  _toggleSelection(nb.id),
                              onDelete: () => _confirmDelete(nb),
                              onChat: () {
                                if (!context.mounted) return;
                                try {
                                  context
                                      .read<ChatProvider>()
                                      .setActiveNotebook(nb.id,
                                          notebookName: nb.name);
                                } catch (_) {}
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (context.mounted) {
                                    context.go('/chat');
                                  }
                                });
                              },
                            );
                          },
                          childCount: provider.notebooks.length,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  SliverPadding _buildSkeletonGrid(EdgeInsets pagePadding) {
    return SliverPadding(
      padding:
          EdgeInsets.fromLTRB(pagePadding.left, 16, pagePadding.right, 0),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final cols = AppBreakpoints.documentGridColumns(
              constraints.crossAxisExtent);
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.88,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => const DocumentCardSkeleton()
                  .appEntrance(delay: AppMotion.stagger(index)),
              childCount: 4,
            ),
          );
        },
      ),
    );
  }
}

// ── Notebook Card ─────────────────────────────────────────────────────────────

class _NotebookCard extends StatelessWidget {
  final Notebook notebook;
  final int index;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onDelete;
  final VoidCallback onChat;

  const _NotebookCard({
    required this.notebook,
    required this.index,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    required this.onDelete,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final nbColor = notebook.flutterColor;
    final hasSummary = notebook.summary.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: isSelected ? nbColor : AppColors.border,
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? nbColor.withValues(alpha: 0.20)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: isSelected ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          AppRadius.card.topLeft.x - (isSelected ? 1.0 : 0),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Gradient header ──────────────────────────────────
                Container(
                  height: 82,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        nbColor,
                        Color.lerp(nbColor, Colors.black, 0.20)!,
                      ],
                    ),
                  ),
                  padding:
                      const EdgeInsets.fromLTRB(12, 12, 10, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon badge
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded,
                                size: 20, color: Colors.white)
                            : Icon(
                                _iconFromKey(notebook.icon),
                                size: 20,
                                color: Colors.white,
                              ),
                      ),
                      const Spacer(),
                      // Selection toggle / options
                      if (isSelectionMode)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 22,
                            color: isSelected
                                ? Colors.white
                                : Colors.white
                                    .withValues(alpha: 0.55),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () => _showOptions(context),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.more_vert_rounded,
                              size: 20,
                              color: Colors.white
                                  .withValues(alpha: 0.80),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Body ─────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Notebook name
                        Text(
                          notebook.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                            height: 1.25,
                          ),
                        ),

                        // AI summary snippet
                        if (hasSummary) ...[
                          const SizedBox(height: 5),
                          Expanded(
                            child: Text(
                              notebook.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ] else
                          const Spacer(),

                        // Footer: AI badge + suggestion count
                        Row(
                          children: [
                            if (hasSummary) ...[
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: nbColor
                                      .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome,
                                        size: 9, color: nbColor),
                                    const SizedBox(width: 3),
                                    Text(
                                      'AI',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: nbColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (notebook.suggestions.isNotEmpty) ...[
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 11,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${notebook.suggestions.length} gợi ý',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).appEntrance(delay: AppMotion.stagger(index));
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Notebook identity row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          notebook.flutterColor,
                          Color.lerp(
                              notebook.flutterColor, Colors.black, 0.2)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _iconFromKey(notebook.icon),
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      notebook.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Chat option
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.chat_bubble_rounded,
                    color: AppColors.primary, size: 18),
              ),
              title: const Text(
                'Chat với notebook',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text('Hỏi đáp AI về toàn bộ tài liệu'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.textTertiary),
              onTap: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => onChat());
              },
            ),

            // Delete option
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_outline_rounded,
                    color: AppColors.error, size: 18),
              ),
              title: Text(
                'Xoá notebook',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.error),
              ),
              subtitle: const Text('Tài liệu bên trong vẫn được giữ lại'),
              onTap: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => onDelete());
              },
            ),
            AppSpacing.vMd,
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyNotebooks extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyNotebooks({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hero icon with gradient
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.30),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                size: 44,
                color: Colors.white,
              ),
            ).appScaleIn(),
            AppSpacing.vLg,
            Text(
              'Chưa có notebook nào',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A2E),
              ),
            ).appEntrance(delay: const Duration(milliseconds: 100)),
            AppSpacing.vSm,
            Text(
              'Tạo notebook để nhóm tài liệu theo chủ đề\nvà nhận tóm tắt thông minh từ AI.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.65,
              ),
            ).appEntrance(delay: const Duration(milliseconds: 160)),
            AppSpacing.vXl,
            // Pill button
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Tạo notebook đầu tiên',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ).appEntrance(delay: const Duration(milliseconds: 220)),
          ],
        ),
      ),
    );
  }
}
