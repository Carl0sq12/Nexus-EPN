import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';

/// Emergency SOS button with red glow and expanding pulse ring on long press.
class SosButton extends StatefulWidget {
  final VoidCallback onSosTriggered;

  const SosButton({required this.onSosTriggered, super.key});

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> {
  bool _isPressing = false;
  Timer? _holdTimer;

  void _onLongPressStart(LongPressStartDetails details) {
    setState(() => _isPressing = true);
    _holdTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isPressing = false);
        widget.onSosTriggered();
      }
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _holdTimer?.cancel();
    setState(() => _isPressing = false);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isPressing)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 2),
              builder: (context, value, child) {
                return Container(
                  width: 110 + 60 * value,
                  height: 110 + 60 * value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 1.0 - value),
                      width: 4,
                    ),
                  ),
                );
              },
            ),
          AnimatedScale(
            scale: _isPressing ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield, color: Colors.white, size: 40),
                  Text(
                    AppStrings.sosTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
