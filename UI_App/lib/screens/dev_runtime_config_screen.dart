import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qwallet_mobileapp/Headers/QPageTitle.dart';
import 'package:qwallet_mobileapp/routes/app_routes.dart';
import 'package:qwallet_mobileapp/services/app_api_service.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';
import 'package:qwallet_mobileapp/utils/app_config.dart';
import 'package:qwallet_mobileapp/utils/runtime_config.dart';

/// Boot-only screen: paste backend base URL and/or pick a holder.
/// Opened via Splash logo double-tap only (D4). Save pops to Splash (D7).
/// Always available in release (D5). No mid-session entry (D8).
///
/// STORE GATE — before App Store / production: remove the Splash logo
/// double-tap that navigates here (and re-gate Alice). Do not ship this
/// screen as a reachable route in production builds.
class DevRuntimeConfigScreen extends StatefulWidget {
  const DevRuntimeConfigScreen({super.key});

  @override
  State<DevRuntimeConfigScreen> createState() => _DevRuntimeConfigScreenState();
}

class _DevRuntimeConfigScreenState extends State<DevRuntimeConfigScreen> {
  final _urlCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _manualEidCtrl = TextEditingController();

  List<Map<String, dynamic>> _holders = [];
  String? _selectedEid;
  bool _loadingHolders = false;
  bool _testing = false;
  String? _testMessage;
  bool _testOk = false;
  String? _holdersError;

  @override
  void initState() {
    super.initState();
    final cfg = RuntimeConfig.to;
    _urlCtrl.text = cfg.apiBaseUrl;
    _selectedEid = cfg.emiratesID;
    _manualEidCtrl.text = cfg.emiratesID;
    // Prefill only — holders load when the user presses Test connection.
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _searchCtrl.dispose();
    _manualEidCtrl.dispose();
    super.dispose();
  }

  /// Pending URL field for Test only — RuntimeConfig is written on Save.
  String get _pendingBase => _urlCtrl.text.trim();

  /// Search against the last tested base. No-op if URL is empty (list stays
  /// empty until Test connection succeeds).
  Future<void> _searchHolders(String search) async {
    if (_pendingBase.isEmpty) {
      setState(() {
        _holders = [];
        _holdersError = null;
        _loadingHolders = false;
      });
      return;
    }
    setState(() {
      _loadingHolders = true;
      _holdersError = null;
    });
    try {
      final rows = await ApiService.getHolders(
        search: search,
        baseUrlOverride: _pendingBase,
      );
      if (!mounted) return;
      setState(() {
        _holders = rows;
        _loadingHolders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _holders = [];
        _loadingHolders = false;
        _holdersError = e is ConnectionException
            ? e.message
            : 'Failed to load holders.';
      });
    }
  }

  /// Only path that populates the holder list after a URL change.
  Future<void> _testConnection() async {
    if (_pendingBase.isEmpty) {
      setState(() {
        _testing = false;
        _testOk = false;
        _testMessage = 'Paste a backend URL first.';
        _holders = [];
        _holdersError = null;
      });
      return;
    }
    setState(() {
      _testing = true;
      _loadingHolders = true;
      _testMessage = null;
      _holdersError = null;
    });
    try {
      final rows = await ApiService.getHolders(
        search: _searchCtrl.text,
        timeout: const Duration(seconds: 5),
        baseUrlOverride: _pendingBase,
      );
      if (!mounted) return;
      setState(() {
        _testing = false;
        _loadingHolders = false;
        _testOk = true;
        _testMessage = 'OK — ${rows.length} holder(s)';
        _holders = rows;
        _holdersError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _loadingHolders = false;
        _testOk = false;
        _testMessage = e is ConnectionException
            ? e.message
            : 'Connection failed.';
        // Stale list from a previous base must not linger on a failed test.
        _holders = [];
        _holdersError = null;
      });
    }
  }

  /// Clears the URL field and the holders list. Does not write RuntimeConfig.
  void _clearUrl() {
    setState(() {
      _urlCtrl.clear();
      _searchCtrl.clear();
      _holders = [];
      _holdersError = null;
      _testMessage = null;
      _testOk = false;
      _loadingHolders = false;
      _testing = false;
    });
  }

  void _onSelectHolder(Map<String, dynamic> row) {
    final eid = (row['emiratesID'] ?? '').toString().trim();
    if (eid.isEmpty) return;
    setState(() {
      _selectedEid = eid;
      _manualEidCtrl.text = eid;
    });
  }

  void _onSave() {
    final cfg = RuntimeConfig.to;
    // Partial override is valid (plan §2.2): URL and/or holder.
    cfg.setApiBaseUrl(_urlCtrl.text);
    final manual = _manualEidCtrl.text.trim();
    final eid = manual.isNotEmpty ? manual : (_selectedEid ?? '');
    cfg.setEmiratesID(eid);
    HapticFeedback.lightImpact();
    // D7 — back to Splash; user taps Get Started with the new effective config.
    Get.offAllNamed(Routes.SPLASH);
  }

  void _onReset() {
    RuntimeConfig.to.reset();
    setState(() {
      _urlCtrl.text = kApiBaseUrl;
      _selectedEid = userEmiratesID;
      _manualEidCtrl.text = userEmiratesID;
      _searchCtrl.clear();
      _holders = [];
      _testMessage = null;
      _holdersError = null;
      _testOk = false;
    });
    // Holders reload only after Test connection (same as a fresh paste).
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: qBgSurface,
      body: Column(
        children: [
          _buildHero(topPad),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _sectionLabel('BACKEND URL'),
                const SizedBox(height: 10),
                _buildUrlCard(),
                const SizedBox(height: 22),
                _sectionLabel('HOLDER'),
                const SizedBox(height: 10),
                _buildHolderCard(),
                const SizedBox(height: 28),
                _buildActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(double topPad) {
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
      child: Row(
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
          Expanded(
            child: QPageTitle(
              mainTitle: 'Dev Runtime Config',
              subTitle: 'Session only · kill app resets',
              mainFontSize: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: qPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildUrlCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Exact paste — no auto /api. Trim + one trailing slash stripped.',
            style: TextStyle(color: qSub, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlCtrl,
            style: const TextStyle(
              color: qPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'https://host/api',
              hintStyle: const TextStyle(color: qSub, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: qBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: qBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: qPrimary),
              ),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            // Enter runs the same path as the Test button (loads holders).
            onSubmitted: (_) {
              if (!_testing) _testConnection();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _testConnection,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: qPrimary,
                    side: const BorderSide(color: qBorder),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Test connection'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _clearUrl,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: qRed,
                    side: const BorderSide(color: qRed),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Clear URL'),
                ),
              ),
            ],
          ),
          if (_testMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _testMessage!,
              style: TextStyle(
                color: _testOk ? qValid : qRed,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHolderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchCtrl,
            onSubmitted: (v) => _searchHolders(v),
            style: const TextStyle(color: qPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search holders…',
              hintStyle: const TextStyle(color: qSub, fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 18, color: qSub),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: qBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: qBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: qPrimary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingHolders)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_holdersError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _holdersError!,
                style: const TextStyle(color: qRed, fontSize: 12),
              ),
            )
          else if (_holders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Press Test connection to load holders for this URL.',
                style: TextStyle(color: qSub, fontSize: 12),
              ),
            )
          else
            ..._holders.map(_holderTile),
          const SizedBox(height: 14),
          const Text(
            'Manual Emirates ID (fallback)',
            style: TextStyle(color: qSub, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _manualEidCtrl,
            onChanged: (v) {
              setState(() => _selectedEid = v.trim().isEmpty ? null : v.trim());
            },
            style: const TextStyle(
              color: qPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: '784-YYYY-XXXXXXX-X',
              hintStyle: const TextStyle(color: qSub, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: qBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: qBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: qPrimary),
              ),
            ),
            keyboardType: TextInputType.text,
            autocorrect: false,
          ),
        ],
      ),
    );
  }

  Widget _holderTile(Map<String, dynamic> row) {
    final name = (row['fullName'] ?? '').toString();
    final eid = (row['emiratesID'] ?? '').toString();
    final activated = row['isWalletActivated'] == true;
    final selected = eid == _selectedEid;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFF0F0F0) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _onSelectHolder(row),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? qPrimary : qBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: selected ? qPrimary : qSub,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Unknown' : name,
                        style: const TextStyle(
                          color: qPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        eid,
                        style: const TextStyle(color: qSub, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (!activated)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: qAmberBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'inactive',
                      style: TextStyle(
                        color: qAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: qPrimary,
              foregroundColor: qBg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Save and continue',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _onReset,
            style: OutlinedButton.styleFrom(
              foregroundColor: qPrimary,
              side: const BorderSide(color: qBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Reset to build defaults',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Overrides last until process death. Keychain slots stay per EID.',
          textAlign: TextAlign.center,
          style: TextStyle(color: qDimmed, fontSize: 11),
        ),
      ],
    );
  }
}
