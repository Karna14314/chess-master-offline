import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local service managing native Play Store in-app review prompts and store listings.
class ReviewService {
  ReviewService._();

  static final InAppReview _inAppReview = InAppReview.instance;
  static const String _keyLastPromptMs = 'last_review_prompt_timestamp';
  static const int _minDaysBetweenPrompts = 30;

  /// Prompt native in-app review dialog after a positive milestone.
  /// Enforces a 30-day throttle between prompts to avoid annoying players.
  static Future<void> requestReviewIfAppropriate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPrompt = prefs.getInt(_keyLastPromptMs) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final daysSinceLast = (now - lastPrompt) / (1000 * 60 * 60 * 24);

      if (daysSinceLast < _minDaysBetweenPrompts) {
        return;
      }

      final isAvailable = await _inAppReview.isAvailable();
      if (isAvailable) {
        await prefs.setInt(_keyLastPromptMs, now);
        await _inAppReview.requestReview();
      }
    } catch (e) {
      debugPrint('Review prompt error: $e');
    }
  }

  /// Direct user to Play Store listing for manual rating/review.
  static Future<void> openStoreListing() async {
    try {
      final isAvailable = await _inAppReview.isAvailable();
      if (isAvailable) {
        await _inAppReview.openStoreListing();
      }
    } catch (e) {
      debugPrint('Open store listing error: $e');
    }
  }
}
