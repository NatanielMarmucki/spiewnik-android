import 'package:in_app_review/in_app_review.dart';

class ReviewModel {
  final InAppReview inAppReview = InAppReview.instance;

  Future<void> requestReview() async {
    if (await inAppReview.isAvailable()) {
      inAppReview.requestReview();
    }
  }
}