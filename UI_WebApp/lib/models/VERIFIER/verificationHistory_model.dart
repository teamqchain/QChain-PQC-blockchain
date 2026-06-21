import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/VERIFIER/verifyResult_enum.dart';
import 'package:qportal_webapp/models/helper/verifyMethod_parser.dart';
import 'package:qportal_webapp/models/helper/verifyResult_perser.dart';
import 'package:qportal_webapp/utils/dateFormatter.dart';

class VerificationHistoryRecord {
  final String id;
  final String credID;
  final String credentialType;
  final String holderName;
  final String issuerName;
  final VerifyResult result;
  final VerifyMethod method;
  final String verifiedBy;
  final String verifiedAt;

  const VerificationHistoryRecord({
    required this.id,
    required this.credID,
    required this.credentialType,
    required this.holderName,
    required this.issuerName,
    required this.result,
    required this.method,
    required this.verifiedBy,
    required this.verifiedAt,
  });

  factory VerificationHistoryRecord.fromJson(
    Map<String, dynamic> e,
  ) {
    // final dt = DateTime.tryParse(e['verifiedAt'] as String? ?? '') ?? DateTime.now();
    return VerificationHistoryRecord(
      id: e['id'] as String? ?? '',
      credID: e['credentialID'] as String? ?? '',
      credentialType: e['credentialType'] as String? ?? '',
      holderName: e['holderName'] as String? ?? '',
      issuerName: e['issuerName'] as String? ?? '',
      result: parseVerifyResult(e['result'] as String? ?? ''),
      method: parseVerifyMethod(e['method'] as String? ?? ''),
      verifiedBy: e['verifiedBy'] as String? ?? '',
      verifiedAt: e['verifiedAt'] as String? ?? '',
    );
  }
}

enum VerifyMethod { qrScan, manual, fileUpload, batch }

extension VerifyMethodX on VerifyMethod {
  String get label {
    switch (this) {
      case VerifyMethod.qrScan:
        return 'QR Scan';
      case VerifyMethod.manual:
        return 'Manual';
      case VerifyMethod.fileUpload:
        return 'File Upload';
      case VerifyMethod.batch:
        return 'Batch';
    }
  }

  IconData get icon {
    switch (this) {
      case VerifyMethod.qrScan:
        return Icons.qr_code_scanner_rounded;
      case VerifyMethod.manual:
        return Icons.keyboard_outlined;
      case VerifyMethod.fileUpload:
        return Icons.upload_file_outlined;
      case VerifyMethod.batch:
        return Icons.layers_outlined;
    }
  }
}
