import 'package:flutter/material.dart';
import '../pages/home_page.dart';
import '../pages/recorder_page.dart';
import '../pages/recordings_list_page.dart';

class AppRoutes {
  static const home = '/';
  static const recorder = '/recorder';
  static const recordingsList = '/recordingsList';

  static Map<String, WidgetBuilder> routes = {
    home: (_) => const HomePage(),
    recorder: (_) => const RecorderPage(),
    recordingsList: (_) => const RecordingsListPage(),
  };
}
