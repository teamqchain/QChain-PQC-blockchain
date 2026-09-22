import 'package:qportal_webapp/models/ISSUER/credentials_model.dart';
import 'package:qportal_webapp/models/VERIFIER/policy_model.dart';
import 'package:qportal_webapp/models/VERIFIER/verifyResult_enum.dart';
import 'package:qportal_webapp/models/helper/statusParser.dart';
import 'package:qportal_webapp/utils/dateFormatter.dart';


enum InvalidReason { revoked, expired, suspended, tampered, notFound }

class VerificationResult {
  final CredentialRecord? credential;
  final InvalidReason? invalidReason;
  final List<PolicyCheck> policyChecks;
  final String verifiedAt;

  const VerificationResult({
    this.credential,
    this.invalidReason,
    this.policyChecks = const [],
    required this.verifiedAt,
  });

  bool get isValid => invalidReason == null && credential != null;

  VerifyResult toVerifyResult() {
    if (isValid) return VerifyResult.valid;
    switch (invalidReason) {
      case InvalidReason.revoked:
        return VerifyResult.revoked;
      case InvalidReason.expired:
        return VerifyResult.expired;
      case InvalidReason.suspended:
        return VerifyResult.suspended;
      case InvalidReason.tampered:
        return VerifyResult.tampered;
      default:
        return VerifyResult.notFound;
    }
  }

  factory VerificationResult.fromJson(
    Map<String, dynamic> body,
    String credentialID,
  ) {
    final verified = body['verified'] as bool? ?? false;
    final credType = body['credentialType'] as String? ?? '';
    final holderName = body['holderName'] as String? ?? '';
    final issuedAt = body['issuedAt'] as String? ?? '';
    final rawExpiry = body['expiryDate'] as String?;
    final issuer = body['issuer'] as String? ?? 'University of Sharjah';
    final status = body['status'] as String? ?? '';
    // resolveSession puts disclosed body fields in credentialData (Track H).
    final credData =
        (body['credentialData'] as Map?)?.cast<String, dynamic>() ?? {};
    final attributes = <String, String>{};
    credData.forEach((k, v) {
      if (k.isEmpty) return;
      attributes[k] = v?.toString() ?? '';
    });

    final cred = CredentialRecord(
      holderEmiratesID: body['holderEID'] as String? ?? '',
      id: body['credentialID'] as String? ?? credentialID,
      holderName: holderName,
      holderEmail: body['holderEmail'] as String? ?? '',
      holderId: body['holderID'] as String? ?? '',
      credentialType: credType,
      issuedBy: issuer,
      issueDate: DateFormatter.formatIsoDate(issuedAt),
      expiryDate: (rawExpiry != null && rawExpiry.trim().isNotEmpty)
          ? DateFormatter.formatIsoDate(rawExpiry)
          : null,
      status: parseStatus(status),
      auditTrail: const [],
      attributes: attributes,
    );

    final checks = (body['checks'] as Map?)?.cast<String, dynamic>() ?? {};
    final policyChecks = _buildPolicyChecks(checks);

    if (!verified) {
      // Prefer status/reason from backend; fall back to crypto checks so a
      // failed holder sig / field hash is NOT shown as "credential not found".
      final reason = (body['reason'] as String?)?.toUpperCase();
      final invalidReason = _mapInvalidReason(
        reason: reason,
        status: status,
        checks: checks,
      );

      return VerificationResult(
        invalidReason: invalidReason,
        credential: cred,
        policyChecks: policyChecks,
        verifiedAt: DateTime.now().toString(),
      );
    }

    return VerificationResult(
      invalidReason: null,
      credential: cred,
      policyChecks: policyChecks,
      verifiedAt: DateTime.now().toString(),
    );
  }

  static List<PolicyCheck> _buildPolicyChecks(Map<String, dynamic> checks) {
    return [
      PolicyCheck(
        label: 'Exists on Blockchain',
        passed: checks['existsOnChain'] as bool? ?? false,
      ),
      PolicyCheck(
        label: 'Not Revoked',
        passed: checks['notRevoked'] as bool? ?? false,
      ),
      PolicyCheck(
        label: 'Issuer Signature Valid (ML-DSA-44)',
        passed: checks['signatureValid'] as bool? ?? false,
      ),
      PolicyCheck(
        label: 'Field Hashes Valid (SHA3-256)',
        passed: checks['fieldHashesValid'] as bool? ?? false,
      ),
      PolicyCheck(
        label: 'Holder Signature Valid (ML-DSA-44)',
        passed: checks['holderSignatureValid'] as bool? ?? false,
      ),
    ];
  }

  /// Map backend status / checks → UI reason. Crypto failures → tampered.
  static InvalidReason _mapInvalidReason({
    required String? reason,
    required String status,
    required Map<String, dynamic> checks,
  }) {
    final r = reason ?? '';
    final st = status.toLowerCase();

    if (r == 'REVOKED' || st == 'revoked') return InvalidReason.revoked;
    if (r == 'SUSPENDED' || st == 'suspended') return InvalidReason.suspended;
    if (r == 'EXPIRED' || st == 'expired') return InvalidReason.expired;
    if (r == 'TAMPERED' ||
        r == 'SIGNATURE_INVALID' ||
        r == 'FIELD_HASHES_INVALID' ||
        r == 'HOLDER_SIGNATURE_INVALID' ||
        r == 'HASH_MISMATCH') {
      return InvalidReason.tampered;
    }
    if (r == 'NOT_FOUND') return InvalidReason.notFound;

    // No explicit reason: derive from Track H check flags.
    final exists = checks['existsOnChain'] as bool? ?? true;
    final notRevoked = checks['notRevoked'] as bool? ?? true;
    final sigOk = checks['signatureValid'] as bool? ?? true;
    final fieldsOk = checks['fieldHashesValid'] as bool? ?? true;
    final holderOk = checks['holderSignatureValid'] as bool? ?? true;

    if (!exists) return InvalidReason.notFound;
    if (!notRevoked) {
      if (st == 'suspended') return InvalidReason.suspended;
      if (st == 'expired') return InvalidReason.expired;
      return InvalidReason.revoked;
    }
    if (!sigOk || !fieldsOk || !holderOk) return InvalidReason.tampered;

    // Credential was found but verification failed for an unspecified reason.
    return InvalidReason.tampered;
  }
}


