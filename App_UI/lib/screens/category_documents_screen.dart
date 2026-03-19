import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/Headers/categoryHeader.dart';
import 'package:qwallet_mobileapp/components/CardDetails.dart';
import 'package:qwallet_mobileapp/components/card_widgets.dart';
import 'package:qwallet_mobileapp/model/IdentityDoc.dart';
import 'package:qwallet_mobileapp/model/wallet_category.dart';
import 'package:qwallet_mobileapp/view/listView.dart';
import 'package:qwallet_mobileapp/view/stackView.dart';

class CategoryDocumentsScreen extends StatefulWidget {
  const CategoryDocumentsScreen({super.key});

  @override
  State<CategoryDocumentsScreen> createState() =>
      _CategoryDocumentsScreenState();
}

class _CategoryDocumentsScreenState extends State<CategoryDocumentsScreen> {
  bool _isStackView = true;
  IdentityDoc? _openedDoc;

  late WalletCategory _category;
  late List<IdentityDoc> _categoryDocs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _category = Get.arguments as WalletCategory;
    _categoryDocs = allDocs
        .where((doc) => doc.category == _category.id)
        .toList();
  }

  void _toggleFav(int index) {
    setState(() {
      _categoryDocs[index].isFavourite = !_categoryDocs[index].isFavourite;
    });
  }

  void _openCard(IdentityDoc doc) => setState(() => _openedDoc = doc);
  void _closeCard() => setState(() => _openedDoc = null);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          Column(
            children: [
              Header(
                category: _category,
                isStackView: _isStackView,
                onToggleView: () =>
                    setState(() => _isStackView = !_isStackView),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _isStackView
                      ? StackView(
                          key: const ValueKey('stack'),
                          docs: _categoryDocs,
                          onFav: _toggleFav,
                          onTap: _openCard,
                        )
                      : DocListView(
                          key: const ValueKey('list'),
                          docs: _categoryDocs,
                          onFav: _toggleFav,
                          onTap: _openCard,
                        ),
                ),
              ),
            ],
          ),

          // ── BLUR + CARD DETAIL OVERLAY ──────────────────────────────────
          if (_openedDoc != null)
            CardDetailOverlay(doc: _openedDoc!, onClose: _closeCard),
        ],
      ),
    );
  }
}
