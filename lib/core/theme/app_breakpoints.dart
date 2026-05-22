import 'package:flutter/material.dart';

import 'app_spacing.dart';

class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 1200;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= compact && width < medium;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= medium;

  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= expanded) return AppSpacing.xxl;
    if (width >= compact) return AppSpacing.xl;
    return AppSpacing.lg;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final horizontal = horizontalPadding(context);
    return EdgeInsets.symmetric(
      horizontal: horizontal,
      vertical: AppSpacing.lg,
    );
  }

  static int documentGridColumns(double width) {
    if (width < 340) return 1;
    if (width >= expanded) return 4;
    if (width >= medium) return 3;
    return 2;
  }

  static double documentGridAspectRatio(double width) {
    if (width < 340) return 1.7;
    if (width < 380) return 0.74;
    if (width < compact) return 0.82;
    if (width < medium) return 0.85; // 1.05 → 0.85: cell cao hơn để chứa đủ nội dung card
    return 1.0;
  }
}
