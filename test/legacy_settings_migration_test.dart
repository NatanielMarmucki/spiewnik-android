import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/migration/legacy_settings_migration.dart';
import 'package:spiewnik/model/font_size_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final logger = Logger(level: Level.off);
  late List<MethodCall> calls;

  /// Simulates ios/Runner/AppDelegate.swift: [legacyValue] is what UserDefaults holds under isSize.
  void mockChannel(Object? legacyValue, {bool throws = false}) {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      LegacySettingsMigration.channel,
      (call) async {
        calls.add(call);
        if (throws) {
          throw PlatformException(code: 'unsupported_key');
        }
        return legacyValue;
      },
    );
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LegacySettingsMigration.channel, null);
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  test('moves the real isSize value from the old app to fontSize', () async {
    SharedPreferences.setMockInitialValues({});
    mockChannel(22.0);

    final result = await LegacySettingsMigration(logger: logger).run(isIOS: true);

    expect(result, 22.0);
    expect((await prefs()).getDouble('fontSize'), 22.0);
    expect((await prefs()).getBool(LegacySettingsMigration.doneKey), isTrue);
    expect(calls.single.method, 'readNumber');
    expect(calls.single.arguments, {'key': 'isSize'});
  });

  test('accepts an integer isSize value', () async {
    SharedPreferences.setMockInitialValues({});
    mockChannel(18);

    await LegacySettingsMigration(logger: logger).run(isIOS: true);

    expect((await prefs()).getDouble('fontSize'), 18.0);
  });

  test('clamps values from the old iPad range to the current range', () async {
    for (final entry in {44.0: 30.0, 24.0: 24.0, 31: 30.0, 8.0: 10.0}.entries) {
      SharedPreferences.setMockInitialValues({});
      mockChannel(entry.key);

      await LegacySettingsMigration(logger: logger).run(isIOS: true);

      expect((await prefs()).getDouble('fontSize'), entry.value, reason: 'isSize ${entry.key}');
    }
  });

  test('keeps the default font size when the old app never saved isSize', () async {
    SharedPreferences.setMockInitialValues({});
    mockChannel(null);

    final result = await LegacySettingsMigration(logger: logger).run(isIOS: true);

    expect(result, isNull);
    expect((await prefs()).containsKey('fontSize'), isFalse);
    expect((await prefs()).getBool(LegacySettingsMigration.doneKey), isTrue);
  });

  test('ignores values that are not a finite number', () async {
    for (final value in [double.nan, double.infinity, true, '22']) {
      SharedPreferences.setMockInitialValues({});
      mockChannel(value);

      await LegacySettingsMigration(logger: logger).run(isIOS: true);

      expect((await prefs()).containsKey('fontSize'), isFalse, reason: '$value');
    }
  });

  test('does not overwrite a font size already set in the new app', () async {
    SharedPreferences.setMockInitialValues({'fontSize': 14.0});
    mockChannel(28.0);

    await LegacySettingsMigration(logger: logger).run(isIOS: true);

    expect((await prefs()).getDouble('fontSize'), 14.0);
    expect(calls, isEmpty);
  });

  test('runs only once', () async {
    SharedPreferences.setMockInitialValues({});
    mockChannel(22.0);
    await LegacySettingsMigration(logger: logger).run(isIOS: true);
    await (await prefs()).remove('fontSize');

    final second = await LegacySettingsMigration(logger: logger).run(isIOS: true);

    expect(second, isNull);
    expect((await prefs()).containsKey('fontSize'), isFalse);
    expect(calls, hasLength(1));
  });

  test('does not throw, keeps the default and does not retry when the channel fails', () async {
    SharedPreferences.setMockInitialValues({});
    mockChannel(null, throws: true);

    final result = await LegacySettingsMigration(logger: logger).run(isIOS: true);

    expect(result, isNull);
    expect((await prefs()).containsKey('fontSize'), isFalse);
    expect((await prefs()).getBool(LegacySettingsMigration.doneKey), isTrue);
  });

  group('channel does not respond', () {
    /// No channel at all: exactly what we would see if, after the move to UIScene, the channel
    /// were registered later than the call from Dart.
    void noChannel() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(LegacySettingsMigration.channel, null);
    }

    test('does not save the flag, so the migration will try again', () async {
      SharedPreferences.setMockInitialValues({});
      noChannel();

      final result = await LegacySettingsMigration(logger: logger).run(isIOS: true);

      expect(result, isNull);
      expect((await prefs()).containsKey('fontSize'), isFalse);
      expect(
        (await prefs()).getBool(LegacySettingsMigration.doneKey),
        isNull,
        reason: 'brak flagi: to nasz błąd, nie brak danych u użytkownika',
      );
    });

    test('the migration succeeds on the next launch', () async {
      SharedPreferences.setMockInitialValues({});
      noChannel();
      await LegacySettingsMigration(logger: logger).run(isIOS: true);

      // Second launch, this time the channel responds.
      mockChannel(24.0);
      final result = await LegacySettingsMigration(logger: logger).run(isIOS: true);

      expect(result, 24.0);
      expect((await prefs()).getDouble('fontSize'), 24.0);
      expect((await prefs()).getBool(LegacySettingsMigration.doneKey), isTrue);
    });

    test('a missing key in the old app still completes the migration', () async {
      SharedPreferences.setMockInitialValues({});
      mockChannel(null);

      final result = await LegacySettingsMigration(logger: logger).run(isIOS: true);

      expect(result, isNull);
      expect(
        (await prefs()).getBool(LegacySettingsMigration.doneKey),
        isTrue,
        reason: 'kanał odpowiedział, po prostu nie ma czego przenosić',
      );
    });
  });

  test('does nothing outside iOS', () async {
    SharedPreferences.setMockInitialValues({});
    mockChannel(22.0);

    final result = await LegacySettingsMigration(logger: logger).run(isIOS: false);

    expect(result, isNull);
    expect(calls, isEmpty);
    expect((await prefs()).getBool(LegacySettingsMigration.doneKey), isNull);
  });

  test('the migrated font size is used by the font size settings', () async {
    SharedPreferences.setMockInitialValues({});
    mockChannel(26.0);
    await LegacySettingsMigration(logger: logger).run(isIOS: true);

    final model = FontSizeModel();
    await model.loaded;

    expect(model.fontSize, 26.0);
    expect(model.lineHeight, FontSizeModel.defaultLineHeight); // the old app does not migrate line height
  });
}
