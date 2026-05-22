// =============================================================================
// TDMU SmartDoc — Patrol E2E Integration Test Suite
// =============================================================================
// Chạy: patrol test --target integration_test/app_test.dart
//
// Yêu cầu:
//   1. patrol_cli đã cài: dart pub global activate patrol_cli
//   2. Android emulator đang chạy hoặc device kết nối
//   3. Tạo test account trên Firebase Console: test@tdmusmartdoc.dev / Test@12345
//
// Cấu trúc test:
//   app_test.dart              ← entry point (file này)
//   tests/auth_test.dart       ← Login / Logout flow
//   tests/home_test.dart       ← Home screen, documents list
//   tests/notebook_test.dart   ← Tạo/xóa notebook
// =============================================================================

import 'tests/auth_test.dart';
import 'tests/home_test.dart';
import 'tests/notebook_test.dart';

void main() {
  authTests();
  homeTests();
  notebookTests();
}
