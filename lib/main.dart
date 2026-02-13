import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://lgthupyclkdiuynyokcn.supabase.co',
    anonKey: 'sb_publishable_evV5wtX6Ge1U3A1RWwe0AQ_Ch823EKw'
  );

  runApp(const MainApp());
}

final supabase = Supabase.instance.client; // 全局客户端

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Hello World!'),
        ),
      ),
    );
  }
}
