import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../shared/widgets/widgets.dart';
import 'providers/notebook_provider.dart';
import '../chat/providers/chat_provider.dart';

// Danh sách icon đại diện cho từng lĩnh vực học thuật
const _nbIcons = <(String, IconData, String)>[
  ('school',     Icons.school_rounded,             'Tổng quát'),
  ('book',       Icons.menu_book_rounded,           'Văn học'),
  ('science',    Icons.science_rounded,             'Khoa học'),
  ('math',       Icons.calculate_rounded,           'Toán'),
  ('economics',  Icons.trending_up_rounded,         'Kinh tế'),
  ('computer',   Icons.computer_rounded,            'Công nghệ'),
  ('medical',    Icons.medical_services_rounded,    'Y tế'),
  ('history',    Icons.history_edu_rounded,         'Lịch sử'),
  ('art',        Icons.palette_rounded,             'Nghệ thuật'),
  ('language',   Icons.translate_rounded,           'Ngoại ngữ'),
  ('law',        Icons.gavel_rounded,               'Pháp luật'),
  ('idea',       Icons.lightbulb_rounded,           'Ý tưởng'),
];

IconData _iconFromKey(String key) =>
    _nbIcons.firstWhere((e) => e.$1 == key, orElse: () => _nbIcons.first).$2;

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
    String selectedColor = '#6750A4';
    String selectedIcon = 'school';
    const colors = [
      '#6750A4', '#006874', '#7D5260', '#B1416B',
      '#386A20', '#984716',
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
          final nb = await provider.createNotebook(name, selectedColor, selectedIcon);
          if (nb == null && context.mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: const Text('Tạo notebook thất bại'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
                margin: const EdgeInsets.all(AppSpacing.md),
              ),
            );
          }
        }

        return StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
            title: const Text('Tạo notebook mới'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      hintText: 'Tên notebook...',
                      border: OutlineInputBorder(borderRadius: AppRadius.control),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.control,
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.control,
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      contentPadding: AppSpacing.inputPadding,
                    ),
                  ),
                  AppSpacing.vMd,
                  Text('Màu sắc', style: Theme.of(ctx).textTheme.labelMedium),
                  AppSpacing.vSm,
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: colors.map((hex) {
                      final color = _parseColor(hex);
                      final selected = hex == selectedColor;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedColor = hex),
                        child: AnimatedContainer(
                          duration: AppMotion.fast,
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? AppColors.textPrimary : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: selected ? AppShadows.card : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  AppSpacing.vMd,
                  Text('Biểu tượng', style: Theme.of(ctx).textTheme.labelMedium),
                  AppSpacing.vSm,
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _nbIcons.map((entry) {
                      final selected = entry.$1 == selectedIcon;
                      final accent = _parseColor(selectedColor);
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedIcon = entry.$1),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: AppMotion.fast,
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: selected ? accent : AppColors.surfaceVariant,
                                borderRadius: AppRadius.control,
                                border: Border.all(
                                  color: selected ? accent : AppColors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                entry.$2,
                                size: 20,
                                color: selected ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              entry.$3,
                              style: TextStyle(
                                fontSize: 9,
                                color: selected ? accent : AppColors.textTertiary,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
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
                child: const Text('Tạo'),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              ),
              title: Text('${_selectedIds.length} đã chọn'),
              actions: [
                TextButton(
                  onPressed: _selectedIds.isEmpty ? null : _confirmDeleteSelected,
                  child: Text(
                    'Xoá',
                    style: TextStyle(
                      color: _selectedIds.isEmpty ? AppColors.textTertiary : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          : null,
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _showCreateDialog,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Tạo mới', style: TextStyle(fontWeight: FontWeight.w600)),
            ).appScaleIn(delay: const Duration(milliseconds: 300)),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => provider.refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: pagePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notebooks',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ).appEntrance(),
                      AppSpacing.vXs,
                      Text(
                        'Gom nhóm tài liệu và nhận tóm tắt từ AI.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ).appEntrance(delay: const Duration(milliseconds: 60)),
                      AppSpacing.vLg,
                    ],
                  ),
                ),
              ),
              if (provider.isLoading)
                _buildSkeletonGrid(pagePadding)
              else if (provider.notebooks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyNotebooks(onCreate: _showCreateDialog),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: pagePadding.horizontal / 2,
                  ).copyWith(bottom: AppSpacing.xxl * 2),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final cols = AppBreakpoints.documentGridColumns(
                        constraints.crossAxisExtent,
                      );
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: AppSpacing.md,
                          crossAxisSpacing: AppSpacing.md,
                          childAspectRatio: 1.05,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final nb = provider.notebooks[index];
                            final isSelected = _selectedIds.contains(nb.id);
                            return _NotebookCard(
                              notebook: nb,
                              index: index,
                              isSelectionMode: _isSelectionMode,
                              isSelected: isSelected,
                              onTap: _isSelectionMode
                                  ? () => _toggleSelection(nb.id)
                                  : () => context.push('/notebook/${nb.id}'),
                              onLongPress: () => _toggleSelection(nb.id),
                              onDelete: () => _confirmDelete(nb),
                              onChat: () {
                                if (!context.mounted) return;
                                try {
                                  context.read<ChatProvider>().setActiveNotebook(
                                    nb.id,
                                    notebookName: nb.name,
                                  );
                                } catch (_) {}
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (context.mounted) context.go('/chat');
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
      padding: EdgeInsets.symmetric(horizontal: pagePadding.horizontal / 2),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final cols = AppBreakpoints.documentGridColumns(constraints.crossAxisExtent);
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.05,
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

Color _parseColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return const Color(0xFF6750A4);
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
        color: isSelected ? nbColor.withValues(alpha: 0.08) : AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: isSelected ? nbColor : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.card,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: AppRadius.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colored header strip
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: nbColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: AppSpacing.cardPaddingCompact,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? nbColor.withValues(alpha: 0.2)
                                  : nbColor.withValues(alpha: 0.12),
                              borderRadius: AppRadius.control,
                            ),
                            child: isSelected
                                ? Icon(Icons.check, size: 18, color: nbColor)
                                : Icon(
                                    _iconFromKey(notebook.icon),
                                    size: 18,
                                    color: nbColor,
                                  ),
                          ),
                          const Spacer(),
                          if (!isSelectionMode)
                            IconButton(
                              icon: const Icon(Icons.more_vert, size: 18),
                              color: AppColors.textSecondary,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              onPressed: () => _showOptions(context),
                            )
                          else
                            Icon(
                              isSelected ? Icons.check_circle : Icons.circle_outlined,
                              size: 22,
                              color: isSelected ? nbColor : AppColors.border,
                            ),
                        ],
                      ),
                      AppSpacing.vSm,
                      Text(
                        notebook.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (hasSummary) ...[
                        AppSpacing.vXs,
                        Expanded(
                          child: Text(
                            notebook.summary,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (notebook.suggestions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 13,
                                color: nbColor,
                              ),
                              AppSpacing.hXs,
                              Text(
                                '${notebook.suggestions.length} gợi ý',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: nbColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
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
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('Xoá notebook', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) => onDelete());
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('Chat với notebook này'),
              onTap: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) => onChat());
              },
            ),
            AppSpacing.vSm,
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
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ).appScaleIn(),
            AppSpacing.vLg,
            Text(
              'Chưa có notebook nào',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ).appEntrance(delay: const Duration(milliseconds: 100)),
            AppSpacing.vSm,
            Text(
              'Tạo notebook để nhóm tài liệu theo chủ đề\nvà nhận tóm tắt thông minh từ AI.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ).appEntrance(delay: const Duration(milliseconds: 160)),
            AppSpacing.vXl,
            CustomButton(
              label: 'Tạo notebook đầu tiên',
              onPressed: onCreate,
              icon: Icons.add_rounded,
            ).appEntrance(delay: const Duration(milliseconds: 220)),
          ],
        ),
      ),
    );
  }
}
