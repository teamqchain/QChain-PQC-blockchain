import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
class HolderRow extends StatefulWidget {
  final HolderRecord holder;
  final bool isSelected;
  final VoidCallback onToggle;
  const HolderRow({
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
            ? const Color(0xFF4CAF50).withOpacity(0.07)
            : _hovered
            ? AppColors.surfaceHover
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            HolderAvatar(holder: widget.holder),
            const SizedBox(width: 12),
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
              child: Text(
                widget.holder.college,
                style: AppTextStyles.bodyTiny.copyWith(
                  fontSize: 11,
                  color: AppColors.textDim,
                ),
                overflow: TextOverflow.ellipsis,
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
            SizedBox(
              width: 85,
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
  const HolderAvatar({required this.holder});
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
