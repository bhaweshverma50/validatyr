import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResearchApiService {
  static String get _baseUrl {
    final host = dotenv.env['BACKEND_HOST'] ?? '127.0.0.1';
    final isLocal = host == '127.0.0.1' || host == 'localhost' || host.startsWith('192.168.');
    final scheme = isLocal ? 'http' : 'https';
    final port = isLocal ? ':8000' : '';
    return '$scheme://$host$port/api/v1/research';
  }

  static Map<String, String> get _headers {
    final session = Supabase.instance.client.auth.currentSession;
    return {
      'Content-Type': 'application/json',
      if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
    };
  }

  static Future<Map<String, dynamic>> createTopic({
    required String domain,
    required List<String> keywords,
    List<String> interests = const [],
    String? scheduleCron,
    bool startImmediately = true,
    String? timezone,
  }) async {
    // Auto-detect device timezone if not provided
    final tz = timezone ?? await FlutterTimezone.getLocalTimezone();

    final response = await http.post(
      Uri.parse('$_baseUrl/topics'),
      headers: _headers,
      body: jsonEncode({
        'domain': domain,
        'keywords': keywords,
        'interests': interests,
        'schedule_cron': scheduleCron,
        'start_immediately': startImmediately,
        'timezone': tz,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to create topic: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  static Future<List<Map<String, dynamic>>> getTopics() async {
    final response = await http.get(Uri.parse('$_baseUrl/topics'), headers: _headers);
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['topics'] ?? []);
  }

  static Future<void> updateTopic(String topicId, Map<String, dynamic> updates) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/topics/$topicId'),
      headers: _headers,
      body: jsonEncode(updates),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update topic: ${response.body}');
    }
  }

  static Future<void> deleteTopic(String topicId) async {
    final response = await http.delete(Uri.parse('$_baseUrl/topics/$topicId'), headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete topic: ${response.body}');
    }
  }

  static Future<void> startResearch(String topicId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/start'),
      headers: _headers,
      body: jsonEncode({'topic_id': topicId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to start research: ${response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> getReports(String topicId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/reports?topic_id=$topicId'),
      headers: _headers,
    );
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['reports'] ?? []);
  }

  static Future<Map<String, dynamic>?> getReport(String reportId) async {
    final response = await http.get(Uri.parse('$_baseUrl/reports/$reportId'), headers: _headers);
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>?> getLatestJob(String topicId) async {
    final response = await http.get(Uri.parse('$_baseUrl/topics/$topicId/latest-job'), headers: _headers);
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    return data['job'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> getJobStatus(String jobId) async {
    final response = await http.get(Uri.parse('$_baseUrl/status/$jobId'), headers: _headers);
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body);
  }

  static Future<void> cancelJob(String jobId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/jobs/$jobId/cancel'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to cancel job: ${response.body}');
    }
  }

  static Future<void> toggleTopicActive(String topicId, bool isActive) async {
    await updateTopic(topicId, {'is_active': isActive});
  }
}
