import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/components/card_widgets.dart';
import 'package:qwallet_mobileapp/model/credential_model.dart';

class StackView extends StatefulWidget {
  final List<CredentialModel> docs;
  final Set<String> favIds;
  final void Function(String) onFav;
  final void Function(CredentialModel) onTap;

  const StackView({
    super.key,
    required this.docs,
    required this.favIds,
    required this.onFav,
    required this.onTap,
  });

  @override
  State<StackView> createState() => StackViewState();
}

class StackViewState extends State<StackView>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  double _dragOffset = 0.0;

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

  void _onPanUpdate(DragUpdateDetails details) {
    if (widget.docs.length <= 1) return;
    setState(() {
      _dragOffset += details.delta.dy;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (widget.docs.length <= 1) return;

    if (_dragOffset > 60 || details.primaryVelocity! > 300) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.docs.length;
      });
    } else if (_dragOffset < -60 || details.primaryVelocity! < -300) {
      setState(() {
        _currentIndex =
            (_currentIndex - 1 + widget.docs.length) % widget.docs.length;
      });
    }

    setState(() {
      _dragOffset = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.docs.isEmpty) return const EmptyDocsState();

    final cardWidth = MediaQuery.of(context).size.width - 48;
    const cardHeight = 240.0;

    int displayCount = widget.docs.length > 3 ? 3 : widget.docs.length;
    List<Widget> stackItems = [];

    const double stackGap = 45.0;
    double maxTopOffset = (displayCount - 1) * stackGap;

    for (int i = displayCount - 1; i >= 0; i--) {
      int docIndex = (_currentIndex + i) % widget.docs.length;
      var doc = widget.docs[docIndex];
      bool isTopCard = (i == 0);

      double topOffset = maxTopOffset - (i * stackGap);
      double scale = 1.0 - (i * 0.07);

      if (isTopCard) {
        topOffset += _dragOffset;
      }

      stackItems.add(
        AnimatedPositioned(
          key: ValueKey(doc.credentialID),
          duration: isTopCard && _dragOffset != 0
              ? Duration.zero
              : const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          top: topOffset,
          left: 0,
          right: 0,
          child: AnimatedScale(
            duration: isTopCard && _dragOffset != 0
                ? Duration.zero
                : const Duration(milliseconds: 350),
            scale: scale,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: WalletCard(
                doc: doc,
                isFav: widget.favIds.contains(doc.credentialID),
                onFav: () => widget.onFav(doc.credentialID),
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
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: _onPanUpdate,
            onVerticalDragEnd: _onPanEnd,
            child: Center(
              child: SizedBox(
                width: cardWidth,
                height: cardHeight + maxTopOffset + 20,
                child: Stack(clipBehavior: Clip.none, children: stackItems),
              ),
            ),
          ),
        ),
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
                  'Swipe down to browse',
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
