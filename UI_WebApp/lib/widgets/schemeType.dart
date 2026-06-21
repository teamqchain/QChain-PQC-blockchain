import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/ISSUER/schema_model.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';



class SchemaListItem extends StatefulWidget {
  final SchemaRecord schema;
  final bool isSelected;
  final VoidCallback onTap;
  const SchemaListItem({super.key, 
    required this.schema,
    required this.isSelected,
    required this.onTap,
  });
  @override
  State<SchemaListItem> createState() => SchemaListItemState();
}

class SchemaListItemState extends State<SchemaListItem> {
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
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.issuingAccent.withOpacity(0.13)
                : _hovered
                ? AppColors.issuingAccent.withOpacity(0.06)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: widget.isSelected || _hovered
                    ? AppColors.issuingAccent
                    : Colors.transparent,
                width: 2,
              ),
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 13,
                color: widget.isSelected
                    ? AppColors.issuingAccent
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.schema.name,
                      style: AppTextStyles.bodyTiny.copyWith(
                        fontSize: 12,
                        fontWeight: widget.isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: widget.isSelected
                            ? Colors.white
                            : AppColors.textMuted,
                      ),
                    ),
                    Text(
                      widget.schema.category,
                      style: AppTextStyles.bodyTiny.copyWith(
                        fontSize: 9,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isSelected)
                Icon(Icons.check, size: 13, color: AppColors.issuingAccent),
            ],
          ),
        ),
      ),
    );
  }
}
