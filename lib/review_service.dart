import 'package:in_app_review/in_app_review.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prośba o ocenę aplikacji: rzadko, przy okrągłych uruchomieniach i **najwyżej raz na wersję**.
///
/// Zastępuje `ReviewModel` i `LaunchCounter`. Poprzednie progi zaczynały się od piątego
/// uruchomienia i dochodziły prośby po pierwszym dodaniu ulubionej — łącznie zbyt natarczywie,
/// zwłaszcza że system i tak limituje te okna po swojemu. Zależności są wstrzykiwane, żeby dało
/// się to przetestować bez prawdziwego `in_app_review`.
class ReviewService {
  /// Uruchomienia, przy których pytamy. Gęściej na początku, potem coraz rzadziej.
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

  /// Klucz z licznikiem uruchomień. **Istnieje na urządzeniach użytkowników** — nie zmieniać.
  static const String launchCountKey = 'launch_count';

  /// Wersja, przy której ostatnio pytaliśmy. Klucz nowy, więc u dotychczasowych użytkowników
  /// pierwsze pytanie w 12.0.0 może paść mimo wcześniejszych próśb.
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

  /// Liczy uruchomienie i pyta o ocenę, jeśli wypada. Zwraca true, gdy prośba poszła.
  /// Nigdy nie rzuca: nieudana prośba o ocenę nie ma prawa popsuć startu aplikacji.
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
      // Zapisujemy po prośbie: gdy system odmówi, spróbujemy przy kolejnym progu.
      await prefs.setString(lastAskedVersionKey, version);
      logger.i('Review: asked at launch $launchCount in $version.');
      return true;
    } catch (error, stackTrace) {
      logger.e('Review: asking failed.', error: error, stackTrace: stackTrace);
      return false;
    }
  }
}
