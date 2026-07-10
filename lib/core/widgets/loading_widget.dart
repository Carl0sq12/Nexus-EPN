import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Widget que muestra un indicador de carga. Puede mostrarse inline o como
/// pantalla completa cuando `fullScreen` es true.
class LoadingWidget extends StatelessWidget {
  final bool fullScreen;
  const LoadingWidget({this.fullScreen = false, super.key});

  @override
  Widget build(BuildContext context) {
    final loader = const Center(
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );

    if (fullScreen) {
      return Scaffold(backgroundColor: AppColors.background, body: loader);
    }

    return loader;
  }
}
