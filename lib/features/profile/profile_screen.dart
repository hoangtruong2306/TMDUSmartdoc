import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../shared/widgets/widgets.dart';
import '../auth/providers/auth_provider.dart';
import '../chat/providers/chat_provider.dart';
import '../notebooks/providers/notebook_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingPhoto = false;
  bool _isUpdatingName = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  // ── Avatar ────────────────────────────────────────────────────────────────

  void _showAvatarOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary, size: 20),
              ),
              title: const Text('Chọn ảnh từ thư viện'),
              subtitle: const Text('JPG, PNG, GIF...'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadPhoto();
              },
            ),
            if (_user?.photoURL != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: AppColors.error, size: 20),
                ),
                title: const Text('Xoá ảnh đại diện',
                    style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  _removePhoto();
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    final user = _user;
    if (user == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final ext = (result.files.first.extension ?? 'jpg').toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final ref =
          FirebaseStorage.instance.ref('users/${user.uid}/avatar.$ext');
      await ref.putData(bytes, SettableMetadata(contentType: contentType));
      final url = await ref.getDownloadURL();
      await user.updatePhotoURL(url);
      await user.reload();
      if (mounted) {
        setState(() {});
        _showSnack('Ảnh đại diện đã cập nhật!');
      }
    } catch (e) {
      _showSnack('Lỗi tải ảnh lên. Vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    final user = _user;
    if (user == null) return;
    setState(() => _isUploadingPhoto = true);
    try {
      await user.updatePhotoURL(null);
      await user.reload();
      if (mounted) setState(() {});
    } catch (_) {
      _showSnack('Lỗi xoá ảnh. Vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ── Đổi tên ───────────────────────────────────────────────────────────────

  Future<void> _showEditNameDialog() async {
    final ctrl = TextEditingController(text: _user?.displayName ?? '');
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: const Text('Đổi tên hiển thị'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Tên hiển thị',
              hintText: 'Nhập tên của bạn',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, ctrl.text.trim());
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (newName == null || newName == _user?.displayName) return;

    setState(() => _isUpdatingName = true);
    try {
      await _user!.updateDisplayName(newName);
      await _user!.reload();
      if (mounted) {
        setState(() {});
        _showSnack('Tên đã cập nhật!');
      }
    } catch (_) {
      _showSnack('Lỗi cập nhật tên. Vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) setState(() => _isUpdatingName = false);
    }
  }

  // ── Đổi mật khẩu ─────────────────────────────────────────────────────────

  Future<void> _showChangePasswordDialog() async {
    final isEmailUser =
        _user?.providerData.any((p) => p.providerId == 'password') ?? false;
    if (!isEmailUser) {
      _showSnack('Tài khoản Google không dùng mật khẩu SmartDoc.');
      return;
    }

    final newPassCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: const Text('Đổi mật khẩu'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: newPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu mới',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Ít nhất 6 ký tự' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Xác nhận mật khẩu',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
                validator: (v) =>
                    v != newPassCtrl.text ? 'Mật khẩu không khớp' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, newPassCtrl.text);
              }
            },
            child: const Text('Đổi mật khẩu'),
          ),
        ],
      ),
    );

    if (result == null) return;
    try {
      await _user!.updatePassword(result);
      _showSnack('Mật khẩu đã thay đổi!');
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'requires-recent-login'
          ? 'Vui lòng đăng xuất và đăng nhập lại trước.'
          : (e.message ?? 'Lỗi không xác định.');
      _showSnack(msg, isError: true);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts.first[0].toUpperCase() : 'U';
  }

  Future<void> _confirmLogout(AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<ChatProvider>().clearAll();
      context.read<NotebookProvider>().clear();
      await auth.logout();
      if (mounted) context.go('/login');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final nbProvider = context.watch<NotebookProvider>();
    final user = _user;
    final pagePadding = AppBreakpoints.pagePadding(context);
    final displayName =
        user?.displayName ?? authProvider.userName ?? 'Người dùng';

    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: SingleChildScrollView(
        padding: pagePadding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                // ── Avatar ────────────────────────────────────────────────────
                GestureDetector(
                  onTap: _showAvatarOptions,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.primaryContainer,
                        backgroundImage: user?.photoURL != null
                            ? NetworkImage(user!.photoURL!)
                            : null,
                        child: _isUploadingPhoto
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.primary,
                                ),
                              )
                            : user?.photoURL == null
                                ? Text(
                                    _initials(displayName),
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : null,
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ).appScaleIn(),

                AppSpacing.vLg,

                // ── Tên + nút sửa ────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_isUpdatingName)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      )
                    else
                      GestureDetector(
                        onTap: _showEditNameDialog,
                        child: const Icon(Icons.edit_rounded,
                            size: 18, color: AppColors.textTertiary),
                      ),
                  ],
                ).appEntrance(delay: const Duration(milliseconds: 80)),

                AppSpacing.vXs,

                if (user?.email != null)
                  Text(
                    user!.email!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ).appEntrance(delay: const Duration(milliseconds: 120)),

                AppSpacing.vXxl,

                // ── Stats ─────────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatCard(
                      icon: Icons.auto_stories_rounded,
                      value: '${nbProvider.notebooks.length}',
                      label: 'Notebooks',
                    ),
                  ],
                ).appEntrance(delay: const Duration(milliseconds: 160)),

                AppSpacing.vXxl,

                // ── Tài khoản ─────────────────────────────────────────────────
                AppCard(
                  padding: AppSpacing.cardPaddingCompact,
                  child: Column(
                    children: [
                      _buildMenuItem(
                        Icons.badge_outlined,
                        'Đổi tên hiển thị',
                        onTap: _showEditNameDialog,
                      ),
                      const Divider(height: 32),
                      _buildMenuItem(
                        Icons.lock_outline_rounded,
                        'Đổi mật khẩu',
                        onTap: _showChangePasswordDialog,
                      ),
                      const Divider(height: 32),
                      _buildMenuItem(
                        Icons.help_outline_rounded,
                        'Trợ giúp & Hỗ trợ',
                      ),
                    ],
                  ),
                ).appEntrance(delay: const Duration(milliseconds: 200)),

                AppSpacing.vXxl,

                // ── Đăng xuất ─────────────────────────────────────────────────
                CustomButton(
                  label: 'Đăng xuất',
                  icon: Icons.logout,
                  variant: ButtonVariant.outline,
                  isFullWidth: true,
                  onPressed: () => _confirmLogout(authProvider),
                ).appEntrance(delay: const Duration(milliseconds: 260)),

                AppSpacing.vXl,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.control,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary),
            AppSpacing.hMd,
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 26),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
