import '../../data/vat_check_repository.dart';
import '../../domain/company_profile.dart';
import 'vat_id_format.dart';
import 'vies_client.dart';

/// UID-Prüfung mit Protokoll (Lastenheft L-1.3).
///
/// Automatisch nur nach Opt-in (`CompanyProfile.vatCheckEnabled`): beim Start
/// und beim Zurückkehren in die App, wenn die letzte Runde
/// [CompanyProfile.vatCheckIntervalDays] Tage zurückliegt. Eine echte
/// Hintergrundausführung ist auf iOS nicht planbar; „wöchentlich" heißt daher
/// „bei der ersten Nutzung nach sieben Tagen".
class VatCheckService {
  VatCheckService(this._repository, {ViesClient? client})
    : _client = client ?? ViesClient();

  final VatCheckRepository _repository;
  final ViesClient _client;

  /// Prüft eine UID und protokolliert das Ergebnis.
  Future<VatCheck> check(
    String vatId, {
    required CompanyProfile profile,
    required String subject,
    int? subjectId,
    DateTime? now,
  }) async {
    final result = await _client.check(
      vatId,
      requesterVatId: profile.vatId,
      now: now,
    );
    // Formatfehler verlassen das Gerät nicht und werden nicht protokolliert.
    if (result.result != VatCheckResult.formatError) {
      await _repository.record(result, subject: subject, subjectId: subjectId);
    }
    return result;
  }

  /// Wöchentliche Runde: eigene UID und UIDs aktiver Kunden. Seriell, mit
  /// Pause zwischen den Abfragen, damit VIES nicht drosselt.
  Future<int> runIfDue(
    CompanyProfile profile, {
    DateTime? now,
    Duration pause = const Duration(seconds: 1),
  }) async {
    final at = now ?? DateTime.now();
    if (!profile.vatCheckDue(at)) return 0;

    final targets = <(String, int?, String)>[
      if (profile.vatId.trim().isNotEmpty)
        (VatCheckRepository.subjectCompany, 1, profile.vatId),
      for (final (id, vatId) in await _repository.activeCustomerVatIds(at))
        (VatCheckRepository.subjectCustomer, id, vatId),
    ];
    var checked = 0;
    for (final (subject, id, vatId) in targets) {
      if (VatIdFormat.check(vatId) != null) continue;
      if (checked > 0) await Future<void>.delayed(pause);
      await check(
        VatIdFormat.normalize(vatId),
        profile: profile,
        subject: subject,
        subjectId: id,
        now: at,
      );
      checked++;
    }
    await _repository.markRun(at);
    return checked;
  }
}
