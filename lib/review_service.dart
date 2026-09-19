import 'package:in_app_review/in_app_review.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks for an app review: rarely, at round launch counts and **at most once per version**.
///
/// Replaces `ReviewModel` and `LaunchCounter`. The previous thresholds started at the fifth
/// launch, plus prompts after the first favorite was added — too pushy overall, especially
/// since the system limits these prompts in its own way anyway. Dependencies are injected so
/// this can be tested without the real `in_app_review`.
class ReviewService {
  /// Launches at which we ask. More often at first, then less and less often.
  static const List<int> launchThresholds = [
    20,
    50,
    90,
    140,
    200,
    270,
    300,
    390,
    490,
    640,
    840,
    1140,
    1440,
    1940,
  ];

  /// Key holding the launch count. **It exists on users' devices** — do not change it.
  static const String launchCountKey = 'launch_count';

  /// The version in which we last asked. The key is new, so existing users may get the first
  /// prompt in 12.0.0 despite earlier prompts.
  static const String lastAskedVersionKey = 'reviewAskedVersion';

  final Future<bool> Function() isAvailable;
  final Future<void> Function() requestReview;
  final Future<String> Function() currentVersion;
  final Logger logger;

  ReviewService({
    Future<bool> Function()? isAvailable,
    Future<void> Function()? requestReview,
    Future<String> Function()? currentVersion,
    Logger? logger,
  }) : isAvailable = isAvailable ?? InAppReview.instance.isAvailable,
       requestReview = requestReview ?? InAppReview.instance.requestReview,
       currentVersion = currentVersion ?? _versionFromPackage,
       logger = logger ?? Logger();

  static Future<String> _versionFromPackage() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  /// Counts the launch and asks for a review when it is due. Returns true when the prompt was sent.
  /// Never throws: a failed review prompt must not break the app start.
  Future<bool> onLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final launchCount = (prefs.getInt(launchCountKey) ?? 0) + 1;
      await prefs.setInt(launchCountKey, launchCount);

      if (!launchThresholds.contains(launchCount)) {
        return false;
      }
      final version = await currentVersion();
      if (prefs.getString(lastAskedVersionKey) == version) {
        logger.i('Review: already asked in $version, skipping.');
        return false;
      }
      if (!await isAvailable()) {
        logger.i('Review: the system says the prompt is not available.');
        return false;
      }
      await requestReview();
      // Saved after the prompt: when the system refuses, we try again at the next threshold.
      await prefs.setString(lastAskedVersionKey, version);
      logger.i('Review: asked at launch $launchCount in $version.');
      return true;
    } catch (error, stackTrace) {
      logger.e('Review: asking failed.', error: error, stackTrace: stackTrace);
      return false;
    }
  }
}
