import 'dart:async';
import 'package:flutter/material.dart';
import '../services/recording_service.dart';
import '../services/transcription_service.dart';

class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  final RecordingService _recorder = RecordingService();
  final TranscriptionService _transcriber = TranscriptionService();

  Timer? _timer;
  int _seconds = 0;

  bool get _isRecording => _recorder.isRecording;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    try {
      if (!_isRecording) {
        await _recorder.start();
        setState(() {});
        _startTimer();
      } else {
        final path = await _recorder.stop();
        setState(() {});
        debugPrint(path);
        _stopTimer();

        if (path != null) {
          // _showSnack('录音已保存：$path');
          _showSnack('录音上传中...');
          await _transcriber.uploadAndTranscribe(path);
          _showSnack('转录完成');
        }
      }
    } catch (e) {
      _stopTimer();
      setState(() {});
      _showSnack('操作失败：$e');
      debugPrint('操作失败：$e');
    }
  }

  void _startTimer() {
    _seconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _seconds++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _seconds = 0;
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('超级录音笔'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// 录音状态文字
            Text(
              _isRecording ? '正在录音中...' : '点击开始录音',
              style: theme.textTheme.titleLarge,
            ),

            const SizedBox(height: 24),

            /// 计时器
            Text(
              _formatTime(_seconds),
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _isRecording ? Colors.red : Colors.black,
              ),
            ),

            const SizedBox(height: 40),

            /// 录音按钮
            GestureDetector(
              onTap: _toggleRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 插入的转录状态显示
            StreamBuilder<Map<String, dynamic>?>(
              stream: _transcriber.watchLatestTranscript(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('暂无转写任务');
                }
                final row = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('状态：${row['status']}'),
                    const SizedBox(height: 8),
                    Text(row['text'] ?? '等待识别结果...'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
