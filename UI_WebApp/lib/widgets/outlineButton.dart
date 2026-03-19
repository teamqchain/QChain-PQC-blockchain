// import 'package:flutter/material.dart';
// import 'package:qportal_webapp/theme/appColours.dart';
// import 'package:qportal_webapp/theme/appTextStyle.dart';
// class OutlineButton extends StatefulWidget {
//   final String label;
//   final double widthsize;
//   final VoidCallback onTap;
//   const OutlineButton({
//     required this.label,
//     required this.widthsize,
//     required this.onTap,
//   });
//   @override
//   State<OutlineButton> createState() => OutlineButtonState();
// }

// class OutlineButtonState extends State<OutlineButton> {
//   bool _hovered = false;
//   @override
//   Widget build(BuildContext context) => MouseRegion(
//     cursor: SystemMouseCursors.click,
//     onEnter: (_) => setState(() => _hovered = true),
//     onExit: (_) => setState(() => _hovered = false),
//     child: GestureDetector(
//       onTap: widget.onTap,
//       child: AnimatedContainer(
//         width: widget.widthsize,
//         height: 36,
//         duration: const Duration(milliseconds: 140),
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
//         decoration: BoxDecoration(
//           color: _hovered
//               ? AppColors.surfaceHover
//               : (widget.label == 'Cancel')
//               ? Colors.red
//               : Colors.transparent,
//           borderRadius: BorderRadius.circular(7),
//           border: Border.all(
//             color: (widget.label == 'Cancel')
//                 ? Colors.redAccent
//                 : AppColors.border,
//           ),
//         ),
//         child: Center(
//           child: Text(
//             widget.label,
//             style: AppTextStyles.bodyTiny.copyWith(
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//               color: AppColors.white,
//             ),
//           ),
//         ),
//       ),
//     ),
//   );
// }