import 'package:flutter/material.dart';

// =============================================================================
// APP COLORS — Bảng màu TDMU SmartDoc
// Brand primary: #1565C0 (TDMU Blue)
// =============================================================================

class AppColors {
  // ── Brand palette ────────────────────────────────────────────────────────
  static const primary          = Color(0xFF1565C0); // TDMU Blue chủ đạo
  static const primaryLight     = Color(0xFF42A5F5); // Blue nhạt
  static const primaryDark      = Color(0xFF0D47A1); // Blue đậm
  static const primaryContainer = Color(0xFFE3F2FD); // Nền chip / badge
  static const onPrimaryContainer = Color(0xFF0D47A1); // Text trên nền container

  // ── AI accents ───────────────────────────────────────────────────────────
  static const secondary          = Color(0xFF42A5F5); // Xanh nhạt bổ trợ
  static const secondaryContainer = Color(0xFFE3F2FD);
  static const onSecondaryContainer = Color(0xFF1565C0);
  static const accent             = Color(0xFF06B6D4); // Cyan accent (citations)
  static const accentContainer    = Color(0xFFCFFAFE);

  // ── Neutral surfaces ─────────────────────────────────────────────────────
  static const background      = Color(0xFFF8FAFD);
  static const surface         = Colors.white;
  static const surfaceVariant  = Color(0xFFF1F5FB);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const surfaceMuted    = Color(0xFFEFF6FF);

  // ── Text colors ──────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF1A1A2E); // Đậm — tiêu đề
  static const textSecondary = Color(0xFF5C6B8A); // Vừa — mô tả
  static const textTertiary  = Color(0xFF9BA8BE); // Nhạt — placeholder

  // ── Status + border ──────────────────────────────────────────────────────
  static const border       = Color(0xFFE0E8F4);
  static const borderStrong = Color(0xFFCBD5E1);
  static const error        = Color(0xFFD32F2F); // Đỏ đậm
  static const warning      = Color(0xFFE65100); // Cam đậm
  static const success      = Color(0xFF2E7D32); // Xanh lá đậm

  // ── Document type colors ─────────────────────────────────────────────────
  static const documentPdf   = Color(0xFFEF4444); // Đỏ PDF
  static const documentSlide = Color(0xFFF97316); // Cam Slide
}
