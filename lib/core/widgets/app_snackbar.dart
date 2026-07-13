import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

enum AppSnackBarType { success, error, warning, info }

void showAppSnackBar(
  BuildContext context, {
  required String title,
  required String message,
  AppSnackBarType type = AppSnackBarType.info,
  Duration duration = const Duration(seconds: 4),
}) {
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        padding: EdgeInsets.zero,
        duration: duration,
        content: _AppSnackBarContent(
          title: title,
          message: message,
          type: type,
        ),
      ),
    );
}

class _AppSnackBarContent extends StatelessWidget {
  final String title;
  final String message;
  final AppSnackBarType type;

  const _AppSnackBarContent({
    required this.title,
    required this.message,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(type);
    final icon = _icon(type);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(10, 29, 45, 0.16),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.25,
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

Color _accentColor(AppSnackBarType type) {
  return switch (type) {
    AppSnackBarType.success => AppColors.success,
    AppSnackBarType.error => AppColors.error,
    AppSnackBarType.warning => AppColors.warning,
    AppSnackBarType.info => AppColors.primary,
  };
}

IconData _icon(AppSnackBarType type) {
  return switch (type) {
    AppSnackBarType.success => Icons.check_circle_outline,
    AppSnackBarType.error => Icons.error_outline,
    AppSnackBarType.warning => Icons.warning_amber_rounded,
    AppSnackBarType.info => Icons.info_outline,
  };
}
