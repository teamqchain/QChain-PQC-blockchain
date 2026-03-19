import 'package:flutter/material.dart';

// ─── QCHAIN COLOR PALETTE (INVERTED) ──────────────────────────────────────────
// Now: White-dominant instead of black-dominant.

// ── Dark Mode Backgrounds (Now Light-Based) ───────────────────────────────────
const Color qBg = Color(0xFFFFFFFF); // Pure white — main background
const Color qBgSurface = Color(0xFFF5F5F5); // Soft white surface
const Color qCard = Color(0xFFFFFFFF); // Cards
const Color qCardAlt = Color(0xFFF0F0F0); // Elevated cards
const Color qBorder = Color(0xFFE0E0E0); // Subtle borders
const Color qDivider = Color(0xFFEAEAEA); // Divider lines

// ── Brand — Monochrome ────────────────────────────────────────────────────────
const Color qPrimary = Color(0xFF000000); // Pure black — primary action
const Color qAccent = Color(0xFF333333); // Dark gray accent
const Color qGlow = Color(0xFF000000); // Black glow
const Color qHighlight = Color(0xFFDDDDDD); // Pressed state

// ── Text ──────────────────────────────────────────────────────────────────────
const Color qText = Color(0xFF000000); // Primary — black
const Color qSub = Colors.grey; // Secondary — darker gray
const Color qMuted = Colors.grey; // Muted
const Color qDimmed = Color(0xFFBBBBBB); // Very muted

// ── Semantic ──────────────────────────────────────────────────────────────────
const Color qValid = Colors.green;
Color qValidBg = Color(0xFFF5F5F5);
const Color qRed = Color(0xFFFF3B30);
const Color qRedBg = Color(0xFFFFEAEA);
const Color qAmber = Colors.orange;
const Color qAmberBg = Color(0xFFFFF8E1);

// ── Gradients ─────────────────────────────────────────────────────────────────
const LinearGradient qGradient = LinearGradient(
  colors: [Color(0xFF000000), Color(0xFF444444)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient qCardGradient = LinearGradient(
  colors: [Color(0xFFFFFFFF), Color(0xFFF0F0F0)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
