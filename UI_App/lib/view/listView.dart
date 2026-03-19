// ─────────────────────────────────────────────────────────────────────────────
// listView.dart
//
// Handles the scrollable list layout for document cards.
// Card visuals (colors, text, sub-widgets) all live in card_widgets.dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/components/card_widgets.dart';
import 'package:qwallet_mobileapp/model/IdentityDoc.dart';

class DocListView extends StatelessWidget {
  final List<IdentityDoc> docs;
  final void Function(int) onFav;
  final void Function(IdentityDoc) onTap;

  const DocListView({
    super.key,
    required this.docs,
    required this.onFav,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) return const EmptyDocsState();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) =>
          ListCard(doc: docs[i], index: i, onFav: onFav, onTap: onTap),
    );
  }
}
