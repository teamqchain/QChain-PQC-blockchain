import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/components/card_widgets.dart';
import 'package:qwallet_mobileapp/model/credential_model.dart';

class DocListView extends StatelessWidget {
  final List<CredentialModel> docs;
  final Set<String> favIds;
  final void Function(String) onFav;
  final void Function(CredentialModel) onTap;

  const DocListView({
    super.key,
    required this.docs,
    required this.favIds,
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
      itemBuilder: (_, i) => ListCard(
        doc: docs[i],
        isFav: favIds.contains(docs[i].credentialID),
        onFav: () => onFav(docs[i].credentialID),
        onTap: () => onTap(docs[i]),
      ),
    );
  }
}
