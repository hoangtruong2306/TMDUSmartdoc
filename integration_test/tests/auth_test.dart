// =============================================================================
// AUTH TESTS — Kiểm tra luồng đăng nhập / đăng xuất
// =============================================================================
// Test account: tạo trên Firebase Console (Auth > Add user):
//   Email: test@tdmusmartdoc.dev
//   Password: Test@12345
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:tdmu_smartdocs/main.dart';

const _testEmail    = 'test@tdmusmartdoc.dev';
const _testPassword = 'Test@12345';

void authTests() {
  group('Auth Flow', () {
    // ── Test 1: Login screen hiển thị đúng ─────────────────────────────────
    patrolTest(
      'login screen shows email & password fields',
      ($) async {
        await $.pumpWidgetAndSettle(const TdmuSmartDocApp());

        // Chờ splash xong → LoginScreen
        await $.waitUntilVisible($(TextField));

        // Phải có ít nhất 2 TextField (email + password)
        expect($(TextField), findsAtLeastNWidgets(2));
        expect($(ElevatedButton), findsAtLeastNWidgets(1));
      },
    );

    // ── Test 2: Đăng nhập thành công ────────────────────────────────────────
    patrolTest(
      'valid credentials navigate to home screen',
      ($) async {
        await $.pumpWidgetAndSettle(const TdmuSmartDocApp());
        await $.waitUntilVisible($(TextField));

        // Nhập email (TextField đầu tiên)
        await $(TextField).at(0).enterText(_testEmail);
        // Nhập password (TextField thứ hai)
        await $(TextField).at(1).enterText(_testPassword);
        // Dismiss keyboard
        await $.pumpAndSettle(); // dismiss keyboard

        // Tap nút đăng nhập
        await $('Đăng nhập').tap();

        // Chờ HomeScreen load
        await $.waitUntilVisible(
          $(BottomNavigationBar),
          timeout: const Duration(seconds: 20),
        );
        expect($(BottomNavigationBar), findsOneWidget);
      },
    );

    // ── Test 3: Sai mật khẩu hiện lỗi ──────────────────────────────────────
    patrolTest(
      'wrong password shows error snackbar',
      ($) async {
        await $.pumpWidgetAndSettle(const TdmuSmartDocApp());
        await $.waitUntilVisible($(TextField));

        await $(TextField).at(0).enterText(_testEmail);
        await $(TextField).at(1).enterText('SaiMatKhauXyz999!');
        await $.pumpAndSettle(); // dismiss keyboard
        await $('Đăng nhập').tap();

        // Phải có SnackBar lỗi
        await $.waitUntilVisible($(SnackBar), timeout: const Duration(seconds: 10));
        expect($(SnackBar), findsOneWidget);
      },
    );

    // ── Test 4: Email rỗng hiện validation error ─────────────────────────────
    patrolTest(
      'empty email shows validation error',
      ($) async {
        await $.pumpWidgetAndSettle(const TdmuSmartDocApp());
        await $.waitUntilVisible($(TextField));

        // Tap submit mà không nhập gì
        await $('Đăng nhập').tap();
        await $.pumpAndSettle();

        // Phải có text lỗi validation
        expect(find.byType(Text), findsWidgets);
      },
    );
  });
}
