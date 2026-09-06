import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/Headers/QPageTitle.dart';
import 'package:qwallet_mobileapp/components/emptyState.dart';
import 'package:qwallet_mobileapp/components/shimmerWave.dart';
import 'package:qwallet_mobileapp/skeletons/addDoc_skeleton.dart';
import 'package:qwallet_mobileapp/utils/app_config.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';
import 'package:qwallet_mobileapp/widgets/QSearchBar.dart';
import 'package:qwallet_mobileapp/model/catalog_model.dart';
import 'package:qwallet_mobileapp/controllers/add_document_controller.dart';
import 'package:qwallet_mobileapp/services/app_api_service.dart';
import 'package:qwallet_mobileapp/controllers/wallet_controller.dart';

class AddDocumentScreen extends StatefulWidget {
  const AddDocumentScreen({super.key});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final AddDocumentController controller = Get.put(AddDocumentController());
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDocSheet(
    BuildContext context,
    CatalogIssuer issuer,
    CatalogService service,
  ) {
    bool isFetching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Container(
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 40,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBEBEB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Header
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: issuer.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.file_present_rounded,
                      color: issuer.color,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    issuer.name,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Data Fields Preview
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DETAILS',
                          style: TextStyle(
                            color: Color(0xFFAAAAAA),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SheetInfoRow(
                          icon: Icons.info_outline,
                          label: 'Description',
                          value: service.description,
                        ),
                        const SizedBox(height: 12),
                        const _SheetInfoRow(
                          icon: Icons.security,
                          label: 'Verification',
                          value: 'QChain Blockchain',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Action Area
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      MediaQuery.of(context).padding.bottom + 16,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFEBEBEB))),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: isFetching
                              ? null
                              : () async {
                                  setStateSheet(() => isFetching = true);

                                  try {
                                    // Call the API
                                    final walletCtrl =
                                        Get.find<WalletController>();
                                    final result = await ApiService.fetchDocument(
                                      userEmiratesID,
                                      issuer.id,
                                      service.name,
                                      // service.id
                                    );

                                    setStateSheet(() => isFetching = false);

                                    if (context.mounted) Navigator.pop(ctx);

                                    if (result['success'] == true) {
                                      walletCtrl.fetchMyCredentials();
                                      Get.snackbar(
                                        'Success',
                                        'Document added to your wallet!',
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: Colors.green,
                                        colorText: Colors.white,
                                      );
                                    } else {
                                      Get.snackbar(
                                        'Not Found',
                                        result['message'],
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: Colors.redAccent,
                                        colorText: Colors.white,
                                      );
                                    }
                                  } catch (e) {
                                    setStateSheet(() => isFetching = false);
                                    if (context.mounted) Navigator.pop(ctx);
                                    Get.snackbar(
                                      'Network Error',
                                      e.toString(),
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: qRed,
                                      colorText: Colors.white,
                                    );
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF111111),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isFetching
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Fetch Document',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF000000),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 16,
              24,
              28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                QPageTitle(
                  mainTitle: 'Explore',
                  subTitle: 'Find and fetch new documents',
                ),
                const SizedBox(height: 20),
                QSearchBar(
                  controller: _searchController,
                  onChanged: (v) {},
                  textInside: 'Search issuers or documents...',
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: Obx(() {
              // ─── SKELETON LOADING INJECTION ───
              if (controller.isLoading.value) {
                return const SkeletonExploreList();
              }

              final filtered = controller.getFilteredCategories(_query);

              if (filtered.isEmpty) {
                return EmptyState(
                  query: _query,
                  mainMessage: "No organizations found",
                  subMessage:
                      'Organizations offering credentials will appear here',
                  resultMainMessage: 'No results found',
                  resultSubMessage: 'Nothing matches "$_query"',
                );
              }

              return RefreshIndicator(
                color: qPrimary,
                onRefresh: () async {
                  await controller.loadCatalog();
                  if (controller.errorMessage.value.isNotEmpty) {
                    Get.snackbar(
                      'Network Error',
                      controller.errorMessage.value,
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: qRed,
                      colorText: qSecondary,
                    );
                  }
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final cat = filtered[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Header
                          Row(
                            children: [
                              Icon(
                                cat.icon,
                                size: 20,
                                color: const Color(0xFF111111),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                cat.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Issuers List
                          ...cat.issuers.map((issuer) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFEBEBEB),
                                ),
                              ),
                              child: Theme(
                                data: Theme.of(
                                  context,
                                ).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  childrenPadding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: issuer.color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.business,
                                      color: issuer.color,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    issuer.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111111),
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${issuer.services.length} documents available',
                                    style: const TextStyle(
                                      color: Color(0xFFAAAAAA),
                                      fontSize: 12,
                                    ),
                                  ),
                                  children: issuer.services.map((service) {
                                    return GestureDetector(
                                      onTap: () => _showDocSheet(
                                        context,
                                        issuer,
                                        service,
                                      ),
                                      child: Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF7F7F7),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFEEEEEE),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.file_copy_outlined,
                                              size: 16,
                                              color: issuer.color,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                service.name,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF111111),
                                                ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.add_circle_outline,
                                              size: 20,
                                              color: Color(0xFFAAAAAA),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SheetInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SheetInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: qBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFAAAAAA), size: 15),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
          ),
          const Spacer(),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
