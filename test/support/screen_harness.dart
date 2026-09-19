import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/model/app_settings_model.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/viewmodel/settings_viewmodel.dart';

/// Pumps a screen in the real theme, with the models that the views expect from Provider.
///
/// Used by the accessibility tests: labels, tap targets and text scaling.
/// [textScale] corresponds to system text scaling, not to the song text size setting.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget Function(BuildContext context) build, {
  ThemeData? theme,
  double textScale = 1.0,
  Size size = const Size(411, 915),
  Map<String, Object> preferences = const {},
}) async {
  SharedPreferences.setMockInitialValues(Map<String, Object>.from(preferences));
  final fontSizeModel = FontSizeModel();
  await fontSizeModel.loaded;
  final appSettings = AppSettingsModel();
  await appSettings.loaded;

  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FontSizeModel>.value(value: fontSizeModel),
        ChangeNotifierProvider<AppSettingsModel>.value(value: appSettings),
        Provider<SettingsViewModel>(create: (_) => SettingsViewModel()),
      ],
      child: MaterialApp(
        theme: theme ?? lightTheme,
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Builder(builder: build),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
