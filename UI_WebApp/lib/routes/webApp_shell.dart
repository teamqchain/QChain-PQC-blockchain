import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/sidebar.dart';
import 'package:qportal_webapp/components/topbar.dart';
import 'package:qportal_webapp/models/dashboard_Model.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/models/verifiying_models.dart';
import 'package:qportal_webapp/screens/IT%20Admin/audit_log_page.dart';
import 'package:qportal_webapp/screens/issuer/all_credentials_page.dart';
import 'package:qportal_webapp/screens/issuer/schema/create_schema_page.dart';
import 'package:qportal_webapp/screens/issuer/credentials/credential_detail_page.dart';
import 'package:qportal_webapp/screens/issuer/issue_batch_credential_page.dart';
import 'package:qportal_webapp/screens/issuer/issue_single_credential_page.dart';
import 'package:qportal_webapp/screens/issuer/schema/schema_detail_page.dart';
import 'package:qportal_webapp/screens/issuer/schemas_page.dart';
import 'package:qportal_webapp/screens/IT%20Admin/crypto_settings_page.dart';
import 'package:qportal_webapp/screens/IT%20Admin/manage_staff.dart';
import 'package:qportal_webapp/screens/IT%20Admin/new_request_page.dart';
import 'package:qportal_webapp/screens/IT%20Admin/request_capabilities_page.dart';
import 'package:qportal_webapp/screens/issuer/suspend_revoke_page.dart';
import 'package:qportal_webapp/screens/IT%20Admin/profile_management.dart';
import 'package:qportal_webapp/screens/verifier/add_policy.dart';
import 'package:qportal_webapp/screens/verifier/alert_page.dart';
import 'package:qportal_webapp/screens/verifier/batch_verify_page.dart';
import 'package:qportal_webapp/screens/verifier/create_policy_page.dart';
import 'package:qportal_webapp/screens/verifier/manual_verify_page.dart';
import 'package:qportal_webapp/screens/verifier/policies_page.dart';
import 'package:qportal_webapp/screens/verifier/result_page.dart';
import 'package:qportal_webapp/screens/verifier/scan_validation_page.dart';
import 'package:qportal_webapp/screens/verifier/subscription_page.dart';
import 'package:qportal_webapp/screens/verifier/verification_details_page.dart';
import 'package:qportal_webapp/screens/verifier/verification_history_page.dart';
import 'package:qportal_webapp/screens/verifier/view_policyDetail_page.dart';

import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/screens/dashboard_screen.dart';

import 'package:qportal_webapp/view/responsive_layout.dart';

// ─── ROUTE NAMES ─────────────────────────────────────────────────────────────

class RouteName {
  static const dashboard = '/dashboard';

  static const issueSingle = '/issue/single-credentials';
  static const issueBatch = '/issue/batch-credentials';
  static const allCredentials = '/issue/all-credentials';
  static const credentialDetail = '/issue/credential-detail';
  static const revokeSuspend = '/issue/revoke-suspend';
  static const schemas = '/issue/manage-schemas';
  static const schemaDetail = '/issue/schema-detail';
  static const createSchema = '/issue/create-schema';
  static const issuingSettings = '/issue/settings';

  // ******************************************************************************************
  static const scanQR = '/verify/scanQR';
  static const verificationResult = '/verify/verificationResult';
  static const manualVerify = '/verify/manualVerify';
  // static const uploadFile = '/verify/uploadFile';
  static const batchVerify = '/verify/batchVerify';
  static const verificationHistory = '/verify/verificationHistory';
  static const verificationDetails = '/verify/verificationDetails';
  static const subscription = '/verify/subscription';
  static const alertHistory = '/verify/alertHistory';
  static const policies = '/verify/policies';
  static const policyDetails = '/verify/policy-Details';
  static const createPolicy = '/verify/create-policy';
  static const addPolicy = '/verify/add-policy';
  static const verificationSettings = '/verify/settings';

  // ******************************************************************************************
  static const manageProfile = '/admin/manage-profile';
  static const staffAndPermissions = '/admin/manage-staffandpermissions';
  static const auditLog = '/admin/audit-log';
  static const cryptoSettings = '/admin/crypto-settings';
  static const requestCapabilities = '/admin/request-capabilities';
  static const newRequestCapabilities = '/admin/newRequest-capabilities';

  static const all = <String>[
    dashboard,
    issueSingle,
    issueBatch,
    allCredentials,
    credentialDetail,
    revokeSuspend,
    schemas,
    issuingSettings,
    // issuerProfile,
    scanQR,
    manualVerify,
    // uploadFile,
    batchVerify,
    verificationHistory,
    subscription,
    policies,
    verificationSettings,
  ];
}

// ─── ROUTE PARSER ────────────────────────────────────────────────────────────

class ShellRouteParser extends RouteInformationParser<String> {
  @override
  Future<String> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final path = routeInformation.uri.path;
    if (path == '/' || path.isEmpty) return RouteName.dashboard;
    if (RouteName.all.contains(path)) return path;
    return RouteName.dashboard;
  }

  @override
  RouteInformation? restoreRouteInformation(String configuration) {
    return RouteInformation(uri: Uri.parse(configuration));
  }
}

// ─── ROUTE GROUPS ────────────────────────────────────────────────────────────

const _issuerRoutes = {
  RouteName.issueSingle,
  RouteName.issueBatch,
  RouteName.allCredentials,
  RouteName.revokeSuspend,
  RouteName.schemas,
  RouteName.issuingSettings,
};

const _verifierRoutes = {
  RouteName.scanQR,
  RouteName.manualVerify,
  // RouteName.uploadFile,
  RouteName.batchVerify,
  RouteName.verificationHistory,
  RouteName.subscription,
  RouteName.policies,
  RouteName.verificationSettings,
};

const _ITAdminRoutes = {
  RouteName.manageProfile,
  RouteName.staffAndPermissions,
  RouteName.auditLog,
};

// ─── SHELL ROUTER DELEGATE ──────────────────────────────────────────────────

class ShellRouterDelegate extends RouterDelegate<String> with ChangeNotifier {
  String _currentRoute = RouteName.dashboard;
  DashboardVariant _variant = DashboardVariant.issuerOnly;
  int _generation = 0;

  String get currentRoute => _currentRoute;
  DashboardVariant get variant => _variant;
  int get generation => _generation;

  @override
  String get currentConfiguration => _currentRoute;

  void push(String route) {
    // Auto-switch variant so the correct sidebar section is always visible
    // and the nav item can highlight. Only switches if needed — if the user
    // is already on "both", we leave it alone.
    final neededVariant = _variantForRoute(route);
    final variantChanged = neededVariant != null && neededVariant != _variant;

    final routeChanged = route != _currentRoute;

    if (routeChanged) _currentRoute = route;
    if (variantChanged) _variant = neededVariant;
    _generation++;

    notifyListeners();
  }

  /// Returns the variant required to show the sidebar section for [route],
  /// or null if no change is needed (e.g. dashboard, or already correct).
  DashboardVariant? _variantForRoute(String route) {
    if (_issuerRoutes.contains(route) && !_variant.canIssue) {
      return DashboardVariant.issuerOnly;
    }
    if (_verifierRoutes.contains(route) && !_variant.canVerify) {
      return DashboardVariant.verifierOnly;
    }
    if (_ITAdminRoutes.contains(route) && !_variant.canManage) {
      return DashboardVariant.ITadmin;
    }
    return null; // no switch needed
  }

  void setVariant(DashboardVariant v) {
    if (v != _variant) {
      _variant = v;
      notifyListeners();
    }
  }

  @override
  Future<bool> popRoute() async => false;

  @override
  Future<void> setNewRoutePath(String configuration) async {
    // ✅ FIX: was missing notifyListeners() — without this, browser back/forward
    // and any Router-driven route change never updated _AppShellState, so the
    // sidebar never received the new activeRoute and stayed unhighlighted.
    if (_currentRoute != configuration) {
      _currentRoute = configuration;
      notifyListeners();
    }
  }

  @override
  Widget build(BuildContext context) => Navigator(
    onPopPage: (route, result) => route.didPop(result),
    pages: [
      MaterialPage(
        key: const ValueKey('shell'),
        child: _AppShell(delegate: this),
      ),
    ],
  );
}

// ─── GLOBAL INSTANCES ────────────────────────────────────────────────────────

final shellRouter = ShellRouterDelegate();
final shellRouteParser = ShellRouteParser();

class ShellNav {
  static void push(String routeName) => shellRouter.push(routeName);
}

// ─── APP SHELL ────────────────────────────────────────────────────────────────

class _AppShell extends StatefulWidget {
  final ShellRouterDelegate delegate;
  const _AppShell({required this.delegate});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  ShellRouterDelegate get _delegate => widget.delegate;
  String get _activeRoute => _delegate.currentRoute;
  DashboardVariant get _variant => _delegate.variant;

  @override
  void initState() {
    super.initState();
    _delegate.addListener(_onDelegateChanged);
  }

  @override
  void dispose() {
    _delegate.removeListener(_onDelegateChanged);
    super.dispose();
  }

  void _onDelegateChanged() {
    if (mounted) setState(() {});
  }

  String? _selectedCredentialId;
  CredentialRecord? _reissueCredential;
  String _credentialDetailReturnRoute = RouteName.allCredentials;
  VerificationResult? _selectedVerificationResult;
  String _verificationResultReturnRoute = RouteName.scanQR;

  // Stores the verification_log ID selected from the history table.
  // Used exclusively for the history → verificationDetails navigation.
  String? _selectedVerificationHistoryId;

  String? _selectedPolicyId;
  String _addPolicyReturnRoute = RouteName.manualVerify;

  void _handleNavigate(
    String route, {
    String? arg,
    CredentialRecord? reissueCred,
  }) {
    if (arg != null) _selectedCredentialId = arg;
    _reissueCredential = reissueCred;
    _delegate.push(route);
    final scaffoldState = _scaffoldKey.currentState;
    if (scaffoldState != null && scaffoldState.isDrawerOpen) {
      scaffoldState.closeDrawer();
    }
  }

  Widget _buildPage() {
    //TODO
    // All unimplemented routes fall through to dashboard.
    // The sidebar highlight still works because _activeRoute drives it — the
    // page content and the sidebar highlight are independent of each other.
    switch (_activeRoute) {
      // Uncomment as you build each screen:
      // case RouteName.issueSingle:
      //   return const IssueSingleScreen();
      // case RouteName.scanQR:
      //   return const ScanQRScreen();
      case RouteName.issueSingle:
        return IssueSingleCredentialPage(
          onCancel: () => _handleNavigate(RouteName.dashboard),
          onIssueAnother: () => _handleNavigate(RouteName.issueSingle),
          reissueFrom: _reissueCredential,
        );
      case RouteName.issueBatch:
        return IssueBatchCredentialPage(
          onCancel: () => _handleNavigate(RouteName.dashboard),
          onIssueAnotherBatch: () => _handleNavigate(RouteName.issueBatch),
        );
      case RouteName.allCredentials:
        return AllCredentialsPage(
          onViewCredential: (id) {
            _credentialDetailReturnRoute = RouteName.allCredentials;
            _handleNavigate(RouteName.credentialDetail, arg: id);
          },
        );

      case RouteName.credentialDetail:
        final credId = _selectedCredentialId ?? '';
        // Provide a placeholder credential so the page can mount and read the ID.
        // CredentialDetailPage will automatically fetch the real live details using this ID.
        final placeholderCred = CredentialRecord(
          id: credId,
          holderEmiratesID: '',
          holderName: '',
          holderEmail: '',
          holderId: '',
          credentialType: '',
          issuedBy: '',
          issueDate: '',
          status: CredentialStatus.valid,
          auditTrail: const [],
          attributes: const {},
        );
        return CredentialDetailPage(
          credential: placeholderCred,
          onClose: () => _handleNavigate(_credentialDetailReturnRoute),
          onReissue: (updated) =>
              _handleNavigate(RouteName.issueSingle, reissueCred: updated),
        );

      case RouteName.revokeSuspend:
        return RevokeSuspendPage(
          onViewCredential: (id) {
            _credentialDetailReturnRoute = RouteName.revokeSuspend;
            _handleNavigate(RouteName.credentialDetail, arg: id);
          },
        );

      case RouteName.schemas:
        return SchemasPage(
          onViewSchema: (id) =>
              _handleNavigate(RouteName.schemaDetail, arg: id),
          onCreateNewSchema: () => _handleNavigate(RouteName.createSchema),
        );

      case RouteName.schemaDetail:
        final schema = IssuingMockData.schemas.firstWhere(
          (s) => s.id == (_selectedCredentialId ?? ''),
          orElse: () => IssuingMockData.schemas.first,
        );
        return SchemaDetailPage(
          schema: schema,
          onBack: () => _handleNavigate(RouteName.schemas),
        );

      case RouteName.createSchema:
        return CreateSchemaPage(
          onCancel: () => _handleNavigate(RouteName.schemas),
          onReturnToDash: () => _handleNavigate(RouteName.dashboard),
          onAddNewSchema: () => _handleNavigate(RouteName.createSchema),
        );

      // case RouteName.issuingSettings:
      //   return IssuerSettingsPage(
      //     onManageProfile: () => _handleNavigate(RouteName.manageProfile),
      //     onStaffAndPermissions: () =>
      //         _handleNavigate(RouteName.staffAndPermissions),
      //     onCryptoSettings: () => _handleNavigate(RouteName.cryptoSettings),
      //     onRequestCapabilities: () =>
      //         _handleNavigate(RouteName.requestCapabilities),
      //   );

      // ******************************************************************************************

      case RouteName.scanQR:
        return ScanToValidatePage(
          onBack: () => _handleNavigate(RouteName.dashboard),
          onScanSuccess: (VerificationResult result) {
            _selectedVerificationResult = result; // Pass live API result here!
            _verificationResultReturnRoute = RouteName.scanQR;
            _handleNavigate(RouteName.verificationResult);
          },
        );

      case RouteName.verificationResult:
        return VerificationResultPage(
          result:
              _selectedVerificationResult ??
              VerificationResult(
                credential: null,
                invalidReason: InvalidReason.notFound,
                verifiedAt: DateTime.now().toString(),
              ),
          onVerifyAnother: () =>
              _handleNavigate(_verificationResultReturnRoute),
        );

      case RouteName.manualVerify:
        return ManualVerifyPage(
          onBack: () => _handleNavigate(RouteName.dashboard),
          onVerify: (result) {
            _selectedVerificationResult = result;
            _verificationResultReturnRoute = RouteName.manualVerify;
            _handleNavigate(RouteName.verificationResult);
          },
          onManagePolicies: () {
            _addPolicyReturnRoute = RouteName.manualVerify;
            _handleNavigate(RouteName.addPolicy);
          },
        );

      case RouteName.batchVerify:
        return BatchVerifyPage(
          onCancel: () => _handleNavigate(RouteName.dashboard),
          onVerifyAnother: () => _handleNavigate(RouteName.batchVerify),
          onManagePolicies: () {
            _addPolicyReturnRoute = RouteName.batchVerify;
            _handleNavigate(RouteName.addPolicy);
          },
        );

      case RouteName.verificationHistory:
        return VerificationHistoryPage(
          onViewVerification: (id) {
            // Store the verification log ID, then navigate to the detail page.
            // The detail page will call ApiService.getVerificationDetail(id)
            // on init to fetch all the real data for that event.
            _selectedVerificationHistoryId = id;
            _delegate.push(RouteName.verificationDetails);
            final scaffoldState = _scaffoldKey.currentState;
            if (scaffoldState != null && scaffoldState.isDrawerOpen) {
              scaffoldState.closeDrawer();
            }
          },
        );

      case RouteName.verificationDetails:
        // Pass the verification log record ID. The page fetches its own data.
        return VerificationDetailPage(
          recordId: _selectedVerificationHistoryId ?? '',
          onBack: () => _handleNavigate(RouteName.verificationHistory),
        );

      case RouteName.subscription:
        return SubscriptionPage(
          onBack: () => _handleNavigate(RouteName.dashboard),
          onAlert: (id) => _handleNavigate(RouteName.alertHistory, arg: id),
        );

      case RouteName.alertHistory:
        return AlertsPage(
          onBack: () => _handleNavigate(RouteName.subscription),
        );

      case RouteName.policies:
        return PoliciesPage(
          onBack: () => _handleNavigate(RouteName.dashboard),
          onView: (id) {
            _selectedPolicyId = id;
            _handleNavigate(RouteName.policyDetails);
          },
          onCreatePolicy: () => _handleNavigate(RouteName.createPolicy),
        );

      case RouteName.policyDetails:
        final policy = kMockPolicies.firstWhere(
          (p) => p.id == (_selectedPolicyId ?? ''),
          orElse: () => kMockPolicies.first,
        );
        return ViewPolicyPage(
          policy: policy,
          onBack: () => _handleNavigate(RouteName.policies),
        );

      case RouteName.createPolicy:
        return CreatePolicyPage(
          onCancel: () => _handleNavigate(RouteName.policies),
          onCreate: () => _handleNavigate(RouteName.policies),
        );

      case RouteName.addPolicy:
        return AddPolicyPage(
          onBack: () => _handleNavigate(_addPolicyReturnRoute),
          onConfirm: (_) => _handleNavigate(_addPolicyReturnRoute),
        );

      // ******************************************************************************************

      case RouteName.manageProfile:
        return ManageProfilePage(
          onBack: () => _handleNavigate(RouteName.dashboard),
        );

      case RouteName.staffAndPermissions:
        return ManageStaffPage(
          onBack: () => _handleNavigate(RouteName.dashboard),
        );

      case RouteName.auditLog:
        return AuditLogPage(onBack: () => _handleNavigate(RouteName.dashboard));

      case RouteName.cryptoSettings:
        return CryptoSettingsPage(
          onBack: () => _handleNavigate(RouteName.dashboard),
        );

      case RouteName.requestCapabilities:
        return RequestCapabilitiesPage(
          onBack: () => _handleNavigate(RouteName.dashboard),
          onNewRequest: () => _handleNavigate(RouteName.newRequestCapabilities),
        );

      case RouteName.newRequestCapabilities:
        return RequestNewCapabilityPage(
          onCancel: () => _handleNavigate(RouteName.requestCapabilities),
          onReturnToRequests: () =>
              _handleNavigate(RouteName.requestCapabilities),
        );

      case RouteName.dashboard:
      default:
        return DashboardScreen(
          variant: _variant,
          onVariantChanged: (v) => _delegate.setVariant(v),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final small = isSmallScreen(context);

    // ✅ sidebar receives _activeRoute fresh on every build — this is what
    // drives which nav item is highlighted. As long as _onDelegateChanged →
    // setState fires (which it now does for ALL route changes), this is correct.
    final sidebar = AppSidebar(
      variant: _variant,
      activeRoute: _activeRoute,
      onNavigate: _handleNavigate,
    );

    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: KeyedSubtree(
        key: ValueKey('${_activeRoute}_${_delegate.generation}'),
        child: _buildPage(),
      ),
    );

    if (small) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.bg,
        drawer: Drawer(
          width: 220,
          backgroundColor: Colors.transparent,
          child: sidebar,
        ),
        body: Column(
          children: [
            _SmallTopBarWithHamburger(child: AppTopBar(variant: _variant)),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sidebar,
          Expanded(
            child: Column(
              children: [
                AppTopBar(variant: _variant),
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SMALL TOP BAR + HAMBURGER ────────────────────────────────────────────────

class _SmallTopBarWithHamburger extends StatelessWidget {
  final Widget child;
  const _SmallTopBarWithHamburger({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 12,
          top: 0,
          bottom: 0,
          child: Center(
            child: _HamburgerButton(
              onTap: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
      ],
    );
  }
}

class _HamburgerButton extends StatefulWidget {
  final VoidCallback onTap;
  const _HamburgerButton({required this.onTap});

  @override
  State<_HamburgerButton> createState() => _HamburgerButtonState();
}

class _HamburgerButtonState extends State<_HamburgerButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF1A1A1A) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.menu_rounded,
            color: Color(0xFF888888),
            size: 20,
          ),
        ),
      ),
    );
  }
}