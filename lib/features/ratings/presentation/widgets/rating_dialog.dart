import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';

/// Result returned by [RatingDialog].
class RatingResult {
  final int score;
  final String? comment;

  const RatingResult({required this.score, this.comment});
}

/// Bottom-sheet dialog with a 5-star rating widget and optional comment field.
class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key});

  /// Shows the rating bottom sheet and returns the result if submitted.
  static Future<RatingResult?> show(BuildContext context) {
    return showModalBottomSheet<RatingResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const RatingDialog(),
    );
  }

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _score = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppStrings.ratingTitle, style: AppTextStyles.titleLarge),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _score = starIndex),
                child: Icon(
                  starIndex <= _score ? Icons.star : Icons.star_border,
                  size: 40,
                  color: starIndex <= _score
                      ? AppColors.warning
                      : AppColors.outlineVariant,
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: AppStrings.ratingHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _score == 0
                  ? null
                  : () {
                      Navigator.pop(
                        context,
                        RatingResult(
                          score: _score,
                          comment: _commentController.text.trim().isEmpty
                              ? null
                              : _commentController.text.trim(),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(AppStrings.ratingSubmit),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
