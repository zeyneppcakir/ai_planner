// lib/services/auth_security_api.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

// Güvenlik API'den dönen hatalar için özel exception
class AuthSecurityApiException implements Exception {
  // Örn: RATE_LIMIT, IP_BLOCKED, FIREBASE_ERROR, NETWORK_TIMEOUT...
  final String code;

  // Backend'den gelen açıklama (opsiyonel)
  final String? message;

  AuthSecurityApiException(this.code, [this.message]);

  @override
  String toString() => 'AuthSecurityApiException($code, $message)';
}

// Güvenlik API (Node.js / Firebase Functions vb.) istemcisi
class AuthSecurityApi {
  AuthSecurityApi({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        // Android emülatör için 10.0.2.2
        // Gerçek cihazda test ederken burayı bilgisayarının LAN IP'si ile
        // değiştirebilirsin (örn: http://192.168.1.23:3000)
        _baseUrl = baseUrl ?? 'http://10.0.2.2:3000';

  final http.Client _client;
  final String _baseUrl;

  // Şifre sıfırlama isteği
  Future<void> forgotPassword(String email) async {
    // Backend endpoint’in ile birebir aynı olmalı:
    // Örn: app.post('/api/security/forgot-password', ...)
    final uri = Uri.parse('$_baseUrl/api/security/forgot-password');

    try {
      final resp = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 10));

      // 200 => başarılı
      if (resp.statusCode == 200) {
        return;
      }

      // Hata gövdesi
      Map<String, dynamic> bodyJson = {};
      try {
        bodyJson = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        // JSON değilse bile en azından status kodu ile genel hata fırlat
      }

      final errorCode = (bodyJson['error'] ?? '').toString();
      final message =
          (bodyJson['message'] ?? bodyJson['details'] ?? '').toString();

      // 429 - rate limit / çok sık istek
      if (resp.statusCode == 429 || errorCode == 'RATE_LIMIT') {
        throw AuthSecurityApiException(
          'RATE_LIMIT',
          message.isNotEmpty
              ? message
              : 'Too many reset requests in a short time.',
        );
      }

      // 423 veya IP_BLOCKED - IP kara liste
      if (resp.statusCode == 423 || errorCode == 'IP_BLOCKED') {
        throw AuthSecurityApiException(
          'IP_BLOCKED',
          message.isNotEmpty
              ? message
              : 'IP is temporarily blocked due to too many attempts.',
        );
      }

      // Diğer tüm backend hataları (ör: FIREBASE_ERROR)
      throw AuthSecurityApiException(
        errorCode.isNotEmpty ? errorCode : 'GENERIC',
        message.isNotEmpty ? message : 'Unknown security API error',
      );
    } on TimeoutException {
      // Direkt özel hata tipine çeviriyoruz
      throw AuthSecurityApiException(
        'NETWORK_TIMEOUT',
        'Şifre sıfırlama servisine ulaşırken zaman aşımı oluştu.',
      );
    } catch (e) {
      // Diğer her şeyi aynen yukarı fırlat
      rethrow;
    }
  }
}
