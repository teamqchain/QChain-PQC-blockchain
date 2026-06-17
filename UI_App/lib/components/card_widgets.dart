// ─────────────────────────────────────────────────────────────────────────────
// card_widgets.dart
//
// Single source of truth for every document-card visual.
//
// Public API:
//   WalletCard       — card sized for the stack/swiper view
//   ListCard         — card sized for the list view
//   EmptyDocsState   — "no documents" placeholder (used by both views)
//   StackCounter     — animated dot + counter pill (used by stack view)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/model/IdentityDoc.dart';
import 'package:qwallet_mobileapp/model/credential_model.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _kWhite50 = 0.50; // subtitle opacity
const _kWhite35 = 0.35; // label text opacity
const _kWhite85 = 0.85; // value text opacity
const _kWhite13 = 0.13; // icon box fill opacity
const _kWhite20 = 0.20; // icon box border opacity
const _kWhite18 = 0.18; // fav border default / bottom strip fill opacity

// ─── Private sub-widgets ─────────────────────────────────────────────────────

/// Icon box — top-left of every card.
class _DocIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final double fontSize;
  final double radius;

  const _DocIcon({
    required this.icon,
    required this.size,
    required this.fontSize,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(_kWhite13),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(_kWhite20)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: fontSize),
    );
  }
}

/// Animated star / fav button — top-right of every card.
class _FavButton extends StatelessWidget {
  final bool isFav;
  final double size;
  final double iconSize;
  final VoidCallback onTap;

  const _FavButton({
    required this.isFav,
    required this.size,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isFav
              ? Colors.amber.withOpacity(0.18)
              : Colors.white.withOpacity(0.10),
          border: Border.all(
            color: isFav
                ? Colors.amber.withOpacity(0.50)
                : Colors.white.withOpacity(_kWhite18),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          isFav ? Icons.star : Icons.star_border,
          color: isFav ? Colors.amber : Colors.white54,
          size: iconSize,
        ),
      ),
    );
  }
}

/// NUMBER / EXPIRES strip — bottom of every card.
class _InfoStrip extends StatelessWidget {
  final String number;
  final String status;
  final String expires;

  const _InfoStrip({
    required this.number,
    required this.status,
    required this.expires,
  });

  Widget _field(
    String label,

    String value, {
    CrossAxisAlignment align = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(_kWhite35),
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withOpacity(_kWhite85),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(_kWhite18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _field('NUMBER', number),
          _field('STATUS', status),
          _field('EXPIRES', expires, align: CrossAxisAlignment.end),
        ],
      ),
    );
  }
}

/// Shared card shell — background color, shadows, gradient overlay,
/// watermark emoji and shine orb. Used by both WalletCard and ListCard.
class _CardDecorations extends StatelessWidget {
  final Color color;
  final double borderRadius;
  final IconData icon;
  final double watermarkSize;
  final Widget child;

  const _CardDecorations({
    required this.color,
    required this.borderRadius,
    required this.icon,
    required this.watermarkSize,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.45),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.transparent,
                    Colors.black.withOpacity(0.12),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Watermark emoji
          Positioned(
            right: -18,
            bottom: -18,
            child: Opacity(
              opacity: 0.07,
              child: Icon(icon, size: watermarkSize),
            ),
          ),
          // Shine orb
          Positioned(
            top: -50,
            left: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withOpacity(0.12), Colors.transparent],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ─── WalletCard ───────────────────────────────────────────────────────────────
// Used by stackView.dart — slightly larger sizing for the swiper layout.

// ─── WalletCard ───────────────────────────────────────────────────────────────

class WalletCard extends StatelessWidget {
  final CredentialModel doc;
  final bool isFav;
  final VoidCallback onFav;
  final VoidCallback onTap;

  const WalletCard({
    required this.doc,
    required this.isFav,
    required this.onFav,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _CardDecorations(
        color: doc.cardColor,
        borderRadius: 28,
        icon: doc.icon,
        watermarkSize: 140,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _DocIcon(icon: doc.icon, size: 48, fontSize: 24, radius: 14),
                  _FavButton(
                    isFav: isFav,
                    size: 36,
                    iconSize: 17,
                    onTap: onFav,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                doc.credentialType,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                doc.issuedBy,
                style: TextStyle(
                  color: Colors.white.withOpacity(_kWhite50),
                  fontSize: 11,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 20),
              _InfoStrip(
                number: doc.credentialID,
                status: doc.displayStatus,
                expires: doc.formattedExpiryDate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── ListCard ─────────────────────────────────────────────────────────────────

class ListCard extends StatelessWidget {
  final CredentialModel doc;
  final bool isFav;
  final VoidCallback onFav;
  final VoidCallback onTap;

  const ListCard({
    super.key,
    required this.doc,
    required this.isFav,
    required this.onFav,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _CardDecorations(
        color: doc.cardColor,
        borderRadius: 20,
        icon: doc.icon,
        watermarkSize: 100,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _DocIcon(icon: doc.icon, size: 44, fontSize: 22, radius: 12),
                  _FavButton(
                    isFav: isFav,
                    size: 34,
                    iconSize: 16,
                    onTap: onFav,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                doc.credentialType,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                doc.issuedBy,
                style: TextStyle(
                  color: Colors.white.withOpacity(_kWhite50),
                  fontSize: 11,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 16),
              _InfoStrip(
                number: doc.credentialID,
                status: doc.displayStatus,
                expires: doc.formattedExpiryDate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── EmptyDocsState ───────────────────────────────────────────────────────────
// Shown by both views when the category has no documents.

class EmptyDocsState extends StatelessWidget {
  const EmptyDocsState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: const Text('📭', style: TextStyle(fontSize: 34)),
          ),
          const SizedBox(height: 18),
          const Text(
            'No documents yet',
            style: TextStyle(
              color: Color(0xFF000000),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add a document to this category\nto see it here',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF999999),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── StackCounter ─────────────────────────────────────────────────────────────
// Animated dot-strip + "X / Y" pill shown above the swiper in stack view.

class StackCounter extends StatelessWidget {
  final int current;
  final int total;
  final Color color;

  const StackCounter({
    super.key,
    required this.current,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.25), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: List.generate(total, (i) {
              final isActive = i == current - 1;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: isActive ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? color : color.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(width: 10),
          Text(
            '$current / $total',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
