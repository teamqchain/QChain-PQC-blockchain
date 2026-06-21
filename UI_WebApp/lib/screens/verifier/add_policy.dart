// screens/verifier/add_policy_page.dart
//
// Add Policies — select up to 3 policies to apply during credential validation.
// Accessible from QR scan, manual, and batch validation flows.
//
// Layout:
//   Padding → Column
//     Title (fixed)
//     Added Policies container  — fixed height (header + up to 3 rows)
//     SizedBox(14)
//     Policy Bucket container   — Expanded, scrollable, checkboxes
//     SizedBox(14)
//     Action bar — Back · Add (N) · Confirm
//
// Both containers follow the exact same toolbar/header/row pattern as
// verification_history_page.dart.
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   case RouteName.addPolicy:
//     return AddPolicyPage(
//       onBack:    () => _handleNavigate(/* previous route */),
//       onConfirm: (policies) => _handleNavigate(/* next step */),
//     );

import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/filterButton.dart';
import 'package:qportal_webapp/components/searchBar.dart';
import 'package:qportal_webapp/models/VERIFIER/policy_model.dart';
import 'package:qportal_webapp/screens/verifier/policies_page.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/components/appButton.dart';

const int _kMaxPolicies = 3;

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class AddPolicyPage extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(List<PolicyRecord> added) onConfirm;
  final List<PolicyRecord> initialAdded;

  const AddPolicyPage({
    super.key,
    required this.onBack,
    required this.onConfirm,
    this.initialAdded = const [],
  });

  @override
  State<AddPolicyPage> createState() => _AddPolicyPageState();
}

class _AddPolicyPageState extends State<AddPolicyPage> {
  late final List<PolicyRecord> _added;
  late final List<PolicyRecord> _bucket;

  String _bucketQuery = '';
  final _searchCtrl = TextEditingController();

  final Set<String> _bucketSelected = {};

  // ── derived ───────────────────────────────────────────────────────────────
  int get _slotsRemaining => _kMaxPolicies - _added.length;
  int get _selectableLeft => _slotsRemaining - _bucketSelected.length;
  bool get _addEnabled => _bucketSelected.isNotEmpty;
  bool get _confirmEnabled => _added.isNotEmpty;

  String get _addLabel {
    final n = _bucketSelected.length;
    return n == 0 ? 'Add' : 'Add ($n)';
  }

  List<PolicyRecord> get _filteredBucket {
    final q = _bucketQuery.toLowerCase().trim();
    if (q.isEmpty) return _bucket;
    return _bucket
        .where(
          (p) =>
              p.id.toLowerCase().contains(q) ||
              p.policyName.toLowerCase().contains(q) ||
              p.appliesTo.toLowerCase().contains(q) ||
              p.status.label.toLowerCase().contains(q),
        )
        .toList();
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final addedIds = widget.initialAdded.map((p) => p.id).toSet();
    _added = List.from(widget.initialAdded);
    _bucket = kMockPolicies
        .where((p) => !addedIds.contains(p.id) && p.status == PolicyStatus.active)
        .toList();
  }

  // ── actions ───────────────────────────────────────────────────────────────
  void _toggleBucket(PolicyRecord p) {
    setState(() {
      if (_bucketSelected.contains(p.id)) {
        _bucketSelected.remove(p.id);
      } else if (_selectableLeft > 0) {
        _bucketSelected.add(p.id);
      }
    });
  }

  void _onAdd() {
    if (_bucketSelected.isEmpty) return;
    setState(() {
      final toAdd = _bucket
          .where((p) => _bucketSelected.contains(p.id))
          .toList();
      _bucket.removeWhere((p) => _bucketSelected.contains(p.id));
      _added.addAll(toAdd);
      _bucketSelected.clear();
    });
  }

  void _removeAdded(PolicyRecord p) {
    setState(() {
      _added.remove(p);
      _bucket.insert(0, p);
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ────────────────────────────────────────────────────────
          Text(
            'Add Policies',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // ── Added Policies — standalone container ────────────────────────
          _AddedPoliciesTable(added: _added, onRemove: _removeAdded),
          const SizedBox(height: 14),

          // ── Policy Bucket — standalone container, fills remaining space ──
          Expanded(
            child: _BucketTable(
              bucket: _filteredBucket,
              allBucket: _bucket,
              selected: _bucketSelected,
              selectableLeft: _selectableLeft,
              slotsRemaining: _slotsRemaining,
              query: _bucketQuery,
              searchCtrl: _searchCtrl,
              onToggle: _toggleBucket,
              onSearchChanged: (v) => setState(() => _bucketQuery = v),
              onClearSearch: () {
                _searchCtrl.clear();
                setState(() => _bucketQuery = '');
              },
            ),
          ),
          const SizedBox(height: 14),

          // ── Action bar ───────────────────────────────────────────────────
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Back
        AppButton(
          icon: Icons.arrow_back_rounded,
          label: 'Back',
          showBorder: true,
          borderColor: AppColors.border,
          hoverColor: AppColors.surfaceHover,
          onTap: widget.onBack,
        ),
        const SizedBox(width: 10),

        // Add (N)
        AppButton(
          icon: Icons.add_rounded,
          label: _addLabel,
          // backgroundColor: _addEnabled
          //     ? AppColors.verifyingAccent
          //     : Colors.transparent,
          hoverColor: _addEnabled
              ? AppColors.verifyingDark.withOpacity(0.82)
              : Colors.transparent,
          showBorder: true,
          borderColor: AppColors.verifyingAccent,
          disabledBorderColor: AppColors.border,
          textColor: _addEnabled ? AppColors.verifyingAccent : AppColors.textDim,
          iconColor: _addEnabled ? AppColors.verifyingAccent : AppColors.textDim,
          // disabledBackgroundColor: AppColors.verifyingAccent.withOpacity(0.25),
          enabled: _addEnabled,
          tooltip: _addEnabled
              ? null
              : _slotsRemaining == 0
              ? 'Maximum of $_kMaxPolicies policies already added'
              : 'Select policies from the bucket below',
          onTap: _onAdd,
        ),
        const SizedBox(width: 10),

        // Confirm
        AppButton(
          icon: Icons.check_rounded,
          label: 'Confirm',
          backgroundColor: _confirmEnabled
              ? AppColors.verifyingAccent
              : Colors.transparent,
          hoverColor: _confirmEnabled
              ? AppColors.verifyingAccent.withOpacity(0.82)
              : Colors.transparent,
          showBorder: !_confirmEnabled,
          borderColor: AppColors.border,
          disabledBorderColor: AppColors.border,
          textColor: _confirmEnabled ? AppColors.white : AppColors.textDim,
          iconColor: _confirmEnabled ? AppColors.white : AppColors.textDim,
          disabledBackgroundColor: AppColors.verifyingAccent.withOpacity(0.25),
          enabled: _confirmEnabled,
          tooltip: _confirmEnabled ? null : 'Add at least one policy first',
          onTap: () => widget.onConfirm(_added),
        ),

        // Inline selection hint
        if (_bucketSelected.isNotEmpty) ...[
          const SizedBox(width: 16),
          Container(width: 1, height: 18, color: AppColors.border),
          const SizedBox(width: 14),
          Text(
            '${_bucketSelected.length} selected  ·  '
            '$_slotsRemaining slot${_slotsRemaining == 1 ? '' : 's'} remaining',
            style: AppTextStyles.bodyTiny.copyWith(
              fontSize: 11,
              color: AppColors.textDim,
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ADDED POLICIES TABLE
// ═════════════════════════════════════════════════════════════════════════════

class _AddedPoliciesTable extends StatelessWidget {
  final List<PolicyRecord> added;
  final void Function(PolicyRecord) onRemove;

  const _AddedPoliciesTable({required this.added, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolbar(),
          Container(height: 1, color: AppColors.border),
          _buildHeader(),
          Container(height: 1, color: AppColors.border),
          _buildBody(),
        ],
      ),
    );
  }

  // ── Toolbar — mirrors _HistoryTable._buildToolbar() ───────────────────────
  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF161616),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Count label
          Expanded(
            child: Text(
              added.isEmpty
                  ? 'No policies added yet'
                  : '${added.length} of $_kMaxPolicies added',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: added.isEmpty
                    ? AppColors.textDim
                    : AppColors.verifyingAccent,
              ),
            ),
          ),

          // Slot pip indicators (● ● ●)
          Row(
            children: List.generate(_kMaxPolicies, (i) {
              final filled = i < added.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? AppColors.verifyingAccent
                      : Colors.transparent,
                  border: Border.all(
                    color: filled
                        ? AppColors.verifyingAccent
                        : AppColors.borderLight,
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Header — identical tint + typography to _HistoryTable._buildHeader() ─
  Widget _buildHeader() {
    return Container(
      color: AppColors.verifyingAccent.withOpacity(0.22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          // Dot column placeholder (28px matches dot in rows)
          const SizedBox(width: 28),
          _th('POLICY ID', flex: 2),
          const SizedBox(width: 12),
          _th('POLICY NAME', flex: 5),
          const SizedBox(width: 12),
          _th('APPLIES TO', flex: 3),
          const SizedBox(width: 60),
          _th('CREATED BY', flex: 2),
          const SizedBox(width: 12),
          _th('STATUS', flex: 2),
          // Delete icon column placeholder (40px)
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (added.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: AppColors.textDim,
            ),
            const SizedBox(width: 8),
            Text(
              'Select policies from the bucket below and press Add.',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                color: AppColors.textDim,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < added.length; i++) ...[
          _AddedRow(policy: added[i], onRemove: () => onRemove(added[i])),
          if (i < added.length - 1)
            Container(height: 1, color: AppColors.border),
        ],
      ],
    );
  }

  Widget _th(String label, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(
      label,
      style: AppTextStyles.bodyTiny.copyWith(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: AppColors.white,
      ),
    ),
  );
}

// ─── ADDED ROW ────────────────────────────────────────────────────────────────

class _AddedRow extends StatefulWidget {
  final PolicyRecord policy;
  final VoidCallback onRemove;
  const _AddedRow({required this.policy, required this.onRemove});
  @override
  State<_AddedRow> createState() => _AddedRowState();
}

class _AddedRowState extends State<_AddedRow> {
  bool _hovered = false;
  bool _deleteHovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.policy;
    final fg = p.status.fg;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered
            ? AppColors.verifyingAccent.withOpacity(0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            // Green dot — 28px column
            SizedBox(
              width: 28,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.verifyingAccent,
                ),
              ),
            ),

            // Policy ID
            Expanded(
              flex: 2,
              child: Text(
                p.id,
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: AppColors.verifyingLight,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),

            // Policy Name
            Expanded(
              flex: 5,
              child: Text(
                p.policyName,
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),

            // Applies To
            Expanded(flex: 3, child: AppliesToBadge(label: p.appliesTo)),
            const SizedBox(width: 60),

            // Created By
            Expanded(
              flex: 2,
              child: Text(
                p.createdBy,
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 11,
                  color: AppColors.textDim,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),

            // Status
            Expanded(
              flex: 2,
              child: _StatusBadge(fg: fg, label: p.status.label),
            ),

            // Delete — 40px
            SizedBox(
              width: 40,
              child: Center(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _deleteHovered = true),
                  onExit: (_) => setState(() => _deleteHovered = false),
                  child: GestureDetector(
                    onTap: widget.onRemove,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _deleteHovered
                            ? AppColors.revoked.withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _deleteHovered
                              ? AppColors.revoked.withOpacity(0.4)
                              : Colors.transparent,
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: _deleteHovered
                            ? AppColors.revoked
                            : AppColors.revoked,
                      ),
                    ),
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

// ═════════════════════════════════════════════════════════════════════════════
//  POLICY BUCKET TABLE
// ═════════════════════════════════════════════════════════════════════════════

class _BucketTable extends StatelessWidget {
  final List<PolicyRecord> bucket;
  final List<PolicyRecord> allBucket;
  final Set<String> selected;
  final int selectableLeft;
  final int slotsRemaining;
  final String query;
  final TextEditingController searchCtrl;
  final void Function(PolicyRecord) onToggle;
  final void Function(String) onSearchChanged;
  final VoidCallback onClearSearch;

  const _BucketTable({
    required this.bucket,
    required this.allBucket,
    required this.selected,
    required this.selectableLeft,
    required this.slotsRemaining,
    required this.query,
    required this.searchCtrl,
    required this.onToggle,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          _buildToolbar(),
          Container(height: 1, color: AppColors.border),
          _buildHeader(),
          Container(height: 1, color: AppColors.border),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────
  Widget _buildToolbar() {
    final selCount = selected.length;
    return Container(
      color: const Color(0xFF161616),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Count / selection
          Expanded(
            child: Text(
              selCount > 0
                  ? '$selCount of ${allBucket.length} selected'
                  : '${allBucket.length} policies available',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selCount > 0 ? AppColors.verifyingAccent : Colors.white,
              ),
            ),
          ),

          // Slot hint
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(
              slotsRemaining == 0
                  ? 'Maximum reached'
                  : 'Select up to $slotsRemaining more',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                color: slotsRemaining == 0
                    ? AppColors.revoked.withOpacity(0.7)
                    : AppColors.textDim,
              ),
            ),
          ),

          // Filter icon
          ToolbarIconBtn(
            icon: Icons.filter_list_rounded,
            tooltip: 'Filter',
            onTap: () {},
          ),
          const SizedBox(width: 6),

          // Search bar
          QSearchBar(
            controller: searchCtrl,
            query: query,
            onChanged: onSearchChanged,
            onClear: onClearSearch,
            barWidth: 260,
            searchLabel: 'Search by name, category, status…',
            activeColor: AppColors.verifyingAccent,
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: AppColors.verifyingAccent.withOpacity(0.22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          // Checkbox column (32px — matches SizedBox in rows)
          const SizedBox(width: 32),
          _th('POLICY ID', flex: 2),
          const SizedBox(width: 12),
          _th('POLICY NAME', flex: 5),
          const SizedBox(width: 12),
          _th('APPLIES TO', flex: 3),
          const SizedBox(width: 80),
          _th('CREATED BY', flex: 2),
          const SizedBox(width: 12),
          _th('STATUS', flex: 2),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (allBucket.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.done_all_rounded,
              size: 32,
              color: AppColors.verifyingAccent,
            ),
            const SizedBox(height: 10),
            Text(
              'All available policies have been added.',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                color: AppColors.textDim,
              ),
            ),
          ],
        ),
      );
    }

    if (bucket.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 32,
              color: AppColors.textDim,
            ),
            const SizedBox(height: 10),
            Text(
              'No results for "$query".',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                color: AppColors.textDim,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: bucket.length,
      separatorBuilder: (_, __) =>
          Container(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final p = bucket[i];
        final isSelected = selected.contains(p.id);
        final canSelect = isSelected || selectableLeft > 0;
        return _BucketRow(
          policy: p,
          isSelected: isSelected,
          canSelect: canSelect,
          onTap: () => onToggle(p),
        );
      },
    );
  }

  Widget _th(String label, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(
      label,
      style: AppTextStyles.bodyTiny.copyWith(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: AppColors.white,
      ),
    ),
  );
}

// ─── BUCKET ROW ───────────────────────────────────────────────────────────────

class _BucketRow extends StatefulWidget {
  final PolicyRecord policy;
  final bool isSelected;
  final bool canSelect;
  final VoidCallback onTap;

  const _BucketRow({
    required this.policy,
    required this.isSelected,
    required this.canSelect,
    required this.onTap,
  });

  @override
  State<_BucketRow> createState() => _BucketRowState();
}

class _BucketRowState extends State<_BucketRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.policy;
    final isSelected = widget.isSelected;
    final canSelect = widget.canSelect;
    final fg = p.status.fg;

    return MouseRegion(
      cursor: canSelect ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: canSelect ? widget.onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: (!canSelect && !isSelected) ? 0.38 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            color: isSelected
                ? AppColors.verifyingAccent.withOpacity(0.07)
                : _hovered && canSelect
                ? AppColors.surfaceHover
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                // Checkbox (32px)
                SizedBox(
                  width: 32,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: canSelect ? (_) => widget.onTap() : null,
                    activeColor: AppColors.verifyingAccent,
                    side: const BorderSide(color: AppColors.border),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),

                // Policy ID
                Expanded(
                  flex: 2,
                  child: Text(
                    p.id,
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: AppColors.verifyingLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),

                // Policy Name
                Expanded(
                  flex: 5,
                  child: Text(
                    p.policyName,
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),

                // Applies To
                Expanded(flex: 3, child: AppliesToBadge(label: p.appliesTo)),
                const SizedBox(width: 80),

                // Created By
                Expanded(
                  flex: 2,
                  child: Text(
                    p.createdBy,
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 11,
                      color: AppColors.textDim,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),

                // Status
                Expanded(
                  flex: 2,
                  child: _StatusBadge(fg: fg, label: p.status.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHARED BADGE WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// class _AppliesToBadge extends StatelessWidget {
//   final String label;
//   const _AppliesToBadge({required this.label});

//   @override
//   Widget build(BuildContext context) => Container(
//     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//     decoration: BoxDecoration(
//       color: AppColors.surfaceHover,
//       borderRadius: BorderRadius.circular(5),
//       border: Border.all(color: AppColors.borderLight),
//     ),
//     child: Text(
//       label,
//       style: AppTextStyles.bodyTiny.copyWith(
//         fontSize: 10,
//         fontWeight: FontWeight.w600,
//         color: AppColors.textMuted,
//         letterSpacing: 0.2,
//       ),
//       overflow: TextOverflow.ellipsis,
//     ),
//   );
// }

class _StatusBadge extends StatelessWidget {
  final Color fg;
  final String label;
  const _StatusBadge({required this.fg, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: fg.withOpacity(0.12),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: fg.withOpacity(0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: fg,
            letterSpacing: 0.4,
          ),
        ),
      ],
    ),
  );
}

