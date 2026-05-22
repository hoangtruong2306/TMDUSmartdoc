// =============================================================================
// NOTEBOOK TESTS — Kiểm tra tạo / xem notebook
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:tdmu_smartdocs/main.dart';

const _testEmail    = 'test@tdmusmartdoc.dev';
const _testPassword = 'Test@12345';

/// Login và navigate sang tab Notebooks (tab index 1).
Future<void> _goToNotebooks(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(const TdmuSmartDocApp());
  await $.waitUntilVisible($(TextField));
  await $(TextField).at(0).enterText(_testEmail);
  await $(TextField).at(1).enterText(_testPassword);
  await $.pumpAndSettle(); // dismiss keyboard
  await $('Đăng nhập').tap();
  await $.waitUntilVisible($(BottomNavigationBar), timeout: const Duration(seconds: 20));

  // Tap sang tab Notebooks
  await $(BottomNavigationBarItem).at(1).tap();
  await $.pumpAndSettle();
}

void notebookTests() {
  group('Notebook CRUD', () {
    // ── Test 1: Tab Notebooks có FAB ─────────────────────────────────────────
    patrolTest(
      'notebooks tab displays FAB for creating new notebook',
      ($) async {
        await _goToNotebooks($);

        expect($(FloatingActionButton), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    // ── Test 2: Tạo notebook mới xuất hiện trong list ─────────────────────
    patrolTest(
      'create notebook shows it in the list',
      ($) async {
        await _goToNotebooks($);

        // Unique name để test không conflict
        final testName = 'PatrolTest_${DateTime.now().millisecondsSinceEpoch}';

        // Tap FAB
        await $(FloatingActionButton).tap();
        await $.pumpAndSettle();

        // Dialog phải xuất hiện với TextField
        await $.waitUntilVisible($(AlertDialog));
        await $(AlertDialog).$(TextField).first.enterText(testName);

        // Tap nút Tạo
        await $('Tạo').tap();
        await $.pumpAndSettle();

        // Chờ item mới xuất hiện
        await $.waitUntilVisible(
          find.textContaining(testName),
          timeout: const Duration(seconds: 10),
        );
        expect(find.textContaining(testName), findsOneWidget);
      },
    );

    // ── Test 3: Tap notebook → mở detail screen ────────────────────────────
    patrolTest(
      'tapping notebook card opens detail screen',
      ($) async {
        await _goToNotebooks($);

        // Chờ có ít nhất 1 notebook card
        final cards = $(Card).evaluate();
        if (cards.isEmpty) {
          // Tạo mới trước
          await $(FloatingActionButton).tap();
          await $.waitUntilVisible($(AlertDialog));
          await $(AlertDialog).$(TextField).first.enterText('Test Notebook');
          await $('Tạo').tap();
          await $.waitUntilVisible($(Card), timeout: const Duration(seconds: 10));
        }

        // Tap card đầu tiên
        await $(Card).first.tap();
        await $.pumpAndSettle();

        // NotebookDetailScreen phải load (có AppBar)
        expect(find.byType(AppBar), findsOneWidget);
      },
    );

    // ── Test 4: Detail screen có nút Thêm tài liệu ───────────────────────
    patrolTest(
      'notebook detail screen has add documents button',
      ($) async {
        await _goToNotebooks($);

        final cards = $(Card).evaluate();
        if (cards.isEmpty) return;

        await $(Card).first.tap();
        await $.pumpAndSettle();

        // FAB hoặc nút "Thêm" phải có
        final hasFab = $(FloatingActionButton).evaluate().isNotEmpty;
        final hasAddButton = find.textContaining('Thêm').evaluate().isNotEmpty;
        expect(hasFab || hasAddButton, isTrue);
      },
    );
  });
}
