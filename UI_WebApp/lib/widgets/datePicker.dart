import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/theme/appTextStyle.dart';
class DatePickerButton extends StatelessWidget {
  final String? value;
  final String hint;
  final bool disabled;
  final ValueChanged<DateTime> onPick;

  const DatePickerButton({
    required this.onPick,
    this.value,
    this.hint = 'Select date…',
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: disabled
            ? null
            : () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.issuingAccent,
                        surface: Color(0xFF1C1C1C),
                      ),
                      dialogBackgroundColor: const Color(0xFF1C1C1C),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) onPick(picked);
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: disabled
                ? AppColors.surfaceHover.withOpacity(0.5)
                : AppColors.surfaceHover,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: disabled
                    ? AppColors.textDim.withOpacity(0.35)
                    : AppColors.textDim,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value ?? hint,
                  style: AppTextStyles.bodyTiny.copyWith(
                    fontSize: 12,
                    color: disabled
                        ? AppColors.textDim.withOpacity(0.35)
                        : value != null
                        ? AppColors.textMuted
                        : AppColors.textDim,
                  ),
                ),
              ),
              if (!disabled)
                const Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: AppColors.textDim,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
