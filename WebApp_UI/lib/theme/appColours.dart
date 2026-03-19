import 'package:flutter/material.dart';

abstract class AppColors {
  // ── Base ────────────────────────────────────────────────────────────────────
  static const bg = Color(0xFF0A0A0A);
  static const surface = Color(0xFF111111);
  static const surfaceHover = Color(0xFF1A1A1A);
  static const border = Color(0xFF222222);
  static const borderLight = Color(0xFF2A2A2A);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const text = Color(0xFFF0F0F0);
  static const textMuted = Color(0xFF888888);
  static const textDim = Color(0xFF555555);
  static const white = Color(0xFFFFFFFF);

  // ── Issuing — Navy Blue ────────────────────────────────────────────────────
  static const issuingDark = Color(0xFF0A1628);
  static const issuingMid = Color(0xFF0D1F3C);
  static const issuingAccent = Color(0xFF2563EB);
  static const issuingLight = Color(0xFF3B82F6);
  static const issuingGlow = Color(0x262563EB);

  // ── Verifying — Forest Green ───────────────────────────────────────────────
  static const verifyingDark = Color(0xFF071A10);
  static const verifyingMid = Color(0xFF0B2A1A);
  static const verifyingAccent = Color(0xFF16A34A);
  static const verifyingLight = Color(0xFF22C55E);
  static const verifyingGlow = Color(0x2616A34A);

  // ── IT Admin — Purple ───────────────────────────────────────────────
  static const adminDark = Color(0xFF140A1F);
  static const adminMid = Color(0xFF1F1033);
  static const adminAccent = Color(0xFF8B5CF6);
  static const adminLight = Color(0xFFA78BFA);
  static const adminGlow = Color(0x268B5CF6);

  // ── Sidebar neutral ────────────────────────────────────────────────────────
  static const sidebarNeutral = Color(0xFF0F0F0F);

  // ── Status ─────────────────────────────────────────────────────────────────
  static const valid = Color(0xFF22C55E);
  static const revoked = Color(0xFFEF4444);
  static const suspended = Color(0xFFF59E0B);
  static const expired = Color(0xFF6B7280);
}
