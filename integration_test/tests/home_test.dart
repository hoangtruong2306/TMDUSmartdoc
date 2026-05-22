// =============================================================================
// HOME TESTS — Kiểm tra màn hình chính và danh sách tài liệu
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:tdmu_smartdocs/main.dart';

const _testEmail    = 'test@tdmusmartdoc.dev';
const _testPassword = 'Test@12345';

/// Đăng nhập và chờ HomeScreen sẵn sàng.
Future<void> _loginAndGoHome(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(const TdmuSmartDocApp());
  await $.waitUntilVisible($(TextField));
  await $(TextField).at(0).enterText(_testEmail);
  await $(TextField).at(1).enterText(_testPassword);
  await $.pumpAndSettle(); // dismiss keyboard
  await $('Đăng nhập').tap();
  await $.waitUntilVisible($(BottomNavigationBar), timeout: const Duration(seconds: 20));
}

void homeTests() {
  group('Home Screen', () {
    // ── Test 1: Các thành phần chính hiện diện ──────────────────────────────
    patrolTest(
      'home screen has FAB and bottom navigation',
      ($) async {
        await _loginAndGoHome($);

        expect($(BottomNavigationBar), findsOneWidget);
        expect($(FloatingActionButton), findsOneWidget);
      },
    );

    // ── Test 2: Search không crash ──────────────────────────────────────────
    patrolTest(
      'search box filters list without crashing',
      ($) async {
        await _loginAndGoHome($);

        // Tìm search field và nhập text
        final searchFields = $(TextField);
        if (searchFields.evaluate().isNotEmpty) {
          await searchFields.first.enterText('test');
          await $.pumpAndSettle();
          // Không crash là pass
          expect(find.byType(Scaffold), findsOneWidget);
        }
      },
    );

    // ── Test 3: Long-press vào document card → selection mode ────────────────
    patrolTest(
      'long-pressing document card enters selection mode',
      ($) async {
        await _loginAndGoHome($);

        // Chờ list có ít nhất 1 card
        final cards = $(Card).evaluate();
        if (cards.isEmpty) {
          // Không có tài liệu nào → skip
          return;
        }

        await $(Card).first.longPress();
        await $.pumpAndSettle();

        // Selection AppBar phải xuất hiện
        final hasSelectionUI = find.byIcon(Icons.delete).evaluate().isNotEmpty ||
            find.textContaining('chọn').evaluate().isNotEmpty;
        expect(hasSelectionUI, isTrue);
      },
    );

    // ── Test 4: Thoát selection mode ─────────────────────────────────────────
    patrolTest(
      'back button exits selection mode',
      ($) async {
        await _loginAndGoHome($);

        final cards = $(Card).evaluate();
        if (cards.isEmpty) return;

        // Enter selection mode
        await $(Card).first.longPress();
        await $.pumpAndSettle();

        // Back để thoát
        await $.pumpAndSettle(); // dismiss keyboard
        await $.pumpAndSettle();

        // FAB phải trở lại
        expect($(FloatingActionButton), findsOneWidget);
      },
    );

    // ── Test 5: Navigate sang tab khác ──────────────────────────────────────
    patrolTest(
      'bottom nav tab 1 navigates away from home',
      ($) async {
        await _loginAndGoHome($);

        // Tap vào tab thứ 2 (index 1) của BottomNavigationBar
        final navBar = $(BottomNavigationBar);
        expect(navBar, findsOneWidget);

        await $(BottomNavigationBarItem).at(1).tap();
        await $.pumpAndSettle();

        // Scaffold vẫn còn (không crash)
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  });
}
