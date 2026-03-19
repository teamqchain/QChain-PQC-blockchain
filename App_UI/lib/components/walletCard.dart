// // individual cards in stack view

// import 'package:flutter/material.dart';
// import 'package:qwallet_mobileapp/model/IdentityDoc.dart';

// class WalletCard extends StatelessWidget {
//   final IdentityDoc doc;
//   final int index;
//   final void Function(int) onFav;
//   final VoidCallback onTap;

//   const WalletCard({
//     required this.doc,
//     required this.index,
//     required this.onFav,
//     required this.onTap,
//     super.key,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         decoration: BoxDecoration(
//           color: doc.cardColor,
//           borderRadius: BorderRadius.circular(28),
//           boxShadow: [
//             BoxShadow(
//               color: doc.cardColor.withOpacity(0.45),
//               blurRadius: 28,
//               offset: const Offset(0, 12),
//             ),
//             BoxShadow(
//               color: Colors.black.withOpacity(0.18),
//               blurRadius: 12,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Stack(
//           clipBehavior: Clip.hardEdge,
//           children: [
//             // ── Decorative gradient overlay ────────────────────────────
//             Positioned.fill(
//               child: Container(
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(28),
//                   gradient: LinearGradient(
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                     colors: [
//                       Colors.white.withOpacity(0.08),
//                       Colors.transparent,
//                       Colors.black.withOpacity(0.12),
//                     ],
//                     stops: const [0.0, 0.5, 1.0],
//                   ),
//                 ),
//               ),
//             ),

//             // ── Large watermark emoji ──────────────────────────────────
//             Positioned(
//               right: -18,
//               bottom: -18,
//               child: Opacity(
//                 opacity: 0.07,
//                 child: Text(doc.emoji, style: const TextStyle(fontSize: 140)),
//               ),
//             ),

//             // ── Top-left shine orb ────────────────────────────────────
//             Positioned(
//               top: -50,
//               left: -30,
//               child: Container(
//                 width: 160,
//                 height: 160,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   gradient: RadialGradient(
//                     colors: [
//                       Colors.white.withOpacity(0.12),
//                       Colors.transparent,
//                     ],
//                   ),
//                 ),
//               ),
//             ),

//             // ── Card content ───────────────────────────────────────────
//             Padding(
//               padding: const EdgeInsets.all(24),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Top row: icon + fav button
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       // Doc type icon
//                       Container(
//                         width: 48,
//                         height: 48,
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.13),
//                           borderRadius: BorderRadius.circular(14),
//                           border: Border.all(
//                             color: Colors.white.withOpacity(0.2),
//                           ),
//                         ),
//                         alignment: Alignment.center,
//                         child: Text(
//                           doc.emoji,
//                           style: const TextStyle(fontSize: 24),
//                         ),
//                       ),

//                       // Fav button
//                       GestureDetector(
//                         onTap: () => onFav(index),
//                         child: AnimatedContainer(
//                           duration: const Duration(milliseconds: 220),
//                           width: 36,
//                           height: 36,
//                           decoration: BoxDecoration(
//                             color: doc.isFavourite
//                                 ? Colors.amber.withOpacity(0.18)
//                                 : Colors.white.withOpacity(0.1),
//                             shape: BoxShape.circle,
//                             border: Border.all(
//                               color: doc.isFavourite
//                                   ? Colors.amber.withOpacity(0.5)
//                                   : Colors.white.withOpacity(0.18),
//                             ),
//                           ),
//                           alignment: Alignment.center,
//                           child: Icon(
//                             doc.isFavourite ? Icons.star : Icons.star_border,
//                             color: doc.isFavourite
//                                 ? Colors.amber
//                                 : Colors.white54,
//                             size: 17,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),

//                   const Spacer(),

//                   // Title — now white to match ListCard
//                   Text(
//                     doc.title,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 20,
//                       fontWeight: FontWeight.w800,
//                       letterSpacing: -0.5,
//                     ),
//                   ),
//                   const SizedBox(height: 3),
//                   Text(
//                     doc.subtitle,
//                     style: TextStyle(
//                       color: Colors.white.withOpacity(0.5),
//                       fontSize: 11,
//                       letterSpacing: 0.1,
//                     ),
//                   ),

//                   const SizedBox(height: 20),

//                   // Bottom row: number + expiry
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 14,
//                       vertical: 10,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.black.withOpacity(0.18),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'NUMBER',
//                               style: TextStyle(
//                                 color: Colors.white.withOpacity(0.35),
//                                 fontSize: 8,
//                                 fontWeight: FontWeight.w700,
//                                 letterSpacing: 1.1,
//                               ),
//                             ),
//                             const SizedBox(height: 3),
//                             Text(
//                               doc.number,
//                               style: TextStyle(
//                                 color: Colors.white.withOpacity(0.85),
//                                 fontSize: 11,
//                                 fontWeight: FontWeight.w600,
//                                 letterSpacing: 0.3,
//                               ),
//                             ),
//                           ],
//                         ),
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.end,
//                           children: [
//                             Text(
//                               'EXPIRES',
//                               style: TextStyle(
//                                 color: Colors.white.withOpacity(0.35),
//                                 fontSize: 8,
//                                 fontWeight: FontWeight.w700,
//                                 letterSpacing: 1.1,
//                               ),
//                             ),
//                             const SizedBox(height: 3),
//                             Text(
//                               doc.expires,
//                               style: TextStyle(
//                                 color: Colors.white.withOpacity(0.85),
//                                 fontSize: 11,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
