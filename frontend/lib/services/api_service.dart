import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

String get _baseUrl {
  final host = dotenv.env['BACKEND_HOST'] ?? '127.0.0.1';
  return 'http://$host:8000/api/v1';
}

class SseEvent {
  final String event;
  final Map<String, dynamic> data;
  const SseEvent({required this.event, required this.data});
}

class ApiService {
  static const Duration _connectionTimeout = Duration(seconds: 10);

  static Stream<SseEvent> validateStream(String idea, {String? category}) {
    final controller = StreamController<SseEvent>();
    _startSseStream(idea, controller, category: category).catchError((Object err) {
      if (!controller.isClosed) {
        controller.add(SseEvent(event: 'error', data: {'message': err.toString()}));
        controller.close();
      }
    });
    return controller.stream;
  }

  static Future<void> _startSseStream(
    String idea,
    StreamController<SseEvent> controller, {
    String? category,
  }) async {
    final client = http.Client();
    try {
      final payload = <String, dynamic>{'idea': idea};
      if (category != null) payload['category'] = category;

      final request = http.Request('POST', Uri.parse('$_baseUrl/validate/stream'))
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Cache-Control'] = 'no-cache'
        ..body = jsonEncode(payload);

      final streamedResponse = await client.send(request).timeout(
        _connectionTimeout,
        onTimeout: () => throw TimeoutException('Connection to backend timed out'),
      );

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        throw Exception('HTTP ${streamedResponse.statusCode}: $body');
      }

      String currentEvent = 'message';
      String currentData = '';

      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (controller.isClosed) break;

        if (line.startsWith('event:')) {
          currentEvent = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          currentData = line.substring(5).trim();
        } else if (line.isEmpty && currentData.isNotEmpty) {
          try {
            final parsed = jsonDecode(currentData) as Map<String, dynamic>;
            controller.add(SseEvent(event: currentEvent, data: parsed));
          } catch (_) {}
          currentEvent = 'message';
          currentData = '';
        }
      }
    } finally {
      client.close();
      if (!controller.isClosed) controller.close();
    }
  }

  static Future<String?> transcribeAudio(String filePath) async {
    try {
      final uri = Uri.parse('$_baseUrl/transcribe');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Transcription request timed out'),
      );
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        return (jsonDecode(body) as Map<String, dynamic>)['transcript'] as String?;
      }
    } catch (e) {
      // ignore, caller handles null return
    }
    return null;
  }
}
