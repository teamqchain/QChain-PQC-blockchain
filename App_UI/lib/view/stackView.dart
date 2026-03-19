import 'package:flutter/material.dart';
import 'package:flutter_swiper_view/flutter_swiper_view.dart';
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

  @override
  Widget build(BuildContext context) {
    if (widget.docs.isEmpty) return const EmptyDocsState();

    final cardWidth = MediaQuery.of(context).size.width - 48;
    const cardHeight = 240.0;

    return Column(
      children: [
        const SizedBox(height: 22),
        // StackCounter(
        //   current: _currentIndex + 1,
        //   total: widget.docs.length,
        //   color: widget.docs[_currentIndex].cardColor,
        // ),
        const SizedBox(height: 18),
        Expanded(
          child: Swiper(
            itemCount: widget.docs.length,
            itemWidth: cardWidth,
            itemHeight: cardHeight,
            layout: SwiperLayout.STACK,
            scrollDirection: Axis.vertical,
            loop: true,
            onIndexChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, i) => WalletCard(
              doc: widget.docs[i],
              index: i,
              onFav: widget.onFav,
              onTap: () => widget.onTap(widget.docs[i]),
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
