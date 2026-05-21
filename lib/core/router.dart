// =============================================================================
// ROUTER — Cấu hình điều hướng ứng dụng với GoRouter
// =============================================================================
// CẤU TRÚC ROUTE:
//
//   /splash    → SplashScreen (kiểm tra trạng thái đăng nhập, điều hướng tự động)
//   /login     → LoginScreen (đăng nhập email/Google)
//   /home      ┐
//   /upload    ├─ ShellRoute (bọc bởi MainScaffold — có BottomNavigationBar)
//   /chat      ┤
//   /profile   ┘
//
// THUẬT TOÁN AUTH GUARD (redirect callback):
//
//   Mỗi khi điều hướng đến bất kỳ route nào, GoRouter gọi hàm redirect():
//
//   1. Lấy user hiện tại từ FirebaseAuth (null = chưa đăng nhập)
//   2. Kiểm tra route đích có thuộc _protectedRoutes không
//   3. Nếu route cần đăng nhập MÀ user chưa đăng nhập → chuyển về /login
//   4. Nếu đang ở /login MÀ user đã đăng nhập → chuyển về /home (tránh vào lại login)
//   5. Ngược lại → cho phép điều hướng bình thường (return null)
//
// SHELL ROUTE:
//   MainScaffold bọc các route con → BottomNavigationBar luôn hiển thị
//   Khi chuyển giữa /home, /upload, /chat, /profile → không rebuild Scaffold
//
// PAGE TRANSITION:
//   FadeTransition + SlideTransition (y: 0.04 → 0.0)
//   → Hiệu ứng "trôi nhẹ lên" kết hợp fade-in
// =============================================================================

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/splash/splash_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/home/home_screen.dart';
import '../features/notebooks/notebooks_screen.dart';
import '../features/notebook/screens/notebook_detail_screen.dart';
import '../features/upload/upload_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/quiz/screens/quiz_screen.dart';
import '../features/quiz/screens/quiz_history_screen.dart';
import '../features/quiz/screens/quiz_review_screen.dart';
import '../shared/widgets/main_scaffold.dart';
import 'constants.dart';

/// Listenable bọc một Stream — GoRouter gọi lại redirect mỗi khi stream emit.
/// Dùng cho authStateChanges() để router re-evaluate guard sau login/logout.
class _GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _sub;
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

// Key để truy cập Navigator gốc từ bất kỳ đâu trong app
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

// Key riêng cho Shell (các route có BottomNavigationBar)
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

// Danh sách route cần đăng nhập — dùng startsWith() để bắt cả sub-route
// vd: /home/document/123 cũng sẽ bị guard
const _protectedRoutes = ['/home', '/notebooks', '/notebook', '/upload', '/chat', '/profile', '/quiz'];

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  refreshListenable: _GoRouterRefreshStream(
    FirebaseAuth.instance.authStateChanges(),
  ),

  /// Auth Guard — chạy trước mỗi lần điều hướng.
  ///
  /// Thuật toán:
  ///   - user == null → chưa đăng nhập
  ///   - isProtected = route đích có trong _protectedRoutes
  ///
  ///   Case 1: isProtected && !loggedIn → redirect /login (bảo vệ route)
  ///   Case 2: đang ở /login && loggedIn → redirect /home (tránh vào lại)
  ///   Case 3: các trường hợp khác → null (cho phép điều hướng tự do)
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final loc = state.matchedLocation;
    final isProtected = _protectedRoutes.any((r) => loc.startsWith(r));
    final isAuthRoute = loc == '/login' || loc == '/register' || loc == '/forgot-password';

    if (isProtected && user == null) return '/login';
    if (isAuthRoute && user != null) return '/home';
    return null;
  },

  routes: [
    // Route không cần shell (không có BottomNavigationBar)
    GoRoute(
      path: '/splash',
      pageBuilder: (context, state) =>
          buildPageTransition(state, const SplashScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) =>
          buildPageTransition(state, const LoginScreen()),
    ),
    GoRoute(
      path: '/register',
      pageBuilder: (context, state) =>
          buildPageTransition(state, const RegisterScreen()),
    ),
    GoRoute(
      path: '/forgot-password',
      pageBuilder: (context, state) =>
          buildPageTransition(state, const ForgotPasswordScreen()),
    ),

    // Route notebook detail — ngoài ShellRoute (không BottomNav)
    GoRoute(
      path: '/notebook/:id',
      pageBuilder: (context, state) {
        final notebookId = state.pathParameters['id']!;
        return buildPageTransition(
          state,
          NotebookDetailScreen(notebookId: notebookId),
        );
      },
    ),

    // Route Quiz AI — full-screen, không có BottomNav
    // Path: /quiz/:notebookId?name=<encodedName>
    // notebookId  → để gọi API /quiz/generate
    // name        → query param tên notebook, hiển thị trên AppBar
    GoRoute(
      path: '/quiz/:notebookId',
      pageBuilder: (context, state) {
        final notebookId   = state.pathParameters['notebookId']!;
        final notebookName = state.uri.queryParameters['name'] ?? 'Notebook';
        return buildPageTransition(
          state,
          QuizScreen(
            notebookId:   notebookId,
            notebookName: notebookName,
          ),
        );
      },
    ),

    // Route lịch sử luyện thi — danh sách các lần làm bài của 1 notebook
    // Path: /quiz/history/:notebookId?name=<encodedName>
    GoRoute(
      path: '/quiz/history/:notebookId',
      pageBuilder: (context, state) {
        final notebookId   = state.pathParameters['notebookId']!;
        final notebookName = state.uri.queryParameters['name'] ?? 'Notebook';
        return buildPageTransition(
          state,
          QuizHistoryScreen(
            notebookId:   notebookId,
            notebookName: notebookName,
          ),
        );
      },
    ),

    // Route xem lại chi tiết 1 session — câu hỏi + đáp án + giải thích
    // Path: /quiz/review/:sessionId
    GoRoute(
      path: '/quiz/review/:sessionId',
      pageBuilder: (context, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return buildPageTransition(
          state,
          QuizReviewScreen(sessionId: sessionId),
        );
      },
    ),

    // ShellRoute: các route này share cùng MainScaffold (BottomNavigationBar)
    // Khi điều hướng giữa /home, /upload, /chat, /profile:
    // Khi điều hướng giữa /home, /upload, /chat, /profile:
    //   → child Widget thay đổi nhưng MainScaffold KHÔNG rebuild
    //   → BottomNavigationBar giữ nguyên, không bị flash
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) =>
              buildPageTransition(state, const HomeScreen()),
        ),
        GoRoute(
          path: '/notebooks',
          pageBuilder: (context, state) =>
              buildPageTransition(state, const NotebooksScreen()),
        ),
        GoRoute(
          path: '/upload',
          pageBuilder: (context, state) =>
              buildPageTransition(state, const UploadScreen()),
        ),
        GoRoute(
          path: '/chat',
          pageBuilder: (context, state) =>
              buildPageTransition(state, const ChatScreen()),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) =>
              buildPageTransition(state, const ProfileScreen()),
        ),
      ],
    ),
  ],
);

/// Tạo page transition với hiệu ứng Fade + Slide nhẹ từ dưới lên.
///
/// Thuật toán:
///   - FadeTransition: opacity 0.0 → 1.0 theo CurveTween(AppMotion.curve)
///   - SlideTransition: offset (0, 0.04) → (0, 0) — dịch chuyển 4% chiều cao lên trên
///   - Hai animation chạy song song, cùng dùng chung [animation] từ GoRouter
///
/// Kết quả: màn hình mới "trôi nhẹ lên" kết hợp fade-in — cảm giác mượt mà.
CustomTransitionPage buildPageTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        // Opacity theo đường cong easing (không tuyến tính — nhanh đầu, chậm cuối)
        opacity: CurveTween(curve: AppMotion.curve).animate(animation),
        child: SlideTransition(
          // Slide từ y=0.04 (hơi dưới) về y=0 (vị trí đúng)
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.04),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: AppMotion.curve)),
          child: child,
        ),
      );
    },
  );
}
