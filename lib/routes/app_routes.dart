import 'package:flutter/material.dart';
import '../pages/recorder_page.dart';

class AppRoutes {
  static const home = '/';
  static const recorder = '/recorder';
  static const aiSummary = '/ai-summary';
  static const transcript = '/transcript';
  static const knowledgeGraph = '/graph';

  static Map<String, WidgetBuilder> routes = {
    recorder: (_) => const RecorderPage(),
  };
}
