import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Icon button with an optional red numeric badge.
class BadgedIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final int count;
  final VoidCallback onPressed;

  const BadgedIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = Colors.white,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      color: color,
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: AppColors.error,
        textColor: Colors.white,
        label: Text(
          count > 99 ? '99+' : '$count',
          style: AppTextStyles.caption.copyWith(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}
