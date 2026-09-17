import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qwallet_mobileapp/Headers/QPageTitle.dart';
import 'package:qwallet_mobileapp/services/crypto_service.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _teamMembers = [
    ('Mohammed Bin Ali Maqqavi', 'Project Manager'),
    ('Mohammed Abdul Haris', 'Frontend Lead'),
    ('Mohammed Nihal', 'Technical Lead'),
    ('Mohammed Obied', 'Blockchain Specialist'),
  ];

  void _showTeamDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: const Icon(
                      Icons.groups,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QChain v2.0.0',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Meet the team',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Divider(color: Colors.white.withOpacity(0.08), height: 1),
              const SizedBox(height: 18),

              ..._teamMembers.map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF1E1E1E),
                        child: Text(
                          member.$1.split(' ').map((w) => w[0]).take(2).join(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.$1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              member.$2,
                              style: const TextStyle(
                                color: Color(0xFF888888),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: qSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: qPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.25),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.logout,
                  color: Color(0xFFEF4444),
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Log Out',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your wallet and credentials remain\nsecurely stored on your device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        // TODO: clear session → Get.offAllNamed(Routes.SPLASH)
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Log Out',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPublicKeysDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _PublicKeysDialog(),
    );
  }

  static const _sections = [
    (
      'Security',
      [
        (Icons.lock, 'Biometric Lock — On'),
        (Icons.change_circle, 'Change PIN'),
        (Icons.key, 'View My Public Key'),
      ],
    ),
    (
      'Backup',
      [(Icons.backup, 'Backup Wallet'), (Icons.restore, 'Restore from Backup')],
    ),
    ('Appearance', [(Icons.dark_mode, 'Theme — Dark')]),
    (
      'About',
      [
        (Icons.info, 'QChain v2.0.0'),
        (Icons.lock_person, 'Algorithm: CRYSTALS-Dilithium3'),
        (Icons.article, 'Documentation'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          // ── BLACK HERO BOX ──────────────────────────────────────────
          _SettingsHeroBox(),

          // ── SCROLLABLE SECTIONS ─────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                ..._sections.map((section) {
                  final (title, items) = section;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 10),
                          child: Text(
                            title.toUpperCase(),
                            style: const TextStyle(
                              color: qPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFEBEBEB)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x06000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            children: items.asMap().entries.map((e) {
                              final (IconData icon, String label) = e.value;
                              final isLast = e.key == items.length - 1;
                              return _SettingsTile(
                                icon: icon,
                                label: label,
                                isLast: isLast,
                                onTap: label == 'QChain v2.0.0'
                                    ? () => _showTeamDialog(context)
                                    : label == 'View My Public Key'
                                        ? () => _showPublicKeysDialog(context)
                                        : () {},
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // ── Log Out ─────────────────────────────────────────
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _showLogoutDialog(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, color: Color(0xFFEF4444), size: 18),
                        SizedBox(width: 9),
                        Text(
                          'Log Out',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO BOX — Profile lives here
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsHeroBox extends StatelessWidget {
  const _SettingsHeroBox();

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
          // Screen label
          // const Text(
          //   'Settings',
          //   style: TextStyle(
          //     color: Color(0xFF888888),
          //     fontSize: 13,
          //     letterSpacing: 0.2,
          //   ),
          // ),
          // const SizedBox(height: 2),
          // const Text(
          //   'Your Account',
          //   style: TextStyle(
          //     color: Colors.white,
          //     fontSize: 24,
          //     fontWeight: FontWeight.w800,
          //     letterSpacing: -0.5,
          //   ),
          // ),
          QPageTitle(mainTitle: "Settings", subTitle: "Your Account"),

          const SizedBox(height: 22),

          // Profile card inside hero
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: qBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF222222)),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: qBg,
                    border: Border.all(
                      color: const Color(0xFF444444),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'A',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Name + DID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ahmed Salih',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'did:fabric:0x3f...8a2c',
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.35),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),

                // Edit icon button
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: qBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: qText),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.edit_outlined,
                    color: Colors.black.withOpacity(0.6),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),


        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS TILE
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLast;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: !isLast
              ? const Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: const Color(0xFF333333), size: 17),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: qPrimary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC KEYS DIALOG — same style as the QChain v2.0.0 team dialog
// ─────────────────────────────────────────────────────────────────────────────
class _PublicKeysDialog extends StatefulWidget {
  const _PublicKeysDialog();

  @override
  State<_PublicKeysDialog> createState() => _PublicKeysDialogState();
}

class _PublicKeysDialogState extends State<_PublicKeysDialog> {
  bool _loading = true;
  String? _kemPubHex;
  String? _dsaPubHex;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final keys = await CryptoService.readAllPublicKeys();
    if (!mounted) return;
    setState(() {
      _kemPubHex = keys.kemPubHex;
      _dsaPubHex = keys.dsaPubHex;
      _loading = false;
    });
  }

  String _truncate(String hex, {int head = 28, int tail = 20}) {
    if (hex.length <= head + tail + 3) return hex;
    return '${hex.substring(0, head)}…${hex.substring(hex.length - tail)}';
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF111111),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: const Icon(Icons.key, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Public Keys',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Registered with QChain',
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: Colors.white.withOpacity(0.08), height: 1),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            else ...[
              _PublicKeyBlock(
                title: 'ML-KEM-768',
                value: _kemPubHex,
                truncated: _kemPubHex == null || _kemPubHex!.isEmpty
                    ? null
                    : _truncate(_kemPubHex!),
                onCopy: _kemPubHex == null || _kemPubHex!.isEmpty
                    ? null
                    : () => _copy('KEM public key', _kemPubHex!),
              ),
              const SizedBox(height: 14),
              _PublicKeyBlock(
                title: 'ML-DSA-44',
                value: _dsaPubHex,
                truncated: _dsaPubHex == null || _dsaPubHex!.isEmpty
                    ? null
                    : _truncate(_dsaPubHex!),
                onCopy: _dsaPubHex == null || _dsaPubHex!.isEmpty
                    ? null
                    : () => _copy('DSA public key', _dsaPubHex!),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: qSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: qPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicKeyBlock extends StatelessWidget {
  final String title;
  final String? value;
  final String? truncated;
  final VoidCallback? onCopy;

  const _PublicKeyBlock({
    required this.title,
    required this.value,
    required this.truncated,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final missing = value == null || value!.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onCopy != null)
              GestureDetector(
                onTap: onCopy,
                child: const Icon(
                  Icons.copy_rounded,
                  color: Color(0xFF888888),
                  size: 16,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: SelectableText(
            missing
                ? 'Not found — complete onboarding first'
                : '${value!.length} hex chars (${value!.length ~/ 2} bytes)\n$truncated',
            style: TextStyle(
              color: missing ? const Color(0xFFEF4444) : Colors.white,
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}