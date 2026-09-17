import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/holder_model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';

/// Shared column metrics — keep header and [HolderRow] in lockstep.
class HolderTableLayout {
  HolderTableLayout._();

  /// Avatar diameter (radius 16) + gap before name column.
  static const double avatarLeadWidth = 44;

  /// Fixed slot for the wallet-status icon (always reserved, even when empty).
  static const double statusSlotWidth = 32;

  /// Select / Selected button column.
  static const double actionWidth = 85;

  static const EdgeInsets rowPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 10);
}

class HolderRow extends StatefulWidget {
  final HolderRecord holder;
  final bool isSelected;
  final VoidCallback onToggle;
  const HolderRow({
    super.key,
    required this.holder,
    required this.isSelected,
    required this.onToggle,
  });
  @override
  State<HolderRow> createState() => HolderRowState();
}

class HolderRowState extends State<HolderRow> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: widget.isSelected
            ? AppColors.valid.withOpacity(0.07)
            : _hovered
            ? AppColors.surfaceHover
            : Colors.transparent,
        padding: HolderTableLayout.rowPadding,
        child: Row(
          children: [
            SizedBox(
              width: HolderTableLayout.avatarLeadWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: HolderAvatar(holder: widget.holder),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.holder.fullName,
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.holder.email,
                    style: AppTextStyles.bodyTiny.copyWith(
                      fontSize: 10,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.holder.type.label,
                style: AppTextStyles.bodyTiny.copyWith(fontSize: 11),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 50),
                child: Text(
                  widget.holder.college,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.holder.emiratesID,
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 10,
                  color: AppColors.textDim,
                ),
              ),
            ),
            // Always reserve the same width so Select stays under the header.
            SizedBox(
              width: HolderTableLayout.statusSlotWidth,
              child: widget.holder.isWalletActivated
                  ? null
                  : const Center(child: _WalletInactiveHint()),
            ),
            SizedBox(
              width: HolderTableLayout.actionWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: widget.onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? const Color(0xFF4CAF50).withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: widget.isSelected
                            ? const Color(0xFF4CAF50)
                            : AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.isSelected ? 'Selected ✓' : 'Select',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: widget.isSelected
                            ? const Color(0xFF4CAF50)
                            : AppColors.textMuted,
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

class HolderAvatar extends StatelessWidget {
  final HolderRecord holder;
  const HolderAvatar({super.key, required this.holder});
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 16,
    backgroundColor: AppColors.issuingAccent.withOpacity(0.22),
    child: Text(
      holder.initials,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}

/// Amber circle + warning icon next to Select. Tooltip: "Wallet not activated".
class _WalletInactiveHint extends StatelessWidget {
  const _WalletInactiveHint();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Wallet not activated',
      waitDuration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.withOpacity(0.45)),
      ),
      textStyle: const TextStyle(
        fontSize: 11,
        letterSpacing: 0.5,
        color: Colors.white,
      ),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.orange.withOpacity(0.18),
          border: Border.all(color: Colors.orange.withOpacity(0.55)),
        ),
        child: const Icon(
          Icons.warning_amber_rounded,
          size: 14,
          color: Colors.orange,
        ),
      ),
    );
  }
}
