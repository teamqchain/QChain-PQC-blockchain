import 'package:qportal_webapp/models/ISSUER/credentials_model.dart';
import 'package:qportal_webapp/models/VERIFIER/policy_model.dart';
import 'package:qportal_webapp/models/VERIFIER/verificationHistory_model.dart';
import 'package:qportal_webapp/models/VERIFIER/verificationResult_model.dart';
import 'package:qportal_webapp/models/VERIFIER/verifyResult_enum.dart';
import 'package:qportal_webapp/models/helper/verifyMethod_parser.dart';
import 'package:qportal_webapp/models/helper/verifyResult_perser.dart';
import 'package:qportal_webapp/utils/dateFormatter.dart';

class VerificationDetailData {
  final VerificationHistoryRecord historyRecord;
  final VerificationResult result;

  const VerificationDetailData({
    required this.historyRecord,
    required this.result,
  });

  factory VerificationDetailData.fromJson(Map<String, dynamic> e) {
    final dateTime = DateTime.tryParse(e['verifiedAt'] as String? ?? '') ?? DateTime.now();
    final resultStr = e['result'] as String? ?? '';
    final reasonStr = e['reason'] as String?;
    final verifyResult = parseVerifyResult(resultStr);

    final historyRecord = VerificationHistoryRecord(
      id: e['id'] as String? ?? '',
      credID: e['credentialID'] as String? ?? '',
      credentialType: e['credentialType'] as String? ?? '',
      holderName: e['holderName'] as String? ?? '',
      issuerName: e['issuerName'] as String? ?? '',
      result: verifyResult,
      method: parseVerifyMethod(e['method'] as String? ?? ''),
      verifiedBy: e['verifiedBy'] as String? ?? '',
      verifiedAt: e['verifiedAt'] as String? ?? '',
    );

    final rawExpiry = e['expiryDate'] as String?;

    final cred = CredentialRecord(
      id: e['credentialID'] as String? ?? '',
      holderName: e['holderName'] as String? ?? '',
      holderEmail: '',
      holderId: e['holderID'] as String? ?? '',
      holderEmiratesID: '',
      credentialType: e['credentialType'] as String? ?? '',
      issuedBy: e['issuerName'] as String? ?? '',
      issueDate: DateFormatter.formatIsoDate(e['issuedAt'] as String? ?? ''),
      // expiryDate: DateFormatter.formatIsoDate(e['expiryDate'] as String?),
      expiryDate: (rawExpiry != null && rawExpiry.trim().isNotEmpty)
          ? DateFormatter.formatIsoDate(rawExpiry)
          : null,
      status: _parseStatusFromVerifyResult(verifyResult),
      auditTrail: const [],
      attributes: const {},
    );

    final InvalidReason? invalidReason = verifyResult == VerifyResult.valid
        ? null
        : _parseInvalidReason(resultStr, reasonStr);
    final checks = (e['checks'] as Map?)?.cast<String, dynamic>() ?? {};

    final policyChecks = [
      PolicyCheck(
        label: 'Exists on Blockchain',
        passed:
            checks['existsOnChain'] as bool? ??
            (invalidReason != InvalidReason.notFound),
      ),
      PolicyCheck(
        label: 'Not Revoked',
        passed:
            checks['notRevoked'] as bool? ??
            (invalidReason != InvalidReason.revoked &&
                invalidReason != InvalidReason.suspended),
      ),
      PolicyCheck(
        label: 'Signature Valid (ML-DSA-44)',
        passed:
            checks['signatureValid'] as bool? ??
            (invalidReason != InvalidReason.tampered),
      ),
      PolicyCheck(
        label: 'Hash Matches',
        passed:
            checks['hashMatches'] as bool? ??
            (invalidReason != InvalidReason.tampered),
      ),
    ];

    final result = VerificationResult(
      invalidReason: invalidReason,
      credential: cred,
      policyChecks: policyChecks,
      verifiedAt: e['verifiedAt'] as String? ?? dateTime.toString(),
    );

    return VerificationDetailData(historyRecord: historyRecord, result: result);
  }

  // Verification Result Model
  static InvalidReason _parseInvalidReason(
    String resultStr,
    String? reasonStr,
  ) {
    if (reasonStr != null) {
      switch (reasonStr.toUpperCase()) {
        case 'REVOKED':
          return InvalidReason.revoked;
        case 'SUSPENDED':
          return InvalidReason.suspended;
        case 'EXPIRED':
          return InvalidReason.expired;
        case 'TAMPERED':
          return InvalidReason.tampered;
        case 'NOT_FOUND':
          return InvalidReason.notFound;
      }
    }
    switch (resultStr) {
      case 'revoked':
        return InvalidReason.revoked;
      case 'suspended':
        return InvalidReason.suspended;
      case 'expired':
        return InvalidReason.expired;
      case 'tampered':
        return InvalidReason.tampered;
      default:
        return InvalidReason.notFound;
    }
  }

  static CredentialStatus _parseStatusFromVerifyResult(VerifyResult vr) {
    switch (vr) {
      case VerifyResult.revoked:
        return CredentialStatus.revoked;
      case VerifyResult.suspended:
        return CredentialStatus.suspended;
      case VerifyResult.expired:
        return CredentialStatus.expired;
      default:
        return CredentialStatus.valid;
    }
  }
}
