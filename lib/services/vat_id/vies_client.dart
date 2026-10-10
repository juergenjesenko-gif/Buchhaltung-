import 'dart:convert';
import 'dart:io';

import 'vat_id_format.dart';

/// Ergebnis einer UID-Prüfung. Bewusst dreiwertig: ein Ausfall von VIES ist
/// kein Beweis für eine ungültige Nummer.
enum VatCheckResult {
  valid,
  invalid,

  /// VIES oder der Mitgliedstaat war nicht erreichbar.
  unavailable,

  /// Schon das Format stimmt nicht; es wurde nichts übertragen.
  formatError,
}

class VatCheck {
  const VatCheck({
    required this.vatId,
    required this.result,
    required this.checkedAt,
    this.name = '',
    this.address = '',
    this.requestIdentifier = '',
    this.errorCode = '',
  });

  final String vatId;
  final VatCheckResult result;
  final DateTime checkedAt;

  /// Name und Anschrift laut VIES; Deutschland liefert sie meist nicht.
  final String name;
  final String address;

  /// Abfragenummer der Kommission. Gibt es nur, wenn die eigene UID als
  /// Anfragende mitgeschickt wird; sie dient als Nachweis der Prüfung.
  final String requestIdentifier;
  final String errorCode;

  Map<String, Object?> toJson() => {
    'vat_id': vatId,
    'result': result.name,
    'checked_at': checkedAt.toIso8601String(),
    'name': name,
    'address': address,
    'request_identifier': requestIdentifier,
    'error_code': errorCode,
  };
}

/// Sendet eine Anfrage an VIES und liefert die rohe JSON-Antwort. Austauschbar,
/// damit Tests ohne Netz laufen.
typedef ViesTransport =
    Future<Map<String, Object?>> Function(Map<String, Object?> body);

/// Abfrage über die REST-Schnittstelle der Europäischen Kommission (VIES).
/// Direkt vom Gerät, ohne Server des Anbieters.
class ViesClient {
  ViesClient({ViesTransport? transport})
    : _transport = transport ?? _httpTransport;

  final ViesTransport _transport;

  static final endpoint = Uri.parse(
    'https://ec.europa.eu/taxation_customs/vies/rest-api/check-vat-number',
  );

  /// Prüft [vatId]. Mit [requesterVatId] (eigene UID) liefert VIES eine
  /// Abfragenummer als Nachweis.
  Future<VatCheck> check(
    String vatId, {
    String? requesterVatId,
    DateTime? now,
  }) async {
    final checkedAt = now ?? DateTime.now();
    final normalized = VatIdFormat.normalize(vatId);
    if (VatIdFormat.check(normalized) != null) {
      return VatCheck(
        vatId: normalized,
        result: VatCheckResult.formatError,
        checkedAt: checkedAt,
      );
    }
    final body = <String, Object?>{
      'countryCode': VatIdFormat.countryCode(normalized),
      'vatNumber': VatIdFormat.number(normalized),
    };
    final requester = requesterVatId == null
        ? ''
        : VatIdFormat.normalize(requesterVatId);
    if (requester.isNotEmpty && VatIdFormat.check(requester) == null) {
      body['requesterMemberStateCode'] = VatIdFormat.countryCode(requester);
      body['requesterNumber'] = VatIdFormat.number(requester);
    }

    try {
      return parse(normalized, await _transport(body), checkedAt);
    } on Object {
      return VatCheck(
        vatId: normalized,
        result: VatCheckResult.unavailable,
        checkedAt: checkedAt,
        errorCode: 'NETWORK',
      );
    }
  }

  /// Wertet die Antwort aus. Öffentlich für Tests.
  static VatCheck parse(
    String vatId,
    Map<String, Object?> json,
    DateTime checkedAt,
  ) {
    final error = json['userError'] as String?;
    final hasErrors =
        (error != null && error != 'VALID' && error != 'INVALID') ||
        json['errorWrappers'] != null;
    if (hasErrors || json['valid'] == null) {
      final wrappers = json['errorWrappers'];
      final code =
          error ??
          (wrappers is List && wrappers.isNotEmpty
              ? (wrappers.first as Map)['error']?.toString()
              : null) ??
          'UNKNOWN';
      return VatCheck(
        vatId: vatId,
        result: VatCheckResult.unavailable,
        checkedAt: checkedAt,
        errorCode: code,
      );
    }
    String clean(Object? value) {
      final text = (value as String?)?.trim() ?? '';
      return text == '---' ? '' : text;
    }

    return VatCheck(
      vatId: vatId,
      result: json['valid'] == true
          ? VatCheckResult.valid
          : VatCheckResult.invalid,
      checkedAt: checkedAt,
      name: clean(json['name']),
      address: clean(json['address']),
      requestIdentifier: clean(json['requestIdentifier']),
    );
  }

  static Future<Map<String, Object?>> _httpTransport(
    Map<String, Object?> body,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(endpoint);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final text = await response.transform(utf8.decoder).join();
      return jsonDecode(text) as Map<String, Object?>;
    } finally {
      client.close();
    }
  }
}
