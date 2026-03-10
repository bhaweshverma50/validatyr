import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String get _baseUrl {
  final host = dotenv.env['BACKEND_HOST'] ?? '127.0.0.1';
  final isLocal = host == '127.0.0.1' || host == 'localhost' || host.startsWith('192.168.');
  final scheme = isLocal ? 'http' : 'https';
  final port = isLocal ? ':8000' : '';
  return '$scheme://$host$port/api/v1';
}

Map<String, String> get _authHeaders {
  final session = Supabase.instance.client.auth.currentSession;
  return {
    'Content-Type': 'application/json',
    if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
  };
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
    _startSseStream(idea, controller, category: category).catchError((
      Object err,
    ) {
      if (!controller.isClosed) {
        controller.add(
          SseEvent(event: 'error', data: {'message': err.toString()}),
        );
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

      final request =
          http.Request('POST', Uri.parse('$_baseUrl/validate/stream'))
            ..headers.addAll(_authHeaders)
            ..headers['Accept'] = 'text/event-stream'
            ..headers['Cache-Control'] = 'no-cache'
            ..body = jsonEncode(payload);

      final streamedResponse = await client
          .send(request)
          .timeout(
            _connectionTimeout,
            onTimeout: () =>
                throw TimeoutException('Connection to backend timed out'),
          );

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        throw Exception('HTTP ${streamedResponse.statusCode}: $body');
      }

      String currentEvent = 'message';
      String currentData = '';

      await for (final line
          in streamedResponse.stream
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
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        request.headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
            throw TimeoutException('Transcription request timed out'),
      );
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        return (jsonDecode(body) as Map<String, dynamic>)['transcript']
            as String?;
      }
    } catch (e) {
      // ignore, caller handles null return
    }
    return null;
  }

  /// Fetch all active (pending/running) validation jobs.
  static Future<List<Map<String, dynamic>>> fetchActiveJobs() async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/validation-jobs'), headers: _authHeaders)
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(body['jobs'] as List);
      }
    } catch (_) {}
    return [];
  }

  /// Fetch a single validation job by ID (for poll mode).
  static Future<Map<String, dynamic>?> fetchValidationJob(String jobId) async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/validation-jobs/$jobId'), headers: _authHeaders)
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Cancel a running validation job.
  static Future<void> cancelValidationJob(String jobId) async {
    try {
      await http
          .post(Uri.parse('$_baseUrl/validation-jobs/$jobId/cancel'), headers: _authHeaders)
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Delete all validations and validation_jobs via the backend.
  static Future<void> clearAllHistory() async {
    final resp = await http
        .delete(Uri.parse('$_baseUrl/history'), headers: _authHeaders)
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Failed to clear history: ${resp.body}');
    }
  }

  static Future<void> registerPushToken({
    required String token,
    required String platform,
  }) async {
    final uri = Uri.parse('$_baseUrl/push-tokens');
    final resp = await http
        .post(
          uri,
          headers: _authHeaders,
          body: jsonEncode({'token': token, 'platform': platform}),
        )
        .timeout(
          _connectionTimeout,
          onTimeout: () =>
              throw TimeoutException('Push token registration timed out'),
        );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Push token registration failed: ${resp.body}');
    }
  }

  static Future<void> unregisterPushToken(String token) async {
    final uri = Uri.parse('$_baseUrl/push-tokens/unregister');
    final resp = await http
        .post(
          uri,
          headers: _authHeaders,
          body: jsonEncode({'token': token}),
        )
        .timeout(
          _connectionTimeout,
          onTimeout: () =>
              throw TimeoutException('Push token unregister timed out'),
        );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Push token unregister failed: ${resp.body}');
    }
  }
}
