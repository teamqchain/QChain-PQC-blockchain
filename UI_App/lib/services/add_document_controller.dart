import 'package:get/get.dart';
import 'package:qwallet_mobileapp/model/catalog_model.dart';
import 'package:qwallet_mobileapp/services/app_api_service.dart';
import 'package:qwallet_mobileapp/utils/logger.dart';

class AddDocumentController extends GetxController {
  var categories = <CatalogCategory>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    logDebug('[AddDocumentController] onInit called');
    loadCatalog();
  }

  Future<void> loadCatalog() async {
    logDebug('[AddDocumentController] loadCatalog started');
    try {
      isLoading(true);
      errorMessage('');
      final data = await ApiService.getCatalog();
      categories.value = data;
      logDebug(
        '[AddDocumentController] loadCatalog success: ${categories.length} categories loaded',
      );
    } on ConnectionException catch (e) {
      logDebug('[AddDocumentController] loadCatalog ConnectionException: ${e.message}');
      errorMessage(e.message);
    } catch (e) {
      logDebug('[AddDocumentController] loadCatalog exception: $e');
      errorMessage('Failed to load issuer directory.');
    } finally {
      isLoading(false);
    }
  }

  // Returns a filtered catalog based on the search query
  List<CatalogCategory> getFilteredCategories(String query) {
    if (query.trim().isEmpty) return categories;

    logDebug(
      '[AddDocumentController] getFilteredCategories called with query: "$query"',
    );
    final q = query.toLowerCase();
    List<CatalogCategory> result = [];

    for (var cat in categories) {
      // Filter issuers within the category
      final matchingIssuers = cat.issuers.where((issuer) {
        final matchesIssuer = issuer.name.toLowerCase().contains(q);
        final matchesService = issuer.services.any(
          (s) => s.name.toLowerCase().contains(q),
        );
        return matchesIssuer || matchesService;
      }).toList();

      // If category matches name OR has matching issuers, include it
      if (cat.name.toLowerCase().contains(q) || matchingIssuers.isNotEmpty) {
        result.add(
          CatalogCategory(
            name: cat.name,
            // If category name matched exactly, show all issuers. Otherwise, show only matching issuers.
            issuers: cat.name.toLowerCase().contains(q)
                ? cat.issuers
                : matchingIssuers,
          ),
        );
      }
    }
    logDebug(
      '[AddDocumentController] getFilteredCategories returning ${result.length} categories',
    );
    return result;
  }
}
