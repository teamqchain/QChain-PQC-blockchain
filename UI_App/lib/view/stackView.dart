import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/components/card_widgets.dart';
import 'package:qwallet_mobileapp/model/IdentityDoc.dart';

class StackView extends StatefulWidget {
  final List<IdentityDoc> docs;
  final void Function(int) onFav;
  final void Function(IdentityDoc) onTap;

  const StackView({
    super.key,
    required this.docs,
    required this.onFav,
    required this.onTap,
  });

  @override
  State<StackView> createState() => StackViewState();
}

class StackViewState extends State<StackView>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  double _dragOffset = 0.0; // Tracks finger movement during a drag

  late AnimationController _hintCtrl;
  late Animation<double> _hintAnim;

  @override
  void initState() {
    super.initState();
    _hintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _hintAnim = Tween<double>(
      begin: 0,
      end: -8,
    ).animate(CurvedAnimation(parent: _hintCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _hintCtrl.dispose();
    super.dispose();
  }

  // ─── GESTURE HANDLING ────────────────────────────────────────────────────────

  void _onPanUpdate(DragUpdateDetails details) {
    if (widget.docs.length <= 1)
      return; // Prevent drag if there's nothing to browse
    setState(() {
      _dragOffset += details.delta.dy; // Accumulate vertical movement
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (widget.docs.length <= 1) return; // Prevent if one doc

    // Thresholds: Determine if a full swipe was made or if it should snap back
    if (_dragOffset > 60 || details.primaryVelocity! > 300) {
      // Swipe down completed (Reveal NEXT card)
      setState(() {
        _currentIndex =
            (_currentIndex + 1) % widget.docs.length; // Loop through items
      });
    } else if (_dragOffset < -60 || details.primaryVelocity! < -300) {
      // Swipe up completed (Reveal PREVIOUS card)
      setState(() {
        _currentIndex =
            (_currentIndex - 1 + widget.docs.length) %
            widget.docs.length; // Handle reverse looping
      });
    }

    // Reset drag offset to trigger the shuffle-back/spring-back animations
    setState(() {
      _dragOffset = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.docs.isEmpty) return const EmptyDocsState();

    final cardWidth = MediaQuery.of(context).size.width - 48;
    const cardHeight = 240.0;

    // We only visually render up to 3 cards in the stack to match the image and keep performance high
    int displayCount = widget.docs.length > 3 ? 3 : widget.docs.length;
    List<Widget> stackItems = [];

    // The precise visual stacking as shown in image_0.png
    // i=0 is the top card (closest to you, front)
    // i=2 is the third card (furthest away, back of the pile)

    // Increased gap to show more height of the background cards as shown in image_0.png
    const double stackGap = 45.0;

    // Calculate the maximum offset so we can push the front card down from the top edge
    // This anchors the background cards at the top
    double maxTopOffset = (displayCount - 1) * stackGap;

    // Build the stack from back (furthest) to front (top) to handle Z-indexing correctly
    for (int i = displayCount - 1; i >= 0; i--) {
      // Calculate which document index to show for each stacked card layer
      int docIndex = (_currentIndex + i) % widget.docs.length;
      var doc = widget.docs[docIndex];

      bool isTopCard = (i == 0); // Is this the card receiving gestures?

      // Math flipped from standard 'expand' to 'stack behind above' layout
      // Top position calculation pushes the front card *down* and keeps back cards *high*
      double topOffset = maxTopOffset - (i * stackGap);

      // Scale math is standard, larger index i = smaller scale (furthest back)
      double scale = 1.0 - (i * 0.07);

      // Apply drag offset directly to the top card only while dragging
      if (isTopCard) {
        topOffset += _dragOffset;
      }

      stackItems.add(
        AnimatedPositioned(
          key: ValueKey(doc), // Crucial key to animate card shuffling correctly
          duration: isTopCard && _dragOffset != 0
              ? Duration
                    .zero // Instant follow while dragging
              : const Duration(
                  milliseconds: 350,
                ), // Smooth spring animation on release or shuffling
          curve: Curves.easeOutCubic,
          top: topOffset, // Calculated top position
          left: 0,
          right: 0,
          child: AnimatedScale(
            duration: isTopCard && _dragOffset != 0
                ? Duration.zero
                : const Duration(milliseconds: 350),
            scale: scale, // Calculated scale per stack level
            alignment:
                Alignment.topCenter, // Anchors the scale effect at the top
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: WalletCard(
                doc: doc,
                index: docIndex,
                onFav: widget.onFav,
                onTap: () => widget.onTap(doc),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 16),

        // ─── CARD COUNTER (TOP RIGHT) ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentIndex + 1} of ${widget.docs.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),
        Expanded(
          // Gesture detector around the whole stack area
          child: GestureDetector(
            behavior:
                HitTestBehavior.translucent, // Captures drag outside exact card
            onVerticalDragUpdate: _onPanUpdate, // Active tracking
            onVerticalDragEnd: _onPanEnd, // Threshold detection
            child: Center(
              child: SizedBox(
                width: cardWidth,
                // Total height covers the card height + max stack depth + padding
                height: cardHeight + maxTopOffset + 20,
                child: Stack(
                  clipBehavior:
                      Clip.none, // Allows top cards to pop out during animation
                  children: stackItems, // Built back-to-front
                ),
              ),
            ),
          ),
        ),
        // Existing animated hint text component
        AnimatedBuilder(
          animation: _hintAnim,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, _hintAnim.value),
            child: child,
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.black.withOpacity(0.2),
                  size: 22,
                ),
                const SizedBox(height: 2),
                Text(
                  'Swipe down to browse', // Text updated from the full text file
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.25),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
