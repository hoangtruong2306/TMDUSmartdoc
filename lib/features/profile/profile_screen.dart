import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../auth/providers/auth_provider.dart';
import '../chat/providers/chat_provider.dart';
import '../home/providers/document_provider.dart';
import '../notebooks/providers/notebook_provider.dart';

// ── App version (hardcoded — thay bằng package_info_plus nếu cần) ─────────────
const _kAppVersion = '1.0.0';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingPhoto = false;
  bool _isUpdatingName   = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return parts.isNotEmpty ? parts.first[0].toUpperCase() : 'U';
  }

  String _memberSince() {
    final meta = _user?.metadata.creationTime;
    if (meta == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return 'Thành viên từ ${months[meta.month - 1]} ${meta.year}';
  }

  bool get _isGoogleUser =>
      _user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

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

  // ── Avatar ────────────────────────────────────────────────────────────────────

  void _showAvatarOptions() {
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
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Ảnh đại diện',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            ListTile(
              leading: _iconBox(Icons.photo_library_outlined, AppColors.primary),
              title: const Text('Chọn ảnh từ thư viện'),
              subtitle: const Text('JPG, PNG, GIF...'),
              onTap: () { Navigator.pop(context); _pickAndUploadPhoto(); },
            ),
            if (_user?.photoURL != null)
              ListTile(
                leading: _iconBox(Icons.delete_outline_rounded, AppColors.error),
                title: const Text('Xoá ảnh đại diện',
                    style: TextStyle(color: AppColors.error)),
                onTap: () { Navigator.pop(context); _removePhoto(); },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    final user = _user;
    if (user == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final ext = (result.files.first.extension ?? 'jpg').toLowerCase();
      final ref = FirebaseStorage.instance.ref('users/${user.uid}/avatar.$ext');
      await ref.putData(bytes,
          SettableMetadata(contentType: ext == 'png' ? 'image/png' : 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await user.updatePhotoURL(url);
      await user.reload();
      if (mounted) { setState(() {}); _showSnack('Ảnh đại diện đã cập nhật!'); }
    } catch (_) {
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

  // ── Edit name ─────────────────────────────────────────────────────────────────

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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
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
      if (mounted) { setState(() {}); _showSnack('Tên đã cập nhật!'); }
    } catch (_) {
      _showSnack('Lỗi cập nhật tên. Vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) setState(() => _isUpdatingName = false);
    }
  }

  // ── Change password ───────────────────────────────────────────────────────────

  Future<void> _showChangePasswordDialog() async {
    final isEmailUser =
        _user?.providerData.any((p) => p.providerId == 'password') ?? false;
    if (!isEmailUser) {
      _showSnack('Tài khoản Google không dùng mật khẩu SmartDoc.');
      return;
    }

    final newPassCtrl  = TextEditingController();
    final confirmCtrl  = TextEditingController();
    final formKey      = GlobalKey<FormState>();

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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
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

  // ── About dialog ──────────────────────────────────────────────────────────────

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppRadius.card,
              ),
              child: const Icon(Icons.auto_stories_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('TDMU SmartDoc',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Phiên bản $_kAppVersion',
                style: const TextStyle(color: AppColors.textTertiary)),
            const SizedBox(height: 12),
            const Text(
              'Ứng dụng học tập thông minh cho sinh viên Trường Đại học Thủ Dầu Một. '
              'Hỗ trợ chat AI, luyện thi và flashcard từ tài liệu học tập.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  // ── Logout ────────────────────────────────────────────────────────────────────

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

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final nbProvider   = context.watch<NotebookProvider>();
    final docProvider  = context.watch<DocumentProvider>();
    final user         = _user;
    final displayName  = user?.displayName ?? authProvider.userName ?? 'Người dùng';
    final pagePadding  = AppBreakpoints.pagePadding(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // trạng thái bar trắng trên gradient
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            // ── 1. Gradient Hero Header ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _ProfileHeader(
                user:            user,
                displayName:     displayName,
                isUploadingPhoto: _isUploadingPhoto,
                isUpdatingName:  _isUpdatingName,
                isGoogleUser:    _isGoogleUser,
                memberSince:     _memberSince(),
                initials:        _initials(displayName),
                onAvatarTap:     _showAvatarOptions,
                onEditNameTap:   _showEditNameDialog,
                pagePadding:     pagePadding,
              ),
            ),

            // ── 2. Stats Dashboard ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: _StatsRow(
                notebookCount: nbProvider.notebooks.length,
                docCount:      docProvider.documents.length,
                pageCount:     docProvider.totalPageCount,
                padding:       pagePadding,
              ).appEntrance(delay: const Duration(milliseconds: 100)),
            ),

            // ── 3. Section: Tài khoản ────────────────────────────────────────
            SliverToBoxAdapter(
              child: _SettingsSection(
                label: 'Tài khoản',
                padding: pagePadding,
                tiles: [
                  _SettingsTile(
                    iconBg: AppColors.primary,
                    icon: Icons.badge_outlined,
                    title: 'Đổi tên hiển thị',
                    subtitle: displayName,
                    onTap: _showEditNameDialog,
                  ),
                  _SettingsTile(
                    iconBg: const Color(0xFFF59E0B),
                    icon: Icons.lock_outline_rounded,
                    title: 'Đổi mật khẩu',
                    subtitle: _isGoogleUser ? 'Tài khoản Google' : '••••••••',
                    trailing: _isGoogleUser
                        ? _ProviderBadge(isGoogle: true)
                        : null,
                    onTap: _showChangePasswordDialog,
                  ),
                ],
              ).appEntrance(delay: const Duration(milliseconds: 160)),
            ),

            // ── 4. Section: Ứng dụng ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: _SettingsSection(
                label: 'Ứng dụng',
                padding: pagePadding,
                tiles: [
                  _SettingsTile(
                    iconBg: const Color(0xFF7C3AED),
                    icon: Icons.help_outline_rounded,
                    title: 'Trợ giúp & Hỗ trợ',
                    subtitle: 'Câu hỏi thường gặp',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    iconBg: const Color(0xFF0891B2),
                    icon: Icons.info_outline_rounded,
                    title: 'Về TDMU SmartDoc',
                    subtitle: 'Phiên bản $_kAppVersion',
                    onTap: _showAboutDialog,
                  ),
                ],
              ).appEntrance(delay: const Duration(milliseconds: 200)),
            ),

            // ── 5. Logout button ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  pagePadding.left, AppSpacing.sm,
                  pagePadding.right, 0,
                ),
                child: _SettingsSection(
                  label: '',
                  padding: EdgeInsets.zero,
                  tiles: [
                    _SettingsTile(
                      iconBg: AppColors.error,
                      icon: Icons.logout_rounded,
                      title: 'Đăng xuất',
                      titleColor: AppColors.error,
                      showChevron: false,
                      onTap: () => _confirmLogout(authProvider),
                    ),
                  ],
                ),
              ).appEntrance(delay: const Duration(milliseconds: 240)),
            ),

            // ── 6. Version footer ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 48),
                child: Column(
                  children: [
                    Text(
                      'TDMU SmartDoc v$_kAppVersion',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Trường Đại học Thủ Dầu Một',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Colored icon container (iOS Settings style)
  static Widget _iconBox(IconData icon, Color color) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      );
}

// ── Profile Header ────────────────────────────────────────────────────────────
// Gradient banner + avatar overlap + name/email/badges

class _ProfileHeader extends StatelessWidget {
  final User? user;
  final String displayName;
  final bool isUploadingPhoto;
  final bool isUpdatingName;
  final bool isGoogleUser;
  final String memberSince;
  final String initials;
  final VoidCallback onAvatarTap;
  final VoidCallback onEditNameTap;
  final EdgeInsets pagePadding;

  const _ProfileHeader({
    required this.user,
    required this.displayName,
    required this.isUploadingPhoto,
    required this.isUpdatingName,
    required this.isGoogleUser,
    required this.memberSince,
    required this.initials,
    required this.onAvatarTap,
    required this.onEditNameTap,
    required this.pagePadding,
  });

  @override
  Widget build(BuildContext context) {
    const avatarRadius = 44.0; // diameter = 88px
    const overlapPx   = avatarRadius * 0.6; // avatar sticks out of banner by 60%

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // ── Gradient banner ─────────────────────────────────────────────────
        Container(
          height: 170,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: pagePadding.left),
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Hồ sơ',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Avatar (overlapping banner bottom) ──────────────────────────────
        Positioned(
          top: 170 - avatarRadius - overlapPx,
          child: GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // White ring border
                Container(
                  width: avatarRadius * 2 + 6,
                  height: avatarRadius * 2 + 6,
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: AppColors.primaryContainer,
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: isUploadingPhoto
                          ? const SizedBox(
                              width: 28, height: 28,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.primary),
                            )
                          : user?.photoURL == null
                              ? Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                )
                              : null,
                    ),
                  ),
                ),
                // Camera badge
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.background, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Name + email + badges (below banner) ────────────────────────────
        Padding(
          padding: EdgeInsets.only(
            top: 170 + avatarRadius - overlapPx + 12,
            left: pagePadding.left,
            right: pagePadding.right,
            bottom: 20,
          ),
          child: Column(
            children: [
              // Name row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isUpdatingName)
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  else
                    GestureDetector(
                      onTap: onEditNameTap,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            size: 13, color: AppColors.primary),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 6),

              // Email
              if (user?.email != null)
                Text(
                  user!.email!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),

              const SizedBox(height: 10),

              // Badges row: provider + member since
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _ProviderBadge(isGoogle: isGoogleUser),
                  if (memberSince.isNotEmpty)
                    _InfoBadge(
                      icon: Icons.calendar_today_outlined,
                      label: memberSince,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int notebookCount;
  final int docCount;
  final int pageCount;
  final EdgeInsets padding;

  const _StatsRow({
    required this.notebookCount,
    required this.docCount,
    required this.pageCount,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          padding.left, 0, padding.right, AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _StatCell(
                icon: Icons.auto_stories_rounded,
                value: '$notebookCount',
                label: 'Notebooks',
                color: AppColors.primary,
              ),
              VerticalDivider(
                  color: AppColors.border, width: 1, indent: 16, endIndent: 16),
              _StatCell(
                icon: Icons.description_outlined,
                value: '$docCount',
                label: 'Tài liệu',
                color: const Color(0xFF7C3AED),
              ),
              VerticalDivider(
                  color: AppColors.border, width: 1, indent: 16, endIndent: 16),
              _StatCell(
                icon: Icons.menu_book_outlined,
                value: '$pageCount',
                label: 'Trang',
                color: const Color(0xFF0891B2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCell({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Settings Section ──────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String label;
  final List<_SettingsTile> tiles;
  final EdgeInsets padding;

  const _SettingsSection({
    required this.label,
    required this.tiles,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        padding.left, label.isEmpty ? 0 : AppSpacing.lg,
        padding.right, 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                for (int i = 0; i < tiles.length; i++) ...[
                  tiles[i],
                  if (i < tiles.length - 1)
                    Divider(
                      height: 1,
                      indent: 60,
                      endIndent: 0,
                      color: AppColors.border,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final Color iconBg;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.iconBg,
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.trailing,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 13),
          child: Row(
            children: [
              // Colored icon container (iOS Settings style)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 17),
              ),

              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: titleColor ?? AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),

              // Trailing
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (showChevron)
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Provider Badge ────────────────────────────────────────────────────────────

class _ProviderBadge extends StatelessWidget {
  final bool isGoogle;
  const _ProviderBadge({required this.isGoogle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isGoogle
            ? const Color(0xFFEA4335).withValues(alpha: 0.1)
            : AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGoogle
              ? const Color(0xFFEA4335).withValues(alpha: 0.3)
              : AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGoogle ? Icons.g_mobiledata_rounded : Icons.email_outlined,
            size: 14,
            color: isGoogle ? const Color(0xFFEA4335) : AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            isGoogle ? 'Google' : 'Email',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isGoogle ? const Color(0xFFEA4335) : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Badge ────────────────────────────────────────────────────────────────

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
