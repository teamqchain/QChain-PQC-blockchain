import 'package:flutter/material.dart';

class Toast extends StatefulWidget {
  final String message;
  final VoidCallback onDone;
  final IconData toastIcons;
  final Color iconColor;
  final Color bgColor;

  const Toast({super.key, 
    required this.message,
    required this.onDone,
    required this.bgColor,
    required this.iconColor,
    required this.toastIcons,
  });

  @override
  State<Toast> createState() => _ToastState();
}

class _ToastState extends State<Toast> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide; // 1. Add this slide animation variable

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 320,
      ), // Increased slightly to match ReceiptToast's smoother timing
    );

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    // 2. Initialize the slide animation
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.4), // Starts slightly above
      end: Offset.zero, // Moves down to its final position
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        // Added a mounted check (good practice before running animations in delayed futures!)
        _ctrl.reverse().then((_) => widget.onDone());
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    // bottom: 50,
    left: 150,
    right: 0,
    top: 100,
    child: Center(
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          // 3. Add the SlideTransition here
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: widget.bgColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.toastIcons, size: 14, color: widget.iconColor),
                  const SizedBox(width: 8),
                  Text(
                    widget.message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
