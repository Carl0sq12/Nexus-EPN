import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Botón primario/outlined reutilizable con estilo Coastal Wave.
class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final double? width;
  final IconData? leadingIcon;

  const CustomButton({
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
    this.leadingIcon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null || isLoading;
    const borderRadius = 14.0;

    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: SizedBox(
        width: width ?? double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isOutlined
                ? Colors.transparent
                : AppColors.primary,
            shadowColor: isOutlined ? Colors.transparent : AppColors.primary,
            elevation: isOutlined ? 0 : 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.onPrimary,
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (leadingIcon != null) ...[
                      Icon(
                        leadingIcon,
                        color: isOutlined
                            ? AppColors.primary
                            : AppColors.onPrimary,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: isOutlined
                            ? AppColors.primary
                            : AppColors.onPrimary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
