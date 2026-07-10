import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'loading_widget.dart';
import 'error_widget.dart';

/// Generic widget that maps an [AsyncValue] to UI states: loading, data,
/// and error.
class AsyncValueWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  const AsyncValueWidget({
    required this.value,
    required this.builder,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (data) => builder(data),
      loading: () => const LoadingWidget(),
      error: (error, _) => AppErrorWidget(message: error.toString()),
    );
  }
}
