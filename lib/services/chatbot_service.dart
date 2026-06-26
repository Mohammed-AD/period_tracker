import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cycle_entry.dart';
import '../services/cycle_analyzer.dart';
 
class ChatbotService {
  static const String _baseUrl = 'https://be-chatbot-jozi.onrender.com';
  static const String _chatEndpoint = '$_baseUrl/chat';
 
  static const List<String> _fallbackRoutes = [
    '$_baseUrl/api/chat',
    '$_baseUrl/message',
    '$_baseUrl/api/message',
  ];
 
  static String? _workingEndpoint;
  static final List<Map<String, String>> _history = [];
 
  static void clearHistory() => _history.clear();
 
  // ── Render cold start ke liye server wake karo ─────────────────
  static Future<void> _wakeServer() async {
    try {
      await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Silently ignore — sirf wake karna tha
    }
  }
 
  // ──────────────────────────────────────────────────────────────
  //  PUBLIC: sendMessage
  // ──────────────────────────────────────────────────────────────
  static Future<String> sendMessage({
    required String userMessage,
    required List<CycleEntry> cycleHistory,
  }) async {
    _wakeServer(); // await mat karo — background mein chale
    final context = _buildContext(cycleHistory);
 
    _history.add({'role': 'user', 'content': userMessage.trim()});
 
    String reply;
 
    if (_workingEndpoint != null) {
      reply = await _postToEndpoint(
        _workingEndpoint!, userMessage, context, _history,
      );
    } else {
      reply = await _tryEndpoints(userMessage, context);
    }
 
    _history.add({'role': 'assistant', 'content': reply});
 
    if (_history.length > 20) {
      _history.removeRange(0, _history.length - 20);
    }
 
    return reply;
  }
 
  // ──────────────────────────────────────────────────────────────
  //  PRIVATE HELPERS
  // ──────────────────────────────────────────────────────────────
 
  static Future<String> _tryEndpoints(
    String userMessage,
    Map<String, dynamic> context,
  ) async {
    final endpoints = [_chatEndpoint, ..._fallbackRoutes];
    for (final url in endpoints) {
      try {
        final result = await _postToEndpoint(
          url, userMessage, context, _history,
        );
        if (!result.startsWith('⚠️') && !result.startsWith('❌')) {
          _workingEndpoint = url;
        }
        return result;
      } on _EndpointNotFoundException {
        continue;
      } catch (_) {
        break;
      }
    }
    if (_history.isNotEmpty) _history.removeLast();
    return _offlineFallback(userMessage, []);
  }
 
  static Future<String> _postToEndpoint(
    String url,
    String userMessage,
    Map<String, dynamic> context,
    List<Map<String, String>> history,
  ) async {
    final response = await http
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'message': userMessage,
            'context': context,
            'history': history,
          }),
        )
        .timeout(const Duration(seconds: 60)); // ← 30 se 60 kiya
 
    if (response.statusCode == 404) throw _EndpointNotFoundException();
 
    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = data['reply'] as String? ??
            data['response'] as String? ??
            data['text'] as String? ??
            data['answer'] as String? ??
            data['message'] as String?;
        return reply ?? "I didn't get a clear response. Could you try again?";
      } catch (_) {
        final body = response.body.trim();
        if (body.isNotEmpty) return body;
        return "Got an empty response from the server. Please try again.";
      }
    }
 
    return '⚠️ Server returned error ${response.statusCode}. Please try again.';
  }
 
  // ──────────────────────────────────────────────────────────────
  //  CONTEXT BUILDER
  // ──────────────────────────────────────────────────────────────
  static Map<String, dynamic> _buildContext(List<CycleEntry> entries) {
    final analyzer = CycleAnalyzer(entries);
    final predicted = analyzer.predictedNextPeriodStart;
 
    return {
      'averageCycleLength': analyzer.averageCycleLength?.round(),
      'averagePeriodLength': analyzer.averagePeriodLength?.round(),
      'lastPeriodStart': entries.isNotEmpty
          ? entries.first.startDate.toIso8601String()
          : null,
      'predictedNextPeriod': predicted?.toIso8601String(),
      'recentSymptoms': entries.isNotEmpty ? entries.first.symptoms : [],
      'cyclesLogged': entries.length,
    };
  }

  // ──────────────────────────────────────────────────────────────
  //  OFFLINE FALLBACK
  // ──────────────────────────────────────────────────────────────
  static Future<String> _offlineFallback(
    String userMessage,
    List<CycleEntry> entries,
  ) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final msg = userMessage.toLowerCase();
    final analyzer = CycleAnalyzer(entries);

    if (msg.contains('next period') || msg.contains('when')) {
      final next = analyzer.predictedNextPeriodStart;
      if (next != null) {
        return "Based on your logged cycles, your next period is predicted around "
            "${next.day}/${next.month}/${next.year}. Remember, this is just an estimate.";
      }
      return "I need at least two logged periods to predict your next one.";
    }
    if (msg.contains('cramp') || msg.contains('pain')) {
      return "Cramps are caused by uterine contractions. A heating pad, gentle movement, "
          "and staying hydrated can help. If pain is severe or disrupts daily life, "
          "please see a doctor.";
    }
    if (msg.contains('late') || msg.contains('missed')) {
      return "A late or missed period can happen due to stress, weight changes, travel, "
          "or hormonal shifts. If it's been more than 45 days or you suspect pregnancy, "
          "please consult a doctor.";
    }
    if (msg.contains('bloat')) {
      return "Bloating around your period is caused by hormonal water retention. "
          "Reducing salt, staying hydrated, and light exercise can help.";
    }
    if (msg.contains('healthy') || msg.contains('normal')) {
      final insight = analyzer.analyze();
      return "${insight.summary} "
          "${insight.recommendations.isNotEmpty ? insight.recommendations.first : ''}";
    }

    return "❌ Couldn't reach the server right now. Check your connection and try again.\n\n"
        "Offline, I can help with: next period prediction, cramps, late periods, "
        "bloating, or cycle health questions.";
  }
}

class _EndpointNotFoundException implements Exception {}