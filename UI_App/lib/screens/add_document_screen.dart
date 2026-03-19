import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/constants/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _Service {
  final String name;
  final String description;
  final String estimatedTime;
  bool requested;

  _Service({
    required this.name,
    required this.description,
    required this.estimatedTime,
    this.requested = false,
  });
}

class _Issuer {
  final String name;
  final String emoji;
  final Color color;
  final List<_Service> services;

  const _Issuer({
    required this.name,
    required this.emoji,
    required this.color,
    required this.services,
  });
}

class _Category {
  final String name;
  final IconData icon;
  final List<_Issuer> issuers;

  const _Category({
    required this.name,
    required this.icon,
    required this.issuers,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DUMMY DATA
// ─────────────────────────────────────────────────────────────────────────────

final _dummyCategories = [
  _Category(
    name: 'Government',
    icon: Icons.account_balance,
    issuers: [
      _Issuer(
        name: 'Ministry of Interior',
        emoji: '🇦🇪',
        color: const Color(0xFF1D4ED8),
        services: [
          _Service(
            name: 'Emirates ID',
            description: 'National identity document issued by ICA.',
            estimatedTime: '3–5 business days',
          ),
          _Service(
            name: 'Residency Permit',
            description: 'Proof of legal residency in the UAE.',
            estimatedTime: '5–7 business days',
          ),
        ],
      ),
      _Issuer(
        name: 'Road & Transport Authority',
        emoji: '🚗',
        color: const Color(0xFF0F766E),
        services: [
          _Service(
            name: 'Driving Licence',
            description: 'UAE driving licence credential.',
            estimatedTime: '1–2 business days',
          ),
          _Service(
            name: 'Vehicle Registration',
            description: 'Digital vehicle registration card.',
            estimatedTime: '1 business day',
          ),
        ],
      ),
    ],
  ),
  _Category(
    name: 'Education',
    icon: Icons.school,
    issuers: [
      _Issuer(
        name: 'University of Sharjah',
        emoji: '🎓',
        color: const Color(0xFF7C3AED),
        services: [
          _Service(
            name: 'Degree Certificate',
            description: 'Official bachelor/master/PhD degree credential.',
            estimatedTime: '7–10 business days',
          ),
          _Service(
            name: 'Course Certificate',
            description: 'Completion certificate for a specific course.',
            estimatedTime: '2–3 business days',
          ),
          _Service(
            name: 'Enrollment Letter',
            description: 'Proof of active enrollment.',
            estimatedTime: 'Same day',
          ),
        ],
      ),
      _Issuer(
        name: 'American University of Sharjah',
        emoji: '🏛️',
        color: const Color(0xFFB45309),
        services: [
          _Service(
            name: 'Degree Certificate',
            description: 'Official AUS degree credential.',
            estimatedTime: '7–10 business days',
          ),
          _Service(
            name: 'Transcript',
            description: 'Official academic transcript.',
            estimatedTime: '3–5 business days',
          ),
        ],
      ),
    ],
  ),
  _Category(
    name: 'Banking',
    icon: Icons.credit_card,
    issuers: [
      _Issuer(
        name: 'HSBC UAE',
        emoji: '🏦',
        color: const Color(0xFFDC2626),
        services: [
          _Service(
            name: 'Bank Statement',
            description: 'Verified 6-month bank statement.',
            estimatedTime: '1 business day',
          ),
          _Service(
            name: 'Account Ownership Proof',
            description: 'Certified proof of account ownership.',
            estimatedTime: 'Same day',
          ),
          _Service(
            name: 'Credit Report',
            description: 'Official credit score and history.',
            estimatedTime: '2–3 business days',
          ),
        ],
      ),
      _Issuer(
        name: 'Emirates NBD',
        emoji: '💳',
        color: const Color(0xFFD97706),
        services: [
          _Service(
            name: 'Bank Statement',
            description: 'Verified Emirates NBD bank statement.',
            estimatedTime: '1 business day',
          ),
          _Service(
            name: 'Salary Certificate',
            description: 'Employer salary confirmation via bank.',
            estimatedTime: '2 business days',
          ),
        ],
      ),
    ],
  ),
  _Category(
    name: 'Healthcare',
    icon: Icons.local_hospital,
    issuers: [
      _Issuer(
        name: 'Cleveland Clinic Abu Dhabi',
        emoji: '🏥',
        color: const Color(0xFF0891B2),
        services: [
          _Service(
            name: 'Medical Report',
            description: 'Certified medical summary report.',
            estimatedTime: '3–5 business days',
          ),
          _Service(
            name: 'Vaccination Record',
            description: 'Official immunisation history.',
            estimatedTime: '1 business day',
          ),
        ],
      ),
      _Issuer(
        name: 'Ministry of Health UAE',
        emoji: '⚕️',
        color: const Color(0xFF16A34A),
        services: [
          _Service(
            name: 'Health Insurance Card',
            description: 'Digital UAE health insurance credential.',
            estimatedTime: '2–3 business days',
          ),
        ],
      ),
    ],
  ),
  _Category(
    name: 'Employment',
    icon: Icons.work,
    issuers: [
      _Issuer(
        name: 'Ministry of Human Resources',
        emoji: '💼',
        color: const Color(0xFF4F46E5),
        services: [
          _Service(
            name: 'Work Permit',
            description: 'UAE work permit / labour card.',
            estimatedTime: '5–7 business days',
          ),
          _Service(
            name: 'Employment Contract',
            description: 'Ministry-attested employment contract.',
            estimatedTime: '3–5 business days',
          ),
        ],
      ),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AddDocumentScreen extends StatefulWidget {
  const AddDocumentScreen({super.key});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  // Track which categories and issuers are expanded
  final Set<int> _expandedCategories = {0};
  final Set<String> _expandedIssuers = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_Category> get _filtered {
    if (_query.isEmpty) return _dummyCategories;
    return _dummyCategories
        .map((cat) {
          final matchedIssuers = cat.issuers
              .map((issuer) {
                final matchedServices = issuer.services
                    .where(
                      (s) =>
                          s.name.toLowerCase().contains(_query) ||
                          s.description.toLowerCase().contains(_query),
                    )
                    .toList();
                if (issuer.name.toLowerCase().contains(_query) ||
                    matchedServices.isNotEmpty) {
                  return _Issuer(
                    name: issuer.name,
                    emoji: issuer.emoji,
                    color: issuer.color,
                    services: issuer.name.toLowerCase().contains(_query)
                        ? issuer.services
                        : matchedServices,
                  );
                }
                return null;
              })
              .whereType<_Issuer>()
              .toList();

          if (cat.name.toLowerCase().contains(_query) ||
              matchedIssuers.isNotEmpty) {
            return _Category(
              name: cat.name,
              icon: cat.icon,
              issuers: cat.name.toLowerCase().contains(_query)
                  ? cat.issuers
                  : matchedIssuers,
            );
          }
          return null;
        })
        .whereType<_Category>()
        .toList();
  }

  void _requestService(_Service service, _Issuer issuer) {
    setState(() => service.requested = true);
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestConfirmSheet(
        service: service,
        issuer: issuer,
        parentContext: parentContext,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          // ── HERO BOX ────────────────────────────────────────────────
          _AddDocHeroBox(controller: _searchController, query: _query),

          // ── BODY ────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? _EmptySearch(query: _query)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    itemCount: filtered.length,
                    itemBuilder: (context, catIndex) {
                      final cat = filtered[catIndex];
                      final isCatExpanded =
                          _query.isNotEmpty ||
                          _expandedCategories.contains(catIndex);

                      return _CategorySection(
                        category: cat,
                        isExpanded: isCatExpanded,
                        expandedIssuers: _expandedIssuers,
                        onCategoryTap: () => setState(() {
                          if (_expandedCategories.contains(catIndex)) {
                            _expandedCategories.remove(catIndex);
                          } else {
                            _expandedCategories.add(catIndex);
                          }
                        }),
                        onIssuerTap: (key) => setState(() {
                          if (_expandedIssuers.contains(key)) {
                            _expandedIssuers.remove(key);
                          } else {
                            _expandedIssuers.add(key);
                          }
                        }),
                        onRequest: _requestService,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO BOX
// ─────────────────────────────────────────────────────────────────────────────

class _AddDocHeroBox extends StatelessWidget {
  final TextEditingController controller;
  final String query;

  const _AddDocHeroBox({required this.controller, required this.query});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back + title
          Row(
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A1A1A),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Services',
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Add Document',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Search bar + QR scanner button
          Row(
            children: [
              // Search
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: qBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2E2E2E)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(
                        Icons.search,
                        color: Colors.black.withOpacity(0.35),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search issuers or documents…',
                            hintStyle: TextStyle(
                              color: Colors.black.withOpacity(0.25),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          cursorColor: Colors.white,
                        ),
                      ),
                      if (query.isNotEmpty)
                        GestureDetector(
                          onTap: () => controller.clear(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(
                              Icons.close,
                              color: Colors.white.withOpacity(0.4),
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // QR Scanner button
              GestureDetector(
                onTap: () {
                  // TODO: open QR scanner
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2E2E2E)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white.withOpacity(0.8),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final _Category category;
  final bool isExpanded;
  final Set<String> expandedIssuers;
  final VoidCallback onCategoryTap;
  final void Function(String) onIssuerTap;
  final void Function(_Service, _Issuer) onRequest;

  const _CategorySection({
    required this.category,
    required this.isExpanded,
    required this.expandedIssuers,
    required this.onCategoryTap,
    required this.onIssuerTap,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Category header ──
          GestureDetector(
            onTap: onCategoryTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: isExpanded
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      )
                    : BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEBEBEB)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      category.icon,
                      color: const Color(0xFF111111),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category.name,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${category.issuers.length}',
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFFAAAAAA),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Issuer list (animated) ──
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: const Border(
                  left: BorderSide(color: Color(0xFFEBEBEB)),
                  right: BorderSide(color: Color(0xFFEBEBEB)),
                  bottom: BorderSide(color: Color(0xFFEBEBEB)),
                ),
              ),
              child: Column(
                children: category.issuers.asMap().entries.map((e) {
                  final issuer = e.value;
                  final key = '${category.name}::${issuer.name}';
                  final isIssuerExpanded = expandedIssuers.contains(key);
                  final isLast = e.key == category.issuers.length - 1;

                  return _IssuerTile(
                    issuer: issuer,
                    isExpanded: isIssuerExpanded,
                    isLast: isLast,
                    onTap: () => onIssuerTap(key),
                    onRequest: (service) => onRequest(service, issuer),
                  );
                }).toList(),
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ISSUER TILE
// ─────────────────────────────────────────────────────────────────────────────

class _IssuerTile extends StatelessWidget {
  final _Issuer issuer;
  final bool isExpanded;
  final bool isLast;
  final VoidCallback onTap;
  final void Function(_Service) onRequest;

  const _IssuerTile({
    required this.issuer,
    required this.isExpanded,
    required this.isLast,
    required this.onTap,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Issuer header row
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              border: (!isLast || isExpanded)
                  ? const Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))
                  : null,
            ),
            child: Row(
              children: [
                // Coloured emoji avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: issuer.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: issuer.color.withOpacity(0.2)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    issuer.emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issuer.name,
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${issuer.services.length} service${issuer.services.length == 1 ? '' : 's'} available',
                        style: const TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFFCCCCCC),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Services list
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            children: issuer.services.asMap().entries.map((e) {
              final service = e.value;
              final isLastService = e.key == issuer.services.length - 1;
              return _ServiceRow(
                service: service,
                issuerColor: issuer.color,
                isLast: isLastService && isLast,
                onRequest: () => onRequest(service),
              );
            }).toList(),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE ROW
// ─────────────────────────────────────────────────────────────────────────────

class _ServiceRow extends StatelessWidget {
  final _Service service;
  final Color issuerColor;
  final bool isLast;
  final VoidCallback onRequest;

  const _ServiceRow({
    required this.service,
    required this.issuerColor,
    required this.isLast,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: !isLast
            ? const Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left accent line
          Container(
            width: 3,
            height: 42,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: issuerColor.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Service info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  service.description,
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      color: Color(0xFFCCCCCC),
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      service.estimatedTime,
                      style: const TextStyle(
                        color: Color(0xFFCCCCCC),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Request / Requested button
          GestureDetector(
            onTap: service.requested ? null : onRequest,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: service.requested
                    ? const Color(0xFFF0F0F0)
                    : const Color(0xFF111111),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                service.requested ? 'Requested' : 'Request',
                style: TextStyle(
                  color: service.requested
                      ? const Color(0xFFAAAAAA)
                      : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY SEARCH STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptySearch extends StatelessWidget {
  final String query;
  const _EmptySearch({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: const Text('🔍', style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No results found',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No issuers or services match "$query"',
            style: const TextStyle(
              color: Color(0xFF999999),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REQUEST CONFIRM BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _RequestConfirmSheet extends StatelessWidget {
  final _Service service;
  final _Issuer issuer;
  final BuildContext parentContext;

  const _RequestConfirmSheet({
    required this.service,
    required this.issuer,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Issuer row
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: issuer.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: issuer.color.withOpacity(0.2)),
                ),
                alignment: Alignment.center,
                child: Text(issuer.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    issuer.name,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Info rows
          _SheetInfoRow(
            icon: Icons.schedule,
            label: 'Estimated Time',
            value: service.estimatedTime,
          ),
          const SizedBox(height: 10),
          _SheetInfoRow(
            icon: Icons.lock_outline,
            label: 'Verified on',
            value: 'QChain Blockchain',
          ),
          const SizedBox(height: 10),
          _SheetInfoRow(
            icon: Icons.notifications_outlined,
            label: 'Notification',
            value: 'You\'ll be notified when ready',
          ),

          const SizedBox(height: 24),

          // Confirm button
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(parentContext).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Request sent to ${issuer.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF16A34A),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_outlined, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Request',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
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
        border: Border.all(color: const Color(0xFFEEEEEE)),
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
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
