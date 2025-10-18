import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'objectbox.g.dart';
import 'json_manager.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/view/favorite_songs_view.dart';
import 'package:spiewnik/view/settings_view.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final objectBoxStore = await openStore();
  final jsonLoader = JsonManager(objectBoxStore, logger);

  bool shouldForceUpdate = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    final currentAppVersion = "${packageInfo.version}+${packageInfo.buildNumber}";

    final lastRunAppVersion = prefs.getString(_kLastRunAppVersionKey);

    if (lastRunAppVersion == null || lastRunAppVersion != currentAppVersion) {
      logger.i('First launch after installation/update or version change. Current version: $currentAppVersion, previous: $lastRunAppVersion');
      shouldForceUpdate = true;
    } else {
      logger.i('Launching with the same app version: $currentAppVersion');
    }

    await jsonLoader.loadDataFromJsonIfNeeded(forceUpdate: shouldForceUpdate);

    if (shouldForceUpdate) {
      await prefs.setString(_kLastRunAppVersionKey, currentAppVersion);
      logger.i('Saved current app version: $currentAppVersion');
    }

  } catch (e) {
    logger.e('Error during app version check or data loading: $e');
    await jsonLoader.loadDataFromJsonIfNeeded(forceUpdate: false);
  }

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

  @override
  void initState() {
    super.initState();
    viewModel = SongViewModel(widget.store);
  }

  List<Widget> _buildScreens() {
    return [
      SongListView(viewModel: viewModel),
      FavoriteSongsView(viewModel: viewModel),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
