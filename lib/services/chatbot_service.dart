import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cycle_entry.dart';
import '../services/cycle_analyzer.dart';

/// IMPORTANT:
/// This service NEVER calls the Gemini API directly from the app.
/// It calls YOUR backend proxy (a Firebase Cloud Function), which holds
/// the real Gemini API key server-side. This keeps your key safe even
/// after the app is published and the APK is decompiled.
///
/// See README_CHATBOT_SETUP.md for how to deploy the matching
/// Firebase Function.
class ChatbotService {
  /// Replace this with YOUR deployed Cloud Function URL after setup.
  /// Example: https://us-central1-yourproject.cloudfunctions.net/chatProxy
  static const String _endpoint = 'REPLACE_WITH_YOUR_FIREBASE_FUNCTION_URL';

  /// Sends the user's message + relevant cycle context to the backend,
  /// which forwards it to Gemini and returns the reply text.
  static Future<String> sendMessage({
    required String userMessage,
    required List<CycleEntry> cycleHistory,
  }) async {
    if (_endpoint.startsWith('REPLACE_WITH')) {
      return _offlineFallback(userMessage, cycleHistory);
    }

    try {
      final context = _buildContext(cycleHistory);

      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': userMessage,
              'context': context,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'] as String? ??
            "I'm here for you, but I didn't get a clear answer back. Try asking again?";
      } else {
        return "I'm having trouble connecting right now (error ${response.statusCode}). Please try again in a moment.";
      }
    } catch (e) {
      return "I couldn't reach the server. Check your internet connection and try again.";
    }
  }

  /// Builds a short, privacy-conscious context string summarizing the
  /// user's cycle data (no need to send full raw history every time).
  static Map<String, dynamic> _buildContext(List<CycleEntry> entries) {
    final analyzer = CycleAnalyzer(entries);
    return {
      'averageCycleLength': analyzer.averageCycleLength?.round(),
      'averagePeriodLength': analyzer.averagePeriodLength?.round(),
      'lastPeriodStart': entries.isNotEmpty
          ? entries.first.startDate.toIso8601String()
          : null,
      'recentSymptoms': entries.isNotEmpty ? entries.first.symptoms : [],
    };
  }

  /// Simple offline/local fallback so the chatbot UI is testable
  /// before you've deployed the Firebase Function + Gemini key.
  /// This is NOT real AI — just keeps the app functional during dev.
  static Future<String> _offlineFallback(
      String userMessage, List<CycleEntry> entries) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final msg = userMessage.toLowerCase();
    final analyzer = CycleAnalyzer(entries);

    if (msg.contains('next period') || msg.contains('when')) {
      final next = analyzer.predictedNextPeriodStart;
      if (next != null) {
        return "Based on your logged cycles, your next period is predicted around ${next.day}/${next.month}/${next.year}. Remember, this is an estimate — cycles can naturally shift a little.";
      }
      return "I need at least two logged periods to predict your next one. Try logging a bit more history!";
    }
    if (msg.contains('cramp') || msg.contains('pain')) {
      return "Cramps are common during periods due to uterine contractions. A heating pad, gentle movement, and staying hydrated can help. If pain is severe enough to disrupt your day, it's worth mentioning to a doctor.";
    }
    if (msg.contains('late') || msg.contains('missed')) {
      return "A late or missed period can happen for many reasons — stress, weight changes, travel, or hormonal shifts. If it's been more than 45 days, or you suspect pregnancy, please check in with a doctor.";
    }
    if (msg.contains('healthy') || msg.contains('normal')) {
      final insight = analyzer.analyze();
      return "${insight.summary} ${insight.recommendations.isNotEmpty ? insight.recommendations.first : ''}";
    }
    return "I'm your cycle assistant — once connected to the live AI backend, I'll be able to answer more naturally. For now I can help with questions about your next period, cramps, late periods, or whether your cycle looks healthy.";
  }
}
