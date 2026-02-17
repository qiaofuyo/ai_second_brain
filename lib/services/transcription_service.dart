import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class TranscriptionService {
  final SupabaseClient _client = Supabase.instance.client;

  // 上传音频并触发转写
  Future<void> uploadAndTranscribe(String localPath) async {
    try {
      final file = File(localPath);
      final fileName = p.basename(localPath);

      final storagePath = 'recordings/$fileName';

      // 1. 上传音频文件到 Supabase Storage
      await _client.storage.from('audio').upload(
        storagePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );
      debugPrint('音频上传完成');

      // 2. 创建转写任务，触发 Database Triggers
      await _client.from('transcripts').insert({
        'file_path': storagePath,
        'status': 'pending',
      });

    } on SocketException catch (_) {
      throw Exception('无网络连接，请检查网络');
    } on StorageException catch (e) {
      if (e.message.contains('timeout')) {
        throw Exception('上传超时，请检查网络');
      }
      throw Exception('上传失败：${e.message}');
    } on PostgrestException catch (e) {
      throw Exception('数据库写入失败：${e.message}');
    } catch (e) {
      throw Exception('未知错误：$e');
    }
  }

  // 实时监听全部转写任务
  Stream<List<Map<String, dynamic>>> watchTranscripts() {
    return _client
        .from('transcripts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  // 只监听最近一次转写任务（UI 极简模式）
  Stream<Map<String, dynamic>?> watchLatestTranscript() {
    return _client
        .from('transcripts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(1)
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }
}
