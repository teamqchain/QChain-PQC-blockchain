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
    //final expiryDate = body['expiryDate'] as String? ?? '';
    final issuer = body['issuer'] as String? ?? 'University of Sharjah';
    final status = body['status'] as String? ?? '';
    final credData =
        (body['credentialData'] as Map?)?.cast<String, dynamic>() ?? {};
    final attributes = credData.map((k, v) => MapEntry(k, v?.toString() ?? ''));

    final cred = CredentialRecord(
      holderEmiratesID: body['holderEID'] as String? ?? '',
      id: body['credentialID'] as String? ?? credentialID,
      holderName: holderName,
      holderEmail: body['holderEmail'] as String? ?? '',
      holderId: body['holderID'] as String? ?? '',
      credentialType: credType,
      issuedBy: issuer,
      issueDate: DateFormatter.formatIsoDate(issuedAt),
      //expiryDate: expiryDate != null ? formatIsoDate(expiryDate) : null,
      status: parseStatus(status),
      auditTrail: const [],
      attributes: attributes,
    );

    if (!verified) {
      final reason = body['reason'] as String?;
      InvalidReason invalidReason;
      if (reason == 'REVOKED') {
        invalidReason = InvalidReason.revoked;
      } else if (reason == 'SUSPENDED')
        invalidReason = InvalidReason.suspended;
      else if (reason == 'EXPIRED')
        invalidReason = InvalidReason.expired;
      else if (reason == 'TAMPERED')
        invalidReason = InvalidReason.tampered;
      else
        invalidReason = InvalidReason.notFound;

      return VerificationResult(
        invalidReason: invalidReason,
        credential: cred,
        policyChecks: const [],
        verifiedAt: DateTime.now().toString(),
      );
    }

    final checks = (body['checks'] as Map?)?.cast<String, dynamic>() ?? {};
    final policyChecks = [
      PolicyCheck(
        label: 'Exists on Blockchain',
        passed: checks['existsOnChain'] as bool? ?? false,
      ),
      PolicyCheck(
        label: 'Not Revoked',
        passed: checks['notRevoked'] as bool? ?? false,
      ),
      PolicyCheck(
        label: 'Signature Valid (ML-DSA-44)',
        passed: checks['signatureValid'] as bool? ?? false,
      ),
      PolicyCheck(
        label: 'Hash Matches',
        passed: checks['hashMatches'] as bool? ?? false,
      ),
    ];

    return VerificationResult(
      invalidReason: null,
      credential: cred,
      policyChecks: policyChecks,
      verifiedAt: DateTime.now().toString(),
    );
  }
}


