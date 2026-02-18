// lib/pages/recordings_list_page.dart
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/transcription_service.dart';

// 录音列表（合并本地文件与 transcripts 表）
class RecordingsListPage extends StatefulWidget {
  const RecordingsListPage({super.key});

  @override
  State<RecordingsListPage> createState() => _RecordingsListPageState();
}

class _RecordingsListPageState extends State<RecordingsListPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TranscriptionService _transcriber = TranscriptionService();
  final AudioPlayer _player = AudioPlayer();

  List<_MergedRecord> _items = [];

  String? _playingPath;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  PlayerState _state = PlayerState.stopped;

  bool get _isPlaying => _state == PlayerState.playing;
  bool get _isPaused => _state == PlayerState.paused;

  @override
  void initState() {
    super.initState();

    _player.onPlayerStateChanged.listen((s) {
      setState(() => _state = s);
    });

    _player.onDurationChanged.listen((d) {
      setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((p) {
      setState(() => _position = p);
    });

    _player.onPlayerComplete.listen((_) {
      setState(() {
        _position = Duration.zero;
        _playingPath = null;
        _state = PlayerState.stopped;
      });
    });

    _refreshAll();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<Directory> _getRecordingDir() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'recordings'));
  }

  Future<void> _refreshAll() async {
    try {
      final res =
          await _supabase
                  .from('transcripts')
                  .select()
                  .order('created_at', ascending: false)
              as List<dynamic>;

      final dbRows = res
          .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .toList();

      final dir = await _getRecordingDir();
      final localFiles = <File>[];

      if (await dir.exists()) {
        await for (final e in dir.list()) {
          if (e is File) {
            final name = p.basename(e.path);
            if (name.startsWith('rec') &&
                (name.endsWith('.m4a') ||
                    name.endsWith('.aac') ||
                    name.endsWith('.wav') ||
                    name.endsWith('.mp3'))) {
              localFiles.add(e);
            }
          }
        }
      }

      final Map<String, Map<String, dynamic>> dbByBasename = {};
      for (final row in dbRows) {
        final fp = (row['file_path'] ?? '') as String;
        final base = p.basename(fp);
        if (base.isNotEmpty) dbByBasename[base] = row;
      }

      final List<_MergedRecord> merged = [];

      for (final f in localFiles) {
        final base = p.basename(f.path);
        final row = dbByBasename[base];
        if (row == null) {
          merged.add(
            _MergedRecord.localOnly(localPath: f.path, fileName: base),
          );
        } else {
          merged.add(
            _MergedRecord.localAndDb(
              id: row['id']?.toString(),
              localPath: f.path,
              fileName: base,
              filePathInDb: row['file_path'],
              text: row['text'],
              status: row['status'],
              error: row['error'],
            ),
          );
          dbByBasename.remove(base);
        }
      }

      for (final entry in dbByBasename.entries) {
        final row = entry.value;
        merged.add(
          _MergedRecord.dbOnly(
            id: row['id']?.toString(),
            fileName: entry.key,
            filePathInDb: row['file_path'],
            text: row['text'],
            status: row['status'],
            error: row['error'],
          ),
        );
      }

      setState(() => _items = merged);
    } on SocketException catch (_) {
      _showSnack('无网络连接，请检查网络');
    } on StorageException catch (e) {
      if (e.message.contains('timeout')) {
        _showSnack('上传超时，请检查网络');
      }
      _showSnack('上传失败：${e.message}');
    } on PostgrestException catch (e) {
      _showSnack('数据库写入失败：${e.message}');
    } catch (e) {
      _showSnack('未知错误：$e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _togglePlay(String path) async {
    if (_playingPath == path) {
      if (_isPlaying) {
        await _player.pause();
        return;
      }
      if (_isPaused) {
        await _player.resume();
        return;
      }
    }

    _playingPath = path;
    _position = Duration.zero;
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  Future<void> _deleteLocalFile(_MergedRecord item) async {
    if (item.localPath == null) return;

    final f = File(item.localPath!);
    if (await f.exists()) {
      if (_playingPath == f.path) {
        await _player.stop();
        _playingPath = null;
        _position = Duration.zero;
        _state = PlayerState.stopped;
      }
      await f.delete();
      await _refreshAll();
    }
  }

  Future<void> _retryUploadLocalFile(_MergedRecord item) async {
    if (!item.isLocal) return;
    await _transcriber.uploadAndTranscribe(item.localPath!);
    await _refreshAll();
  }

  Future<void> _retryTranscription(_MergedRecord item) async {
    if (item.id == null) return;

    await _supabase
        .from('transcripts')
        .update({'status': 'pending', 'error': null})
        .eq('id', item.id!);

    await _refreshAll();
  }

  Future<void> _editTranscriptInDialog(_MergedRecord item) async {
    final controller = TextEditingController(text: item.text ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('编辑转写文本'),
        content: TextField(
          controller: controller,
          maxLines: 12,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (ok == true && item.id != null) {
      await _supabase
          .from('transcripts')
          .update({'text': controller.text, 'status': 'done'})
          .eq('id', item.id!);

      await _refreshAll();
    }
  }

  Widget _buildStatusWidget(_MergedRecord item) {
    if (item.isLocal && !item.isDb) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, color: Colors.grey),
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: () => _retryUploadLocalFile(item),
          ),
        ],
      );
    }

    switch (item.status) {
      case 'pending':
      case 'processing':
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case 'done':
        return IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _editTranscriptInDialog(item),
        );
      case 'error':
        return IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _retryTranscription(item),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('录音列表'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshAll),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: Text('暂无录音'))
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final item = _items[i];
                final isCurrent = item.localPath == _playingPath;

                return Column(
                  children: [
                    ListTile(
                      leading: item.localPath == null
                          ? const Icon(Icons.cloud)
                          : IconButton(
                              iconSize: 36,
                              icon: Icon(
                                isCurrent && _isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                              ),
                              onPressed: () => _togglePlay(item.localPath!),
                            ),
                      title: Text(item.fileName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.text != null && item.text!.isNotEmpty)
                            Text(
                              item.text!.length > 80
                                  ? '${item.text!.substring(0, 80)}...'
                                  : item.text!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatusWidget(item),
                          if (item.isLocal)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteLocalFile(item),
                            ),
                        ],
                      ),
                    ),
                    if (isCurrent)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            Slider(
                              min: 0,
                              max: _duration.inMilliseconds.toDouble().clamp(
                                1,
                                double.infinity,
                              ),
                              value: _position.inMilliseconds.toDouble().clamp(
                                0,
                                _duration.inMilliseconds.toDouble(),
                              ),
                              onChanged: (v) => _player.seek(
                                Duration(milliseconds: v.toInt()),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_fmt(_position)),
                                Text(_fmt(_duration)),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _MergedRecord {
  final String fileName;
  final String? id;
  final String? localPath;
  final String? filePathInDb;
  final String? text;
  final String? status;
  final String? error;

  bool get isLocal => localPath != null;
  bool get isDb => id != null || filePathInDb != null;

  _MergedRecord._({
    required this.fileName,
    this.id,
    this.localPath,
    this.filePathInDb,
    this.text,
    this.status,
    this.error,
  });

  factory _MergedRecord.localOnly({
    required String localPath,
    required String fileName,
  }) => _MergedRecord._(fileName: fileName, localPath: localPath);

  factory _MergedRecord.localAndDb({
    String? id,
    required String localPath,
    required String fileName,
    String? filePathInDb,
    String? text,
    String? status,
    String? error,
  }) => _MergedRecord._(
    id: id,
    fileName: fileName,
    localPath: localPath,
    filePathInDb: filePathInDb,
    text: text,
    status: status,
    error: error,
  );

  factory _MergedRecord.dbOnly({
    String? id,
    required String fileName,
    String? filePathInDb,
    String? text,
    String? status,
    String? error,
  }) => _MergedRecord._(
    id: id,
    fileName: fileName,
    filePathInDb: filePathInDb,
    text: text,
    status: status,
    error: error,
  );
}
