import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../shared/widgets/widgets.dart';
import 'providers/upload_provider.dart';
import '../home/providers/document_provider.dart';
import '../notebooks/providers/notebook_provider.dart';

class UploadScreen extends StatefulWidget {
  /// notebookId được truyền trực tiếp khi navigate từ NotebookDetail
  /// (tránh lỗi duplicate GlobalKey với GoRouter ShellRoute)
  final String? notebookId;

  const UploadScreen({super.key, this.notebookId});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String? _selectedNotebookId;
  String? _returnNotebookId;

  @override
  void initState() {
    super.initState();
    // Truyền notebookId trực tiếp qua constructor (tránh lỗi GoRouter key)
    final id = widget.notebookId;
    if (id != null && id.isNotEmpty) {
      _selectedNotebookId = id;
      _returnNotebookId = id;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotebookProvider>().loadNotebooks();
    });
  }

  Future<void> _pickAndUpload() async {
    final notebookId = _selectedNotebookId;

    // ── Kiểm tra notebook được chọn (REQUIRED) ─────────────────────────────
    if (notebookId == null || notebookId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn notebook trước khi upload'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uploadProvider = context.read<UploadProvider>();
    final documentProvider = context.read<DocumentProvider>();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    // ── Upload với notebook_id (REQUIRED) ──────────────────────────────────
    final success = await uploadProvider.uploadFile(
      file.name,
      file.bytes!,
      notebookId: notebookId,  // pass as required parameter
    );

    if (!mounted) return;

    if (success) {
      // Refresh danh sách tài liệu → home screen hiển thị file vừa upload
      await documentProvider.refresh();
      if (!mounted) return;
      
      // Nếu upload từ notebook detail → pop về (tránh duplicate GlobalKey)
      if (_returnNotebookId != null) {
        context.pop();
      } else {
        context.go('/home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tải lên thất bại. Vui lòng thử lại!'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
          margin: const EdgeInsets.all(AppSpacing.md),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UploadProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tải tài liệu lên'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: provider.isUploading
                    ? _UploadingCard(provider: provider, key: const ValueKey('up'))
                    : _IdleCard(
                        key: const ValueKey('idle'),
                        onPick: _pickAndUpload,
                        selectedNotebookId: _selectedNotebookId,
                        onNotebookChanged: (id) => setState(() => _selectedNotebookId = id),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Idle state ──────────────────────────────────────────────────────────────

class _IdleCard extends StatelessWidget {
  final VoidCallback onPick;
  final String? selectedNotebookId;
  final ValueChanged<String?> onNotebookChanged;

  const _IdleCard({
    required this.onPick,
    required this.selectedNotebookId,
    required this.onNotebookChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drop zone
        InkWell(
          onTap: onPick,
          borderRadius: AppRadius.card,
          child: Container(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xxl, horizontal: AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.card,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
                width: 2,
              ),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    size: 44,
                    color: AppColors.primary,
                  ),
                )
                    .animate()
                    .scale(begin: const Offset(0.8, 0.8), duration: 400.ms,
                        curve: Curves.elasticOut),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Nhấp hoặc kéo thả file vào đây',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Hỗ trợ PDF · TXT · Tối đa 20 MB',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                CustomButton(
                  label: 'Chọn tệp tin',
                  onPressed: onPick,
                  icon: Icons.folder_open_outlined,
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05),

        const SizedBox(height: AppSpacing.lg),

        // Format chips
        Text(
          'Định dạng hỗ trợ',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _FormatChip(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF',
                color: AppColors.documentPdf,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _FormatChip(
                icon: Icons.text_snippet_outlined,
                label: 'TXT',
                color: AppColors.primary,
              ),
            ),
          ],
        ).animate().fadeIn(delay: 160.ms),

        const SizedBox(height: AppSpacing.lg),

        // Notebook selector
        _NotebookSelector(
          selectedNotebookId: selectedNotebookId,
          onChanged: onNotebookChanged,
        ).animate().fadeIn(delay: 200.ms),

        const SizedBox(height: AppSpacing.lg),

        // Tip
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.5),
            borderRadius: AppRadius.control,
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'AI sẽ đọc và lập chỉ mục nội dung tài liệu để bạn có thể hỏi đáp trực tiếp.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onPrimaryContainer,
                      ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 220.ms),
      ],
    );
  }
}

// ── Notebook Selector ────────────────────────────────────────────────────────

class _NotebookSelector extends StatelessWidget {
  final String? selectedNotebookId;
  final ValueChanged<String?> onChanged;

  const _NotebookSelector({
    required this.selectedNotebookId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final notebooks = context.watch<NotebookProvider>().notebooks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thêm vào Notebook',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: AppRadius.control,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: selectedNotebookId,
              isExpanded: true,
              hint: const Text('Không chọn (tuỳ chọn)'),
              icon: const Icon(Icons.expand_more_rounded),
              onChanged: onChanged,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Không chọn'),
                ),
                ...notebooks.map((nb) {
                  final color = nb.flutterColor;
                  return DropdownMenuItem<String?>(
                    value: nb.id,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            nb.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Format Chip ───────────────────────────────────────────────────────────────

class _FormatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _FormatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.control,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Uploading state ──────────────────────────────────────────────────────────

class _UploadingCard extends StatelessWidget {
  final UploadProvider provider;
  const _UploadingCard({required this.provider, super.key});

  @override
  Widget build(BuildContext context) {
    final pct = (provider.progress * 100).toInt();
    const steps = [
      (label: 'Tải lên', icon: Icons.cloud_upload_outlined, threshold: 0.05),
      (label: 'Trích xuất', icon: Icons.article_outlined, threshold: 0.40),
      (label: 'Nhúng AI', icon: Icons.hub_outlined, threshold: 0.70),
      (label: 'Hoàn tất', icon: Icons.auto_awesome, threshold: 0.90),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              _AIPulseIcon(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.progress < 0.7
                          ? 'Đang xử lý tài liệu…'
                          : 'AI đang lập chỉ mục',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider.currentFileName.isEmpty
                          ? 'Đang chuẩn bị…'
                          : provider.currentFileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                '$pct%',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Progress bar
          ClipRRect(
            borderRadius: AppRadius.chip,
            child: LinearProgressIndicator(
              value: provider.progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),

          const SizedBox(height: AppSpacing.xs),
          Text(
            provider.currentStep,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.primary),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Step badges
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: steps.map((s) {
              final done = provider.progress >= s.threshold;
              return _StepBadge(
                  icon: s.icon, label: s.label, active: done);
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.lg),

          CustomButton(
            label: 'Hủy',
            onPressed: () => context.read<UploadProvider>().cancelUpload(),
            variant: ButtonVariant.outline,
            isFullWidth: true,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _StepBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _StepBadge(
      {required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: active ? AppColors.primaryContainer : AppColors.surfaceVariant,
        borderRadius: AppRadius.chip,
        border: Border.all(
          color: active
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: active ? AppColors.primary : AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: active ? AppColors.primary : AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _AIPulseIcon extends StatefulWidget {
  @override
  State<_AIPulseIcon> createState() => _AIPulseIconState();
}

class _AIPulseIconState extends State<_AIPulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _scale = Tween(begin: 0.93, end: 1.05).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: AppRadius.control,
        ),
        child: const Icon(Icons.auto_awesome,
            color: AppColors.primary, size: 22),
      ),
    );
  }
}
