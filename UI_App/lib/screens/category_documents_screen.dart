import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/Headers/categoryHeader.dart';
import 'package:qwallet_mobileapp/components/CardDetails.dart';
import 'package:qwallet_mobileapp/components/emptyState.dart';
import 'package:qwallet_mobileapp/model/credential_model.dart';
import 'package:qwallet_mobileapp/utils/logger.dart';
import 'package:qwallet_mobileapp/widgets/wallet_category.dart';
import 'package:qwallet_mobileapp/view/listView.dart';
import 'package:qwallet_mobileapp/view/stackView.dart';
import 'package:qwallet_mobileapp/controllers/wallet_controller.dart';

class CategoryDocumentsScreen extends StatefulWidget {
  const CategoryDocumentsScreen({super.key});

  @override
  State<CategoryDocumentsScreen> createState() =>
      _CategoryDocumentsScreenState();
}

class _CategoryDocumentsScreenState extends State<CategoryDocumentsScreen> {
  bool _isStackView = true;
  CredentialModel? _openedDoc;
  final Set<String> _localFavs = {};

  late WalletCategory _category;
  late List<CredentialModel> _categoryDocs;

  // Set the default filter to 'active' (Valid Only)
  String _currentFilter = 'active';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _category = Get.arguments as WalletCategory;
    _loadLiveDocs();
  }

  void _loadLiveDocs() {
    final controller = Get.find<WalletController>();

    var baseDocs = controller.credentials
        .where((c) => c.category == _category.id)
        .toList();

    setState(() {
      // --- ADD THIS BLOCK to sync initial favorites ---
      _localFavs.clear();
      for (var doc in baseDocs) {
        if (doc.isFavorite) {
          _localFavs.add(doc.credentialID);
        }
      }
      // ----------------------------------------------

      if (_currentFilter == 'all') {
        _categoryDocs = baseDocs;
      } else {
        _categoryDocs = baseDocs
            .where((c) => c.status.toLowerCase() == _currentFilter)
            .toList();
      }
    });
  }

  void _toggleFav(String credId) {
    // 1. Update the local UI state for instant feedback
    setState(() {
      if (_localFavs.contains(credId)) {
        _localFavs.remove(credId);
      } else {
        _localFavs.add(credId);
      }
    });

    // 2. Look up the document and trigger the API call in the controller
    final controller = Get.find<WalletController>();
    try {
      final doc = controller.credentials.firstWhere(
        (c) => c.credentialID == credId,
      );
      controller.toggleFavoriteStatus(doc);
    } catch (e) {
      logDebug('Error finding document: $e');
    }
  }

  void _openCard(CredentialModel doc) => setState(() => _openedDoc = doc);
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
                currentFilter: _currentFilter,
                onFilterChanged: (newFilter) {
                  _currentFilter = newFilter;
                  _loadLiveDocs();
                },
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
                  child: _categoryDocs.isEmpty
                      ? const EmptyState(
                          query: '',
                          mainMessage: 'No documents found',
                          subMessage: 'Try selecting a different category',
                          resultMainMessage: 'No documents match this filter',
                          resultSubMessage: 'Try selecting "All Documents"',
                        )
                      : (_isStackView
                            ? StackView(
                                key: const ValueKey('stack'),
                                docs: _categoryDocs,
                                favIds: _localFavs,
                                onFav: _toggleFav,
                                onTap: _openCard,
                              )
                            : DocListView(
                                key: const ValueKey('list'),
                                docs: _categoryDocs,
                                favIds: _localFavs,
                                onFav: _toggleFav,
                                onTap: _openCard,
                              )),
                ),
              ),
            ],
          ),

          if (_openedDoc != null)
            CardDetailOverlay(doc: _openedDoc!, onClose: _closeCard),
        ],
      ),
    );
  }
}

