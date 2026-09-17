import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'objectbox.g.dart';
import 'json_manager.dart';
import 'package:spiewnik/migration/core_data_migration.dart';
import 'package:spiewnik/migration/legacy_settings_migration.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/view/favorite_songs_view.dart';
import 'package:spiewnik/view/my_song_form_view.dart';
import 'package:spiewnik/view/my_songs_view.dart';
import 'package:spiewnik/view/settings_view.dart';
import 'package:spiewnik/data/repositories/my_song_repository.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/model/review_model.dart';
import 'package:spiewnik/launch_counter.dart';
import 'package:spiewnik/viewmodel/settings_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1,
    errorMethodCount: 5,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.none,
  ),
);

const String _kLastRunAppVersionKey = 'last_run_app_version';

Future<void> initializeApp(JsonManager jsonManager) async {
  bool shouldForceUpdate = false;
  String? currentAppVersion;

  try {
    logger.i("Starting app initialization and version check...");
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();

    currentAppVersion = "${packageInfo.version}+${packageInfo.buildNumber}";

    final lastRunAppVersion = prefs.getString(_kLastRunAppVersionKey);

    logger.i("Current app version: $currentAppVersion");
    logger.i("Stored app version: $lastRunAppVersion");

    if (lastRunAppVersion == null || lastRunAppVersion != currentAppVersion) {
      logger.i('Version mismatch or first launch. Forcing data update.');
      shouldForceUpdate = true;
    } else {
      logger.i('App versions match. No data update needed.');
    }
  } catch (e, stacktrace) {
    logger.e('Error during version check!', error: e, stackTrace: stacktrace);
    shouldForceUpdate = false;
  }

  await jsonManager.loadDataFromJsonIfNeeded(forceUpdate: shouldForceUpdate);

  if (shouldForceUpdate && currentAppVersion != null) {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastRunAppVersionKey, currentAppVersion);
      logger.i('Successfully saved current app version: $currentAppVersion');
    } catch (e) {
      logger.e('Failed to save the new app version string!', error: e);
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final objectBoxStore = await openStore();
  final jsonLoader = JsonManager(objectBoxStore, logger);

  await initializeApp(jsonLoader);
  // After the songs are loaded, so favorites from the old iOS app can be matched by number.
  await CoreDataMigration.runOnStartup(store: objectBoxStore, logger: logger);
  // Before runApp, so FontSizeModel loads the migrated font size.
  await LegacySettingsMigration(logger: logger).run();

  runApp(
    MultiProvider(
      providers: [
        Provider<Store>.value(value: objectBoxStore),
        ChangeNotifierProvider(create: (_) => FontSizeModel()),
        Provider(create: (_) => SettingsViewModel()),
      ],
      child: MyApp(store: objectBoxStore),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Store store;
  final ReviewModel reviewModel = ReviewModel();
  final LaunchCounter launchCounter = LaunchCounter();

  MyApp({
    super.key,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    _checkForReviewRequest();
    return MaterialApp(
      title: 'Śpiewnik',
      theme: lightTheme,
      debugShowCheckedModeBanner: false,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: HomeScreen(store: store),
    );
  }

  void _checkForReviewRequest() async {
    int launchCount = await launchCounter.incrementLaunchCount();
    if (launchCounter.checkThreshold(launchCount)) {
      await reviewModel.requestReview();
    }
  }
}

@immutable
class HomeScreen extends StatefulWidget {
  final Store store;

  const HomeScreen({
    super.key,
    required this.store,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late SongViewModel viewModel;
  late MySongViewModel mySongViewModel;

  @override
  void initState() {
    super.initState();
    viewModel = SongViewModel(widget.store);
    mySongViewModel = MySongViewModel(ObjectBoxMySongRepository(widget.store));
  }

  List<Widget> _buildScreens() {
    return [
      SongListView(viewModel: viewModel),
      FavoriteSongsView(viewModel: viewModel),
      MySongsView(viewModel: mySongViewModel),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Śpiewnik',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (_selectedIndex == 2)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Dodaj pieśń',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MySongFormView(viewModel: mySongViewModel)),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsView()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _buildScreens(),
      ),
      bottomNavigationBar: ConvexAppBar(
        style: TabStyle.reactCircle,
        items: const [
          TabItem(icon: Icons.auto_stories, title: 'Śpiewnik'),
          TabItem(icon: Icons.favorite, title: 'Ulubione'),
          TabItem(icon: Icons.edit_note, title: 'Moje pieśni'),
        ],
        backgroundColor: Theme.of(context).colorScheme.primary,
        activeColor: Colors.white.withAlpha(153),
        curveSize: 80,
        initialActiveIndex: _selectedIndex,
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
