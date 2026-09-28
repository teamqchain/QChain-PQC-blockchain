import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qwallet_mobileapp/Headers/QPageTitle.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';
import 'package:qwallet_mobileapp/utils/alice_inspector.dart';
import 'package:qwallet_mobileapp/utils/logger.dart';

/// In-app log console for release IPA/APK testing (same STORE GATE as Alice).
/// Shows every [logDebug]/[logError]/HTTP success+fail buffered this process.
class AppLogsScreen extends StatefulWidget {
  const AppLogsScreen({super.key});

  @override
  State<AppLogsScreen> createState() => _AppLogsScreenState();
}

class _AppLogsScreenState extends State<AppLogsScreen> {
  final _scroll = ScrollController();
  String _filter = '';

  /// Newest first so the latest events are at the top without scrolling.
  List<AppLogEntry> get _rows {
    final all = appLogEntries.reversed.toList(growable: false);
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((e) => e.line.toLowerCase().contains(q))
        .toList(growable: false);
  }

  void _copyAll() {
    // Same order as the UI (newest first) so pasted dumps match what you see.
    final text =
        appLogEntries.reversed.map((e) => e.line).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${appLogEntries.length} log line(s)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clear() {
    clearAppLogs();
    setState(() {});
    HapticFeedback.selectionClick();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final rows = _rows;
    return Scaffold(
      backgroundColor: qBgSurface,
      body: Column(
        children: [
          _hero(topPad),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _filter = v),
              style: const TextStyle(color: qPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Filter logs…',
                hintStyle: const TextStyle(color: qSub, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18, color: qSub),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: qBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: qBorder),
                ),
              ),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'No logs yet. Trigger an action, then pull to refresh.',
                      style: TextStyle(color: qSub, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: rows.length,
                      itemBuilder: (_, i) => _tile(rows[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _hero(double topPad) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, topPad + 12, 8, 20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 18),
          ),
          Expanded(
            child: QPageTitle(
              mainTitle: 'App logs',
              subTitle: '${appLogEntries.length} lines · session only',
              mainFontSize: 20,
            ),
          ),
          IconButton(
            tooltip: 'Alice HTTP',
            onPressed: aliceEnabled ? () => alice.showInspector() : null,
            icon: const Icon(Icons.network_check, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Copy all',
            onPressed: _copyAll,
            icon: const Icon(Icons.copy, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _tile(AppLogEntry e) {
    final isErr = e.level == DiagnosticLevel.error ||
        e.level == DiagnosticLevel.warning ||
        e.message.contains('[HTTP] ✗');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isErr ? qRedBg : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isErr ? qRed.withValues(alpha: 0.3) : qBorder),
      ),
      child: SelectableText(
        e.line,
        style: TextStyle(
          color: isErr ? qRed : qPrimary,
          fontSize: 11,
          fontFamily: 'Courier',
          height: 1.35,
        ),
      ),
    );
  }
}
