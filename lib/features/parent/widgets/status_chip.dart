import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';

/// A small UI badge for displaying status
class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bgColor;

    // "Checked In" -> Green, "At Home" -> Red/Grey, "Checked Out" -> Blue
    switch (status) {
      case 'Checked In':
      case 'In Class':
        color = AppColors.success;
        bgColor = AppColors.successLight;
        break;
      case 'At Home':
        color = AppColors.danger;
        bgColor = AppColors.dangerLight;
        break;
      case 'Checked Out':
        color = AppColors.info;
        bgColor = AppColors.infoLight;
        break;
      default:
        color = AppColors.textMuted;
        bgColor = AppColors.divider;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        status.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
