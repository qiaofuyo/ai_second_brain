import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// 录音服务
class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  String? _currentFilePath;

  /// 开始录音
  Future<void> start() async {
    if (_isRecording) return;

    // 1. 请求麦克风权限
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw Exception('Microphone permission denied');
    }

    // 2. 构建文件保存路径
    final dir = await _getRecordingDir();  // /data/user/0/com.example.ai_second_brain/app_flutter/recordings/
    final filePath = p.join(
      dir.path,
      _generateFileName(),
    );

    _currentFilePath = filePath;

    // 3. 开始录音
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    _isRecording = true;
  }

  /// 停止录音，返回音频文件路径
  Future<String?> stop() async {
    if (!_isRecording) return null;

    final path = await _recorder.stop();
    _isRecording = false;

    return path ?? _currentFilePath;
  }

  /// 获取录音文件存储目录
  Future<Directory> _getRecordingDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(baseDir.path, 'recordings'));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  /// 生成文件名：rec_yyyyMMdd_HHmmss.aac
  String _generateFileName() {
    final now = DateTime.now();
    final ts =
        '${now.year}'
        '${_two(now.month)}'
        '${_two(now.day)}_'
        '${_two(now.hour)}'
        '${_two(now.minute)}'
        '${_two(now.second)}';

    return 'rec_$ts.aac';
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
