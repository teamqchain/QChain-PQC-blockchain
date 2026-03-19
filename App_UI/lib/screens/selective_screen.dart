import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/model/IdentityDoc.dart';

enum ShareMode { link, export }

class SelectiveShareScreen extends StatefulWidget {
  final IdentityDoc doc;
  final ShareMode mode;

  const SelectiveShareScreen({
    super.key,
    required this.doc,
    required this.mode,
  });

  @override
  State<SelectiveShareScreen> createState() => _SelectiveShareScreenState();
}

class _SelectiveShareScreenState extends State<SelectiveShareScreen> {
  final Map<String, bool> _visible = {
    'Document Type': true,
    'Credential ID': true,
    'Issued To': true,
    'National ID': false,
    'Issuing Authority': true,
    'Country of Issue': true,
    'Date of Issue': true,
    'Expiry Date': true,
    'Digital Signature': false,
    'Blockchain Anchor': false,
    'DID': false,
    'Verification Status': true,
  };

  @override
  Widget build(BuildContext context) {
    final isLink = widget.mode == ShareMode.link;

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
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLink ? 'Share Link' : 'Export Document',
                          style: const TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Choose what to share',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF22C55E),
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Toggled-off fields will be masked before '
                          '${isLink ? 'generating the link' : 'export'}. '
                          'Sensitive data stays on your device.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Field toggles
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              children: [
                const _ShareSectionLabel('Include in shared document'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEBEBEB)),
                  ),
                  child: Column(
                    children: _visible.keys.toList().asMap().entries.map((e) {
                      final key = e.value;
                      final isLast = e.key == _visible.length - 1;
                      return Container(
                        decoration: BoxDecoration(
                          border: !isLast
                              ? const Border(
                                  bottom: BorderSide(color: Color(0xFFF0F0F0)),
                                )
                              : null,
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0,
                          ),
                          title: Text(
                            key,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _visible[key]!
                                  ? const Color(0xFF111111)
                                  : const Color(0xFFAAAAAA),
                            ),
                          ),
                          subtitle: Text(
                            _visible[key]! ? 'Visible' : 'Hidden',
                            style: TextStyle(
                              fontSize: 11,
                              color: _visible[key]!
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFCCCCCC),
                            ),
                          ),
                          value: _visible[key]!,
                          activeThumbColor: const Color(0xFF22C55E),
                          onChanged: (v) => setState(() => _visible[key] = v),
                          inactiveThumbColor: Colors.red.shade900,
                          inactiveTrackColor: Colors.red.shade300,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Confirm button
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.of(context).padding.bottom + 20,
            ),
            child: GestureDetector(
              onTap: () {
                // TODO: perform share/export with _visible mask applied
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isLink
                                ? 'Generating shareable link…'
                                : 'Preparing export…',
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
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isLink ? Icons.link : Icons.download_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      isLink ? 'Generate Share Link' : 'Export Document',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareSectionLabel extends StatelessWidget {
  final String text;
  const _ShareSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFFAAAAAA),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}
