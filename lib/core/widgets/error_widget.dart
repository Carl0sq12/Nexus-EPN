import 'package:flutter/material.dart';
import '../constants/app_text_styles.dart';
import '../constants/app_strings.dart';
import 'custom_button.dart';

/// Muestra un mensaje de error centrado y opcionalmente un botón para reintentar.
class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorWidget({required this.message, this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              CustomButton(label: AppStrings.confirm, onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}
