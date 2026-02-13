import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/recording_service.dart';
import 'routes/app_routes.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://lgthupyclkdiuynyokcn.supabase.co',
    anonKey: 'sb_publishable_evV5wtX6Ge1U3A1RWwe0AQ_Ch823EKw',
  );

  runApp(const MainApp());
}

final supabase = Supabase.instance.client; // 全局客户端
final recorder = RecordingService();

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Second Brain',
      // debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (_) => const HomePage(),
        ...AppRoutes.routes,
      },
      // home: Scaffold(
      //   body: Center(
      //     child: Column(
      //       mainAxisAlignment: MainAxisAlignment.center,
      //       children: [
      //         const Text('Hello World!'),
      //         const SizedBox(height: 20),
      //         ElevatedButton(
      //           onPressed: () async {
      //             if (!recorder.isRecording) {
      //               debugPrint('Recording started');
      //               await recorder.start();
      //             } else {
      //               final path = await recorder.stop();
      //               debugPrint('Recording saved: $path');
      //             }
      //           },
      //           child: Text('Start / Stop'),
      //         ),
      //       ],
      //     ),
      //   ),
      // ),
    );
  }
}
