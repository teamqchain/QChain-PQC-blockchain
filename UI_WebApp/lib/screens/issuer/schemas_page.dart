// screens/issuer/schemas_page.dart
//
// Schemas Management — list all credential schemas with search, status
// badges, and Delete / Archive / View actions.
//
// ── Integration in app_shell.dart ───────────────────────────────────────────
//   case RouteName.schemas:
//     return SchemasPage(
//       onViewSchema: (id) => _handleNavigate(RouteName.schemaDetail, arg: id),
//     );

import 'package:flutter/material.dart';
import 'package:qportal_webapp/components/searchBar.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
import 'package:qportal_webapp/widgets/app_button.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE
// ═════════════════════════════════════════════════════════════════════════════

class SchemasPage extends StatefulWidget {
  /// Called when the user presses "View" for the selected schema.
  /// The schema detail page will be implemented later.
  final void Function(String schemaId)? onViewSchema;

  /// Called when "Add New" is pressed.
  final VoidCallback? onCreateNewSchema;

  const SchemasPage({super.key, this.onViewSchema, this.onCreateNewSchema});

  @override
  State<SchemasPage> createState() => _SchemasPageState();
}

class _SchemasPageState extends State<SchemasPage> {
  // ── mutable local copy of schemas ─────────────────────────────────────────
  late List<SchemaRecord> _schemas;
  late List<SchemaRecord> _filtered;

  String _query = '';
  final _searchCtrl = TextEditingController();
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _schemas = List<SchemaRecord>.from(IssuingMockData.schemas);
    _applyFilter();
  }

  // ── filter ─────────────────────────────────────────────────────────────────

  void _applyFilter() {
    final q = _query.toLowerCase().trim();
    _filtered = q.isEmpty
        ? List<SchemaRecord>.from(_schemas)
        : _schemas.where((s) {
            return s.name.toLowerCase().contains(q) ||
                s.category.toLowerCase().contains(q) ||
                s.description.toLowerCase().contains(q) ||
                s.schemaStatus.label.toLowerCase().contains(q);
          }).toList();
  }

  // ── selection ──────────────────────────────────────────────────────────────

  SchemaRecord? get _sel => _selectedId == null
      ? null
      : _schemas.where((s) => s.id == _selectedId).firstOrNull;

  bool get _canDelete => _sel != null && _sel!.credentialsIssued == 0;

  bool get _canArchive =>
      _sel != null && _sel!.schemaStatus == SchemaStatus.active;

  bool get _canRestore =>
      _sel != null && _sel!.schemaStatus == SchemaStatus.archived;

  bool get _canView => _sel != null;

  // ── mutations ──────────────────────────────────────────────────────────────

  void _deleteSelected() {
    if (_sel == null) return;
    final id = _sel!.id;
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        icon: Icons.delete_outline_rounded,
        iconColor: AppColors.revoked,
        title: 'Delete Schema',
        message:
            'Are you sure you want to permanently delete the schema '
            '"${_sel!.name}"? This action cannot be undone.',
        proceedLabel: 'Delete',
        proceedColor: AppColors.revoked,
        onProceed: () {
          setState(() {
            _schemas.removeWhere((s) => s.id == id);
            _selectedId = null;
            _applyFilter();
          });
        },
      ),
    );
  }

  void _archiveSelected() {
    if (_sel == null) return;
    final id = _sel!.id;
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        icon: Icons.inventory_2_outlined,
        iconColor: AppColors.suspended,
        title: 'Archive Schema',
        message:
            'Archiving "${_sel!.name}" will prevent new credentials from '
            'being issued using this schema. Previously issued credentials '
            'will not be affected.',
        proceedLabel: 'Archive',
        proceedColor: AppColors.suspended,
        onProceed: () {
          setState(() {
            final i = _schemas.indexWhere((s) => s.id == id);
            if (i >= 0) {
              final old = _schemas[i];
              _schemas[i] = SchemaRecord(
                id: old.id,
                name: old.name,
                description: old.description,
                category: old.category,
                requirements: old.requirements,
                fieldsCount: old.fieldsCount,
                credentialsIssued: old.credentialsIssued,
                isActive: false,
                fields: old.fields,
                createdDate: old.createdDate,
                schemaStatus: SchemaStatus.archived,
              );
            }
            _applyFilter();
          });
        },
      ),
    );
  }

  void _restoreSelected() {
    if (_sel == null) return;
    final id = _sel!.id;
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        icon: Icons.restore_rounded,
        iconColor: AppColors.verifyingAccent,
        title: 'Restore Schema',
        message:
            'Restoring "${_sel!.name}" will set it back to Active status. '
            'New credentials can be issued using this schema again.',
        proceedLabel: 'Restore',
        proceedColor: AppColors.verifyingAccent,
        onProceed: () {
          setState(() {
            final i = _schemas.indexWhere((s) => s.id == id);
            if (i >= 0) {
              final old = _schemas[i];
              _schemas[i] = SchemaRecord(
                id: old.id,
                name: old.name,
                description: old.description,
                category: old.category,
                requirements: old.requirements,
                fieldsCount: old.fieldsCount,
                credentialsIssued: old.credentialsIssued,
                isActive: true,
                fields: old.fields,
                createdDate: old.createdDate,
                schemaStatus: SchemaStatus.active,
              );
            }
            _applyFilter();
          });
        },
      ),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ───────────────────────────────────────────────────────
          Text(
            'Schemas',
            style: AppTextStyles.navLabelActive.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),

          // ── Main container ───────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: [
                  _buildHeader(),
                  Container(height: 1, color: AppColors.border),
                  Expanded(child: _buildList()),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Action buttons ───────────────────────────────────────────────
          _buildActionBar(),
        ],
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF161616),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          // Schema count chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.issuingAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.issuingAccent.withOpacity(0.25),
              ),
            ),
            child: Text(
              '${_schemas.length} schema${_schemas.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.issuingLight,
              ),
            ),
          ),

          const Spacer(),

          // Search bar
          QSearchBar(
            controller: _searchCtrl,
            query: _query,
            onChanged: (v) => setState(() {
              _query = v;
              _applyFilter();
            }),
            onClear: () => setState(() {
              _query = '';
              _searchCtrl.clear();
              _applyFilter();
            }),
            barWidth: 240,
            searchLabel: 'Search schemas…',
          ),
          const SizedBox(width: 10),

          // Add New
          AppButton(
            icon: Icons.add_rounded,
            label: 'Add New',
            backgroundColor: AppColors.issuingAccent,
            hoverColor: AppColors.issuingAccent.withOpacity(0.82),
            onTap: () => widget.onCreateNewSchema?.call(),
          ),
        ],
      ),
    );
  }

  // ─── LIST ──────────────────────────────────────────────────────────────────

  Widget _buildList() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _query.isEmpty ? Icons.schema_outlined : Icons.search_off_rounded,
              size: 36,
              color: AppColors.textDim,
            ),
            const SizedBox(height: 12),
            Text(
              _query.isEmpty
                  ? 'No schemas found.'
                  : 'No results for "$_query".',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 13,
                color: AppColors.textDim,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) =>
          Container(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final schema = _filtered[i];
        return _SchemaRow(
          schema: schema,
          isSelected: schema.id == _selectedId,
          onTap: () => setState(() {
            _selectedId = schema.id == _selectedId ? null : schema.id;
          }),
        );
      },
    );
  }

  // ─── ACTION BAR ────────────────────────────────────────────────────────────

  Widget _buildActionBar() {
    final sel = _sel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Delete — red, disabled when credentialsIssued > 0
        AppButton(
          label: 'Delete',
          icon: Icons.delete_outline_rounded,
          backgroundColor: AppColors.revoked,
          hoverColor: AppColors.revoked.withOpacity(0.82),
          enabled: _canDelete,
          onTap: _deleteSelected,
          disabledTextColor: AppColors.textDim,
          tooltip: sel == null
              ? 'Select a schema first'
              : sel.credentialsIssued > 0
              ? 'Cannot delete — ${sel.credentialsIssued} credentials already issued'
              : null,
        ),
        const SizedBox(width: 10),

        // Archive — amber
        AppButton(
          label: 'Archive',
          icon: Icons.inventory_2_outlined,
          backgroundColor: AppColors.suspended,
          hoverColor: AppColors.suspended.withOpacity(0.82),
          enabled: _canArchive,
          onTap: _archiveSelected,
          disabledTextColor: AppColors.textDim,
          tooltip: sel == null
              ? 'Select a schema first'
              : sel.schemaStatus == SchemaStatus.archived
              ? 'Already archived'
              : null,
        ),
        const SizedBox(width: 10),

        // Restore — green, only for archived schemas
        AppButton(
          label: 'Restore',
          icon: Icons.restore_rounded,
          backgroundColor: AppColors.verifyingAccent,
          hoverColor: AppColors.verifyingAccent.withOpacity(0.82),
          enabled: _canRestore,
          onTap: _restoreSelected,
          disabledTextColor: AppColors.textDim,
          tooltip: sel == null
              ? 'Select a schema first'
              : sel.schemaStatus == SchemaStatus.active
              ? 'Already active'
              : null,
        ),
        const SizedBox(width: 10),

        // View — outlined neutral
        AppButton(
          label: 'View',
          icon: Icons.open_in_new_rounded,
          enabled: _canView,
          onTap: () {
            if (sel != null) widget.onViewSchema?.call(sel.id);
          },
          textColor: AppColors.white,
          showBorder: true,
          borderColor: AppColors.issuingAccent,
          hoverColor: AppColors.surfaceHover,
          disabledTextColor: AppColors.textDim,
          tooltip: sel == null ? 'Select a schema first' : null,
        ),

        // Selection hint
        if (sel != null) ...[
          const SizedBox(width: 16),
          Container(width: 1, height: 18, color: AppColors.border),
          const SizedBox(width: 14),
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 12,
            color: AppColors.textDim,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${sel.name}  ·  ${sel.id}',
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 11,
                color: AppColors.textDim,
              ),
              overflow: TextOverflow.ellipsis,
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
//  SCHEMA LIST ROW
// ═════════════════════════════════════════════════════════════════════════════

class _SchemaRow extends StatefulWidget {
  final SchemaRecord schema;
  final bool isSelected;
  final VoidCallback onTap;

  const _SchemaRow({
    required this.schema,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SchemaRow> createState() => _SchemaRowState();
}

class _SchemaRowState extends State<_SchemaRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.schema;
    final archived = s.schemaStatus == SchemaStatus.archived;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: widget.isSelected
              ? AppColors.issuingAccent.withOpacity(0.07)
              : _hovered
              ? AppColors.surfaceHover
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Selection indicator stripe ─────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 3,
                height: 36,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppColors.issuingAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── LEFT — icon + name + date ──────────────────────────────
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    // Schema icon
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: archived
                            ? AppColors.textDim.withOpacity(0.08)
                            : AppColors.issuingAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: archived
                              ? AppColors.border
                              : AppColors.issuingAccent.withOpacity(0.2),
                        ),
                      ),
                      child: Icon(
                        archived
                            ? Icons.inventory_2_outlined
                            : Icons.schema_outlined,
                        size: 17,
                        color: archived
                            ? AppColors.textDim
                            : AppColors.issuingAccent,
                      ),
                    ),
                    const SizedBox(width: 13),

                    // Name + created date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: AppTextStyles.navLabelActive.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: archived
                                  ? AppColors.textMuted
                                  : AppColors.text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Created  ${s.createdDate}',
                            style: AppTextStyles.bodyTiny.copyWith(
                              fontSize: 10,
                              color: AppColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── MIDDLE — category tag + fields count ───────────────────
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _CategoryChip(label: s.category),
                    const SizedBox(width: 8),
                    // _FieldsChip(count: s.fieldsCount),
                  ],
                ),
              ),

              // ── MIDDLE-RIGHT — credentials issued badge ────────────────
              SizedBox(
                width: 170,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _IssuedBadge(count: s.credentialsIssued),
                ),
              ),
              const SizedBox(width: 20),

              // ── RIGHT — status badge ───────────────────────────────────
              SizedBox(width: 90, child: _StatusBadge(status: s.schemaStatus)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CONFIRM DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _ConfirmDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String proceedLabel;
  final Color proceedColor;
  final VoidCallback onProceed;

  const _ConfirmDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.proceedLabel,
    required this.proceedColor,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 40,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 19, color: iconColor),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: AppTextStyles.navLabelActive.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Message
            Text(
              message,
              style: AppTextStyles.bodyTiny.copyWith(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'Cancel',
                  onTap: () => Navigator.pop(context),
                  showBorder: true,
                  hoverColor: AppColors.surfaceHover,
                  textColor: AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: proceedLabel,
                  backgroundColor: proceedColor,
                  hoverColor: proceedColor.withOpacity(0.82),
                  onTap: () {
                    Navigator.pop(context);
                    onProceed();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ─── STATUS BADGE (Active / Archived) ─────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final SchemaStatus status;
  const _StatusBadge({required this.status});

  Color get _fg => status == SchemaStatus.active
      ? AppColors.verifyingLight
      : AppColors.expired;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    width: 150,
    decoration: BoxDecoration(
      color: _fg.withOpacity(0.11),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _fg.withOpacity(0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _fg),
        ),
        const SizedBox(width: 6),
        Text(
          status.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _fg,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}

// ─── CREDENTIALS ISSUED BADGE ─────────────────────────────────────────────────

class _IssuedBadge extends StatelessWidget {
  final int count;
  const _IssuedBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final hasIssued = count > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      width: 110,
      decoration: BoxDecoration(
        color: hasIssued
            ? AppColors.issuingAccent.withOpacity(0.08)
            : AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasIssued
              ? AppColors.issuingAccent.withOpacity(0.2)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_outlined,
            size: 12,
            color: hasIssued ? AppColors.issuingLight : AppColors.textDim,
          ),
          const SizedBox(width: 5),
          Text(
            '$count issued',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: hasIssued ? AppColors.issuingLight : AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CATEGORY CHIP ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip({required this.label});

  Color get _color {
    switch (label.toLowerCase()) {
      case 'medical':
        return const Color(0xFF06B6D4);
      case 'corporate':
        return const Color(0xFFA855F7);
      default:
        return AppColors.issuingLight;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    width: 80,
    decoration: BoxDecoration(
      color: _color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: _color.withOpacity(0.25)),
    ),
    child: Center(
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    ),
  );
}

// ─── FIELDS COUNT CHIP ────────────────────────────────────────────────────────

// class _FieldsChip extends StatelessWidget {
//   final int count;
//   const _FieldsChip({required this.count});

//   @override
//   Widget build(BuildContext context) => Row(
//     mainAxisSize: MainAxisSize.min,
//     children: [
//       const Icon(Icons.list_alt_rounded, size: 11, color: AppColors.textDim),
//       const SizedBox(width: 4),
//       Text(
//         '$count field${count == 1 ? '' : 's'}',
//         style: AppTextStyles.bodyTiny.copyWith(
//           fontSize: 10,
//           color: AppColors.textDim,
//         ),
//       ),
//     ],
//   );
// }

// ─── SEARCH BAR ───────────────────────────────────────────────────────────────

