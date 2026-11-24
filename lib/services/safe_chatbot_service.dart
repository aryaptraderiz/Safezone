import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SafeChatbotService {
  SafeChatbotService._();

  // Set this when building after deploying the Cloudflare Worker:
  // --dart-define=SAFEZONE_CHAT_ENDPOINT=https://<worker>.<account>.workers.dev
  static const String _endpoint = String.fromEnvironment(
    'SAFEZONE_CHAT_ENDPOINT',
  );

  static Future<String> sendMessage(List<Map<String, String>> messages) async {
    if (_endpoint.isEmpty) {
      throw StateError('SafeBot Worker belum dikonfigurasi.');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Masuk ke SafeZone untuk memakai SafeBot AI.');
    }
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Sesi login tidak tersedia.');
    }

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'messages': messages}),
        )
        .timeout(const Duration(seconds: 45));

    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['error'] : null;
      if (response.statusCode == 429) {
        throw SafeChatbotRateLimitException(
          message is String
              ? message
              : 'Chat terlalu cepat. Tunggu sebentar lalu coba lagi.',
        );
      }
      throw Exception(
          message is String ? message : 'SafeBot AI tidak tersedia.');
    }
    if (decoded is! Map || decoded['reply'] is! String) {
      throw const FormatException('Format jawaban SafeBot tidak valid.');
    }
    return (decoded['reply'] as String).trim();
  }
}

class SafeChatbotRateLimitException implements Exception {
  final String message;

  const SafeChatbotRateLimitException(this.message);

  @override
  String toString() => message;
}
