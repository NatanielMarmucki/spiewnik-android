import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/review_service.dart';

/// Prośba o ocenę: rzadko, na progach uruchomień i najwyżej raz na wersję.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> asked;
  late bool available;

  /// Usługa bez prawdziwego in_app_review: zapisujemy, o co została poproszona.
  ReviewService service({String version = '12.0.0+1'}) {
    return ReviewService(
      logger: Logger(level: Level.off),
      isAvailable: () async => available,
      requestReview: () async => asked.add(version),
      currentVersion: () async => version,
    );
  }

  setUp(() {
    asked = [];
    available = true;
    SharedPreferences.setMockInitialValues({});
  });

  Future<int> launchCount() async =>
      (await SharedPreferences.getInstance()).getInt(ReviewService.launchCountKey) ?? 0;

  /// Uruchamia aplikację [times] razy i zwraca numery uruchomień, przy których padła prośba.
  Future<List<int>> runLaunches(int times, {String version = '12.0.0+1'}) async {
    final askedAt = <int>[];
    for (var i = 1; i <= times; i++) {
      if (await service(version: version).onLaunch()) {
        askedAt.add(i);
      }
    }
    return askedAt;
  }

  test('counts every launch', () async {
    await service().onLaunch();
    await service().onLaunch();
    await service().onLaunch();

    expect(await launchCount(), 3);
  });

  test('does not ask before the first threshold', () async {
    expect(await runLaunches(19), isEmpty);
  });

  test('asks exactly at the first threshold', () async {
    expect(await runLaunches(20), [20]);
  });

  test('thresholds start at 20, not at 5 as before', () async {
    expect(ReviewService.launchThresholds.first, 20);
    expect(ReviewService.launchThresholds, contains(1940));
    expect(ReviewService.launchThresholds, isNot(contains(5)));
  });

  group('one request per version', () {
    test('later thresholds in the same version do not ask', () async {
      final askedAt = await runLaunches(60);

      expect(askedAt, [20], reason: 'próg 50 wypada w tej samej wersji');
      expect(asked, hasLength(1));
    });

    test('after a version change the request can be made again', () async {
      await runLaunches(49);
      expect(asked, hasLength(1));

      // Aktualizacja aplikacji: kolejny próg (50) znów jest w grze.
      final afterUpdate = await service(version: '12.1.0+2').onLaunch();

      expect(afterUpdate, isTrue);
      expect(asked, ['12.0.0+1', '12.1.0+2']);
    });

    test('saves the version only after a successful request', () async {
      available = false;
      await runLaunches(20);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ReviewService.lastAskedVersionKey), isNull);
      expect(asked, isEmpty);
    });
  });

  test('nothing happens when the system has no review dialog', () async {
    available = false;

    expect(await runLaunches(25), isEmpty);
    expect(await launchCount(), 25, reason: 'licznik i tak rośnie');
  });

  test('an error during the request does not break startup', () async {
    final failing = ReviewService(
      logger: Logger(level: Level.off),
      isAvailable: () async => true,
      requestReview: () async => throw StateError('brak okna'),
      currentVersion: () async => '12.0.0+1',
    );
    SharedPreferences.setMockInitialValues({ReviewService.launchCountKey: 19});

    expect(await failing.onLaunch(), isFalse);
  });

  test('the launch counter uses the key that is already on devices', () async {
    expect(ReviewService.launchCountKey, 'launch_count');
    SharedPreferences.setMockInitialValues({'launch_count': 18});

    await service().onLaunch();

    expect(await launchCount(), 19, reason: 'kontynuuje zliczanie, nie zaczyna od zera');
  });
}
