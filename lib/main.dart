import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:objectbox/objectbox.dart';
import 'objectbox.g.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:spiewnik/database_manager.dart';
import 'package:spiewnik/view/song_list_view.dart';
import 'package:spiewnik/view/favorite_songs_view.dart';
import 'package:spiewnik/view/settings_view.dart';
import 'package:spiewnik/viewmodel/song_viewmodel.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/model/review_model.dart';
import 'package:spiewnik/launch_counter.dart';
import 'package:spiewnik/viewmodel/settings_viewmodel.dart';

import 'package:convex_bottom_bar/convex_bottom_bar.dart';

Future<void> copyDatabaseFileFromAssets() async {
  ByteData data = await rootBundle.load('assets/songs.sqlite');
  List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

  Directory documentsDirectory = await getApplicationDocumentsDirectory();
  String path = '${documentsDirectory.path}/songs.sqlite';

  if (!await File(path).exists()) {
    await File(path).writeAsBytes(bytes);
    print('Baza danych skopiowana do $path');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await copyDatabaseFileFromAssets();
  final objectBoxStore = await openStore();

  final dbManager = DatabaseManager(objectBoxStore);
  await dbManager.initializeDatabase();

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

  MyApp({required this.store});

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

class HomeScreen extends StatefulWidget {
  final Store store;

  HomeScreen({required this.store});

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
        title: Text(
          'Śpiewnik',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
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
        items: [
          TabItem(icon: Icons.auto_stories, title: 'Śpiewnik'),
          TabItem(icon: Icons.favorite, title: 'Ulubione'),
        ],
        backgroundColor: Theme.of(context).colorScheme.primary,
        activeColor: Colors.white.withOpacity(0.6),
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
