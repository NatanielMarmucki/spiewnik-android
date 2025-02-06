import 'package:shared_preferences/shared_preferences.dart';

class LaunchCounter {
  static const List<int> thresholds = [5, 10, 50, 100, 250, 500, 750, 1000];
  static const String _launchCountKey = 'launch_count';

  Future<int> incrementLaunchCount() async {
    final prefs = await SharedPreferences.getInstance();
    int launchCount = prefs.getInt(_launchCountKey) ?? 0;
    launchCount++;
    await prefs.setInt(_launchCountKey, launchCount);
    return launchCount;
  }

  bool checkThreshold(int launchCount) {
    return thresholds.contains(launchCount);
  }
}