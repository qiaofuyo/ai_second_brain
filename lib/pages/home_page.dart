import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Second Brain')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.mic),
          label: const Text('超级录音笔'),
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.recorder);
          },
        ),
      ),
    );
  }
}
