// models/verifying_models.dart
//
// Verification-specific models.
// Reuses CredentialRecord from issuing_models.dart — no duplication.

import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/issuing_models.dart';
import 'package:qportal_webapp/screens/verifier/alert_page.dart';
import 'package:qportal_webapp/screens/verifier/subscription_page.dart';
import 'package:qportal_webapp/theme/appColours.dart';

// ─── VALIDITY REASON ──────────────────────────────────────────────────────────
//
// Represents WHY a credential is invalid.
// "valid" means the credential passed all checks.

enum InvalidReason { revoked, expired, suspended, tampered, notFound }

// ─── POLICY CHECK ─────────────────────────────────────────────────────────────

class PolicyCheck {
  final String label;
  final bool passed;
  final String? note;

  const PolicyCheck({required this.label, required this.passed, this.note});
}

// ─── VERIFICATION RESULT ──────────────────────────────────────────────────────

class VerificationResult {
  /// Non-null when the credential was found on-chain.
  final CredentialRecord? credential;

  /// Null = credential is fully valid. Non-null = why it failed.
  final InvalidReason? invalidReason;

  /// Optional policy checks shown for valid credentials.
  final List<PolicyCheck> policyChecks;

  /// Timestamp of this verification event (auto-logged).
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
}

// ─── MOCK RESULTS ─────────────────────────────────────────────────────────────
//
// Six scenarios – one for each outcome type.

abstract class VerifyingMockData {
  static VerificationResult valid() => VerificationResult(
    credential: IssuingMockData.credentials.firstWhere(
      (c) => c.status == CredentialStatus.valid,
    ),
    policyChecks: const [
      PolicyCheck(label: 'Blockchain integrity', passed: true),
      PolicyCheck(label: 'Issuer authorised', passed: true),
      PolicyCheck(label: 'Schema version match', passed: true),
    ],
    verifiedAt: '11 Mar 2026  14:32',
  );

  static VerificationResult revoked() => VerificationResult(
    credential: IssuingMockData.credentials.firstWhere(
      (c) => c.status == CredentialStatus.revoked,
    ),
    invalidReason: InvalidReason.revoked,
    verifiedAt: '11 Mar 2026  14:33',
  );

  static VerificationResult expired() => VerificationResult(
    credential: IssuingMockData.credentials.firstWhere(
      (c) => c.status == CredentialStatus.expired,
    ),
    invalidReason: InvalidReason.expired,
    verifiedAt: '11 Mar 2026  14:34',
  );

  static VerificationResult suspended() => VerificationResult(
    credential: IssuingMockData.credentials.firstWhere(
      (c) => c.status == CredentialStatus.suspended,
    ),
    invalidReason: InvalidReason.suspended,
    verifiedAt: '11 Mar 2026  14:35',
  );

  static VerificationResult tampered() => VerificationResult(
    // Reuse any valid-record shell — the data "doesn't match" the chain.
    credential: IssuingMockData.credentials[2],
    invalidReason: InvalidReason.tampered,
    verifiedAt: '11 Mar 2026  14:36',
  );

  static VerificationResult notFound() => const VerificationResult(
    credential: null,
    invalidReason: InvalidReason.notFound,
    verifiedAt: '11 Mar 2026  14:37',
  );
}

// ─── VERIFY RESULT (history) ──────────────────────────────────────────────────

enum VerifyResult { valid, revoked, suspended, expired, tampered, notFound }

extension VerifyResultX on VerifyResult {
  String get label {
    switch (this) {
      case VerifyResult.valid:
        return 'Valid';
      case VerifyResult.revoked:
        return 'Revoked';
      case VerifyResult.suspended:
        return 'Suspended';
      case VerifyResult.expired:
        return 'Expired';
      case VerifyResult.tampered:
        return 'Tampered';
      case VerifyResult.notFound:
        return 'Not Found';
    }
  }

  Color get fg {
    switch (this) {
      case VerifyResult.valid:
        return AppColors.valid;
      case VerifyResult.revoked:
        return AppColors.revoked;
      case VerifyResult.suspended:
        return AppColors.suspended;
      case VerifyResult.expired:
        return AppColors.expired;
      case VerifyResult.tampered:
        return const Color(0xFFF97316);
      case VerifyResult.notFound:
        return AppColors.textDim;
    }
  }

  Color get bg {
    switch (this) {
      case VerifyResult.valid:
        return AppColors.verifyingDark;
      case VerifyResult.revoked:
        return const Color(0xFF1A0A0A);
      case VerifyResult.expired:
        return const Color(0xFF141414);
      case VerifyResult.suspended:
        return const Color(0xFF1A1200);
      case VerifyResult.tampered:
        return const Color(0xFF1A0E00);
      case VerifyResult.notFound:
        return const Color(0xFF111111);
    }
  }

  String get headerLabel {
    switch (this) {
      case VerifyResult.valid:
        return 'CREDENTIAL VALID';
      case VerifyResult.revoked:
        return 'CREDENTIAL REVOKED';
      case VerifyResult.expired:
        return 'CREDENTIAL EXPIRED';
      case VerifyResult.suspended:
        return 'CREDENTIAL SUSPENDED';
      case VerifyResult.tampered:
        return 'CREDENTIAL TAMPERED';
      case VerifyResult.notFound:
        return 'CREDENTIAL NOT FOUND';
    }
  }

  IconData get headerIcon {
    switch (this) {
      case VerifyResult.valid:
        return Icons.check_rounded;
      case VerifyResult.revoked:
        return Icons.block_rounded;
      case VerifyResult.expired:
        return Icons.schedule_rounded;
      case VerifyResult.suspended:
        return Icons.pause_circle_outline_rounded;
      case VerifyResult.tampered:
        return Icons.warning_amber_rounded;
      case VerifyResult.notFound:
        return Icons.search_off_rounded;
    }
  }
}

// ─── VERIFY METHOD ────────────────────────────────────────────────────────────

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

// ─── VERIFICATION HISTORY RECORD ──────────────────────────────────────────────

class VerificationHistoryRecord {
  final String id;
  final String date;
  final String time;
  final String credentialType;
  final String holderName;
  final String issuerName;
  final VerifyResult result;
  final VerifyMethod method;
  final String verifiedBy;

  const VerificationHistoryRecord({
    required this.id,
    required this.date,
    required this.time,
    required this.credentialType,
    required this.holderName,
    required this.issuerName,
    required this.result,
    required this.method,
    required this.verifiedBy,
  });
}

// ─── VERIFICATION HISTORY MOCK DATA ──────────────────────────────────────────

final kMockVerificationHistory = <VerificationHistoryRecord>[
  VerificationHistoryRecord(
    id: 'VH-001',
    date: '11 Mar 2026',
    time: '14:32',
    credentialType: 'Bachelor of Science',
    holderName: 'Ahmed Al Mansoori',
    issuerName: 'University of Sharjah',
    result: VerifyResult.valid,
    method: VerifyMethod.qrScan,
    verifiedBy: 'Sara K.',
  ),
  VerificationHistoryRecord(
    id: 'VH-002',
    date: '11 Mar 2026',
    time: '14:18',
    credentialType: 'Medical License',
    holderName: 'Fatima Noor',
    issuerName: 'Ministry of Health',
    result: VerifyResult.revoked,
    method: VerifyMethod.manual,
    verifiedBy: 'Omar A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-003',
    date: '11 Mar 2026',
    time: '13:55',
    credentialType: 'Diploma in Finance',
    holderName: 'Khalid Al Rashidi',
    issuerName: 'American University',
    result: VerifyResult.valid,
    method: VerifyMethod.qrScan,
    verifiedBy: 'Sara K.',
  ),
  VerificationHistoryRecord(
    id: 'VH-004',
    date: '11 Mar 2026',
    time: '13:40',
    credentialType: 'ISO Certificate',
    holderName: 'Laila Hassan',
    issuerName: 'SGS Group',
    result: VerifyResult.expired,
    method: VerifyMethod.fileUpload,
    verifiedBy: 'Mohammed A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-005',
    date: '11 Mar 2026',
    time: '13:22',
    credentialType: 'Teaching License',
    holderName: 'Yousuf Al Zaabi',
    issuerName: 'Ministry of Education',
    result: VerifyResult.suspended,
    method: VerifyMethod.qrScan,
    verifiedBy: 'Sara K.',
  ),
  VerificationHistoryRecord(
    id: 'VH-006',
    date: '11 Mar 2026',
    time: '13:01',
    credentialType: 'Engineering Cert',
    holderName: 'Noura Al Shamsi',
    issuerName: 'SQA Board',
    result: VerifyResult.tampered,
    method: VerifyMethod.manual,
    verifiedBy: 'Omar A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-007',
    date: '11 Mar 2026',
    time: '12:47',
    credentialType: 'MBA',
    holderName: 'Hamdan Al Falasi',
    issuerName: 'UAEU',
    result: VerifyResult.valid,
    method: VerifyMethod.batch,
    verifiedBy: 'Mohammed A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-008',
    date: '11 Mar 2026',
    time: '12:30',
    credentialType: 'Nursing Certificate',
    holderName: 'Mariam Al Suwaidi',
    issuerName: 'MOH',
    result: VerifyResult.notFound,
    method: VerifyMethod.qrScan,
    verifiedBy: 'Sara K.',
  ),
  VerificationHistoryRecord(
    id: 'VH-009',
    date: '11 Mar 2026',
    time: '12:14',
    credentialType: 'Bachelor of Laws',
    holderName: 'Rashed Al Nuaimi',
    issuerName: 'University of Sharjah',
    result: VerifyResult.valid,
    method: VerifyMethod.qrScan,
    verifiedBy: 'Omar A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-010',
    date: '11 Mar 2026',
    time: '11:58',
    credentialType: 'CPA Certificate',
    holderName: 'Hessa Al Ketbi',
    issuerName: 'AICPA',
    result: VerifyResult.revoked,
    method: VerifyMethod.manual,
    verifiedBy: 'Sara K.',
  ),
  VerificationHistoryRecord(
    id: 'VH-011',
    date: '11 Mar 2026',
    time: '11:41',
    credentialType: 'PhD Computer Science',
    holderName: 'Saeed Al Matrooshi',
    issuerName: 'Khalifa University',
    result: VerifyResult.valid,
    method: VerifyMethod.qrScan,
    verifiedBy: 'Mohammed A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-012',
    date: '11 Mar 2026',
    time: '11:27',
    credentialType: 'Fire Safety Cert',
    holderName: 'Shamma Al Qubaisi',
    issuerName: 'Civil Defence',
    result: VerifyResult.expired,
    method: VerifyMethod.fileUpload,
    verifiedBy: 'Omar A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-013',
    date: '11 Mar 2026',
    time: '11:10',
    credentialType: 'Master of Business',
    holderName: 'Ali Al Hammadi',
    issuerName: 'Dubai Business School',
    result: VerifyResult.valid,
    method: VerifyMethod.batch,
    verifiedBy: 'Sara K.',
  ),
  VerificationHistoryRecord(
    id: 'VH-014',
    date: '11 Mar 2026',
    time: '10:52',
    credentialType: 'Cyber Security Cert',
    holderName: 'Moza Al Sulaiti',
    issuerName: 'EC-Council',
    result: VerifyResult.tampered,
    method: VerifyMethod.qrScan,
    verifiedBy: 'Mohammed A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-015',
    date: '10 Mar 2026',
    time: '16:44',
    credentialType: 'Bachelor of Arts',
    holderName: 'Ibrahim Al Bloushi',
    issuerName: 'Zayed University',
    result: VerifyResult.valid,
    method: VerifyMethod.qrScan,
    verifiedBy: 'Omar A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-016',
    date: '10 Mar 2026',
    time: '15:30',
    credentialType: 'Pharmacist License',
    holderName: 'Aisha Al Dhaheri',
    issuerName: 'MOH',
    result: VerifyResult.valid,
    method: VerifyMethod.manual,
    verifiedBy: 'Sara K.',
  ),
  VerificationHistoryRecord(
    id: 'VH-017',
    date: '10 Mar 2026',
    time: '14:18',
    credentialType: 'Legal Practitioner',
    holderName: 'Jassim Al Mansoori',
    issuerName: 'Ministry of Justice',
    result: VerifyResult.suspended,
    method: VerifyMethod.batch,
    verifiedBy: 'Mohammed A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-018',
    date: '10 Mar 2026',
    time: '13:05',
    credentialType: 'MSc Data Science',
    holderName: 'Hind Al Ameri',
    issuerName: 'Heriot-Watt Dubai',
    result: VerifyResult.notFound,
    method: VerifyMethod.qrScan,
    verifiedBy: 'Omar A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-019',
    date: '10 Mar 2026',
    time: '12:00',
    credentialType: 'CISA Certificate',
    holderName: 'Majed Al Hosani',
    issuerName: 'ISACA',
    result: VerifyResult.valid,
    method: VerifyMethod.fileUpload,
    verifiedBy: 'Sara K.',
  ),
  VerificationHistoryRecord(
    id: 'VH-020',
    date: '10 Mar 2026',
    time: '10:45',
    credentialType: 'Driving License',
    holderName: 'Nashwa Al Kaabi',
    issuerName: 'RTA',
    result: VerifyResult.revoked,
    method: VerifyMethod.manual,
    verifiedBy: 'Mohammed A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-021',
    date: '09 Mar 2026',
    time: '17:00',
    credentialType: 'Food Safety Cert',
    holderName: 'Tariq Al Mehairi',
    issuerName: 'ADAFSA',
    result: VerifyResult.valid,
    method: VerifyMethod.qrScan,
    verifiedBy: 'Sara K.',
  ),
  VerificationHistoryRecord(
    id: 'VH-022',
    date: '09 Mar 2026',
    time: '15:50',
    credentialType: 'PMP Certificate',
    holderName: 'Wadha Al Shamsi',
    issuerName: 'PMI',
    result: VerifyResult.valid,
    method: VerifyMethod.batch,
    verifiedBy: 'Omar A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-023',
    date: '09 Mar 2026',
    time: '14:30',
    credentialType: 'Aviation License',
    holderName: 'Faisal Al Marri',
    issuerName: 'GCAA',
    result: VerifyResult.expired,
    method: VerifyMethod.qrScan,
    verifiedBy: 'Mohammed A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-024',
    date: '09 Mar 2026',
    time: '13:20',
    credentialType: 'BEd Education',
    holderName: 'Latifa Al Zaabi',
    issuerName: 'HCT',
    result: VerifyResult.valid,
    method: VerifyMethod.manual,
    verifiedBy: 'Sara K.',
  ),
  VerificationHistoryRecord(
    id: 'VH-025',
    date: '09 Mar 2026',
    time: '12:00',
    credentialType: 'CFA Level 1',
    holderName: 'Khaled Al Mulla',
    issuerName: 'CFA Institute',
    result: VerifyResult.tampered,
    method: VerifyMethod.fileUpload,
    verifiedBy: 'Omar A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-026',
    date: '08 Mar 2026',
    time: '16:30',
    credentialType: 'Veterinary License',
    holderName: 'Nadia Al Falahi',
    issuerName: 'Ministry of Climate',
    result: VerifyResult.valid,
    method: VerifyMethod.qrScan,
    verifiedBy: 'Mohammed A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-027',
    date: '08 Mar 2026',
    time: '15:00',
    credentialType: 'HR Professional',
    holderName: 'Waleed Al Suwaidi',
    issuerName: 'CIPD',
    result: VerifyResult.revoked,
    method: VerifyMethod.manual,
    verifiedBy: 'Sara K.',
  ),
  VerificationHistoryRecord(
    id: 'VH-028',
    date: '08 Mar 2026',
    time: '13:45',
    credentialType: 'MSc Nursing',
    holderName: 'Amna Al Nuaimi',
    issuerName: 'Manchester University',
    result: VerifyResult.valid,
    method: VerifyMethod.batch,
    verifiedBy: 'Omar A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-029',
    date: '07 Mar 2026',
    time: '17:15',
    credentialType: 'CCNA Certificate',
    holderName: 'Bilal Al Hashemi',
    issuerName: 'Cisco',
    result: VerifyResult.valid,
    method: VerifyMethod.qrScan,
    verifiedBy: 'Mohammed A.',
  ),
  VerificationHistoryRecord(
    id: 'VH-030',
    date: '07 Mar 2026',
    time: '14:30',
    credentialType: 'Security Guard License',
    holderName: 'Rawdha Al Khateri',
    issuerName: 'MOI',
    result: VerifyResult.notFound,
    method: VerifyMethod.manual,
    verifiedBy: 'Sara K.',
  ),
];

class SubscriptionRecord {
  final String id;
  final String holderName;
  final String holderId;
  final String credentialType;
  final String issuer;
  final String subscribedDate; // '—' when still pending / rejected
  final String expiryDate; // '—' when no expiry set yet
  final SubStatus status;

  const SubscriptionRecord({
    required this.id,
    required this.holderName,
    required this.holderId,
    required this.credentialType,
    required this.issuer,
    required this.subscribedDate,
    required this.expiryDate,
    required this.status,
  });
}

// ─── MOCK DATA ────────────────────────────────────────────────────────────────

final kMockSubscriptions = <SubscriptionRecord>[
  SubscriptionRecord(
    id: 'SUB-001',
    holderName: 'Ahmed Al Mansoori',
    holderId: 'UAE-100-2301',
    credentialType: 'Bachelor of Science',
    issuer: 'University of Sharjah',
    subscribedDate: '01 Jan 2026',
    expiryDate: '01 Jan 2027',
    status: SubStatus.active,
  ),
  SubscriptionRecord(
    id: 'SUB-002',
    holderName: 'Fatima Noor',
    holderId: 'UAE-100-5512',
    credentialType: 'Medical License',
    issuer: 'Ministry of Health',
    subscribedDate: '15 Jan 2026',
    expiryDate: '15 Jan 2027',
    status: SubStatus.active,
  ),
  SubscriptionRecord(
    id: 'SUB-003',
    holderName: 'Khalid Al Rashidi',
    holderId: 'UAE-100-7741',
    credentialType: 'Diploma in Finance',
    issuer: 'American University',
    subscribedDate: '—',
    expiryDate: '—',
    status: SubStatus.pending,
  ),
  SubscriptionRecord(
    id: 'SUB-004',
    holderName: 'Laila Hassan',
    holderId: 'UAE-100-3309',
    credentialType: 'ISO Certificate',
    issuer: 'SGS Group',
    subscribedDate: '20 Nov 2024',
    expiryDate: '20 Nov 2025',
    status: SubStatus.expired,
  ),
  SubscriptionRecord(
    id: 'SUB-005',
    holderName: 'Yousuf Al Zaabi',
    holderId: 'UAE-100-8823',
    credentialType: 'Teaching License',
    issuer: 'Ministry of Education',
    subscribedDate: '05 Feb 2026',
    expiryDate: '05 Feb 2027',
    status: SubStatus.active,
  ),
  SubscriptionRecord(
    id: 'SUB-006',
    holderName: 'Noura Al Shamsi',
    holderId: 'UAE-100-1147',
    credentialType: 'Engineering Cert',
    issuer: 'SQA Board',
    subscribedDate: '—',
    expiryDate: '—',
    status: SubStatus.rejected,
  ),
  SubscriptionRecord(
    id: 'SUB-007',
    holderName: 'Hamdan Al Falasi',
    holderId: 'UAE-100-6634',
    credentialType: 'MBA',
    issuer: 'UAEU',
    subscribedDate: '10 Dec 2025',
    expiryDate: '10 Dec 2026',
    status: SubStatus.unsubscribed,
  ),
  SubscriptionRecord(
    id: 'SUB-008',
    holderName: 'Mariam Al Suwaidi',
    holderId: 'UAE-100-2290',
    credentialType: 'Nursing Certificate',
    issuer: 'MOH',
    subscribedDate: '—',
    expiryDate: '—',
    status: SubStatus.pending,
  ),
  SubscriptionRecord(
    id: 'SUB-009',
    holderName: 'Rashed Al Nuaimi',
    holderId: 'UAE-100-4401',
    credentialType: 'Bachelor of Laws',
    issuer: 'University of Sharjah',
    subscribedDate: '18 Feb 2026',
    expiryDate: '18 Feb 2027',
    status: SubStatus.active,
  ),
  SubscriptionRecord(
    id: 'SUB-010',
    holderName: 'Hessa Al Ketbi',
    holderId: 'UAE-100-9912',
    credentialType: 'CPA Certificate',
    issuer: 'AICPA',
    subscribedDate: '—',
    expiryDate: '—',
    status: SubStatus.rejected,
  ),
  SubscriptionRecord(
    id: 'SUB-011',
    holderName: 'Saeed Al Matrooshi',
    holderId: 'UAE-100-3356',
    credentialType: 'PhD Computer Science',
    issuer: 'Khalifa University',
    subscribedDate: '22 Jan 2026',
    expiryDate: '22 Jan 2027',
    status: SubStatus.active,
  ),
  SubscriptionRecord(
    id: 'SUB-012',
    holderName: 'Shamma Al Qubaisi',
    holderId: 'UAE-100-7780',
    credentialType: 'Fire Safety Cert',
    issuer: 'Civil Defence',
    subscribedDate: '01 Mar 2025',
    expiryDate: '01 Mar 2026',
    status: SubStatus.expired,
  ),
  SubscriptionRecord(
    id: 'SUB-013',
    holderName: 'Ali Al Hammadi',
    holderId: 'UAE-100-5523',
    credentialType: 'Master of Business',
    issuer: 'Dubai Business School',
    subscribedDate: '—',
    expiryDate: '—',
    status: SubStatus.pending,
  ),
  SubscriptionRecord(
    id: 'SUB-014',
    holderName: 'Moza Al Sulaiti',
    holderId: 'UAE-100-8867',
    credentialType: 'Cyber Security Cert',
    issuer: 'EC-Council',
    subscribedDate: '14 Feb 2026',
    expiryDate: '14 Feb 2027',
    status: SubStatus.active,
  ),
  SubscriptionRecord(
    id: 'SUB-015',
    holderName: 'Ibrahim Al Bloushi',
    holderId: 'UAE-100-1102',
    credentialType: 'Bachelor of Arts',
    issuer: 'Zayed University',
    subscribedDate: '30 Nov 2024',
    expiryDate: '30 Nov 2025',
    status: SubStatus.expired,
  ),
  SubscriptionRecord(
    id: 'SUB-016',
    holderName: 'Aisha Al Dhaheri',
    holderId: 'UAE-100-6645',
    credentialType: 'Pharmacist License',
    issuer: 'MOH',
    subscribedDate: '03 Mar 2026',
    expiryDate: '03 Mar 2027',
    status: SubStatus.active,
  ),
  SubscriptionRecord(
    id: 'SUB-017',
    holderName: 'Jassim Al Mansoori',
    holderId: 'UAE-100-2278',
    credentialType: 'Legal Practitioner',
    issuer: 'Ministry of Justice',
    subscribedDate: '09 Oct 2025',
    expiryDate: '09 Oct 2026',
    status: SubStatus.unsubscribed,
  ),
  SubscriptionRecord(
    id: 'SUB-018',
    holderName: 'Hind Al Ameri',
    holderId: 'UAE-100-3391',
    credentialType: 'MSc Data Science',
    issuer: 'Heriot-Watt Dubai',
    subscribedDate: '—',
    expiryDate: '—',
    status: SubStatus.pending,
  ),
  SubscriptionRecord(
    id: 'SUB-019',
    holderName: 'Majed Al Hosani',
    holderId: 'UAE-100-7756',
    credentialType: 'CISA Certificate',
    issuer: 'ISACA',
    subscribedDate: '20 Feb 2026',
    expiryDate: '20 Feb 2027',
    status: SubStatus.active,
  ),
  SubscriptionRecord(
    id: 'SUB-020',
    holderName: 'Nashwa Al Kaabi',
    holderId: 'UAE-100-4489',
    credentialType: 'Driving License',
    issuer: 'RTA',
    subscribedDate: '—',
    expiryDate: '—',
    status: SubStatus.rejected,
  ),
  SubscriptionRecord(
    id: 'SUB-021',
    holderName: 'Tariq Al Mehairi',
    holderId: 'UAE-100-9934',
    credentialType: 'Food Safety Cert',
    issuer: 'ADAFSA',
    subscribedDate: '11 Jan 2026',
    expiryDate: '11 Jan 2027',
    status: SubStatus.active,
  ),
  SubscriptionRecord(
    id: 'SUB-022',
    holderName: 'Wadha Al Shamsi',
    holderId: 'UAE-100-1123',
    credentialType: 'PMP Certificate',
    issuer: 'PMI',
    subscribedDate: '15 Dec 2024',
    expiryDate: '15 Dec 2025',
    status: SubStatus.expired,
  ),
  SubscriptionRecord(
    id: 'SUB-023',
    holderName: 'Faisal Al Marri',
    holderId: 'UAE-100-5567',
    credentialType: 'Aviation License',
    issuer: 'GCAA',
    subscribedDate: '25 Feb 2026',
    expiryDate: '25 Feb 2027',
    status: SubStatus.active,
  ),
  SubscriptionRecord(
    id: 'SUB-024',
    holderName: 'Latifa Al Zaabi',
    holderId: 'UAE-100-8812',
    credentialType: 'BEd Education',
    issuer: 'HCT',
    subscribedDate: '—',
    expiryDate: '—',
    status: SubStatus.pending,
  ),
  SubscriptionRecord(
    id: 'SUB-025',
    holderName: 'Khaled Al Mulla',
    holderId: 'UAE-100-2234',
    credentialType: 'CFA Level 1',
    issuer: 'CFA Institute',
    subscribedDate: '05 Nov 2024',
    expiryDate: '05 Nov 2025',
    status: SubStatus.expired,
  ),
  SubscriptionRecord(
    id: 'SUB-026',
    holderName: 'Nadia Al Falahi',
    holderId: 'UAE-100-3378',
    credentialType: 'Veterinary License',
    issuer: 'Ministry of Climate',
    subscribedDate: '07 Mar 2026',
    expiryDate: '07 Mar 2027',
    status: SubStatus.active,
  ),
  SubscriptionRecord(
    id: 'SUB-027',
    holderName: 'Waleed Al Suwaidi',
    holderId: 'UAE-100-6612',
    credentialType: 'HR Professional',
    issuer: 'CIPD',
    subscribedDate: '12 Aug 2025',
    expiryDate: '12 Aug 2026',
    status: SubStatus.unsubscribed,
  ),
  SubscriptionRecord(
    id: 'SUB-028',
    holderName: 'Amna Al Nuaimi',
    holderId: 'UAE-100-7745',
    credentialType: 'MSc Nursing',
    issuer: 'Manchester University',
    subscribedDate: '—',
    expiryDate: '—',
    status: SubStatus.pending,
  ),
  SubscriptionRecord(
    id: 'SUB-029',
    holderName: 'Bilal Al Hashemi',
    holderId: 'UAE-100-4456',
    credentialType: 'CCNA Certificate',
    issuer: 'Cisco',
    subscribedDate: '01 Feb 2026',
    expiryDate: '01 Feb 2027',
    status: SubStatus.active,
  ),
  SubscriptionRecord(
    id: 'SUB-030',
    holderName: 'Rawdha Al Khateri',
    holderId: 'UAE-100-9901',
    credentialType: 'Security Guard License',
    issuer: 'MOI',
    subscribedDate: '—',
    expiryDate: '—',
    status: SubStatus.rejected,
  ),
];

// ─── MODEL ───────────────────────────────────────────────────────────────────

class AlertRecord {
  final String id;
  final String holderName;
  final String credentialName;
  final String description; // e.g. "Status changed from Active to Revoked"
  final String dateTime; // e.g. "11 Mar 2026  14:32"
  final AlertSeverity severity;

  const AlertRecord({
    required this.id,
    required this.holderName,
    required this.credentialName,
    required this.description,
    required this.dateTime,
    required this.severity,
  });
}

// ─── MOCK DATA ────────────────────────────────────────────────────────────────

final kMockAlerts = <AlertRecord>[
  AlertRecord(
    id: 'ALT-001',
    holderName: 'Fatima Noor',
    credentialName: 'Medical License',
    description: 'Status changed from Active to Revoked.',
    dateTime: '11 Mar 2026  14:52',
    severity: AlertSeverity.revoked,
  ),
  AlertRecord(
    id: 'ALT-002',
    holderName: 'Laila Hassan',
    credentialName: 'ISO Certificate',
    description: 'Subscription expired — credential monitoring has ended.',
    dateTime: '11 Mar 2026  13:40',
    severity: AlertSeverity.expired,
  ),
  AlertRecord(
    id: 'ALT-003',
    holderName: 'Yousuf Al Zaabi',
    credentialName: 'Teaching License',
    description: 'Status changed from Active to Suspended until 01 Jun 2026.',
    dateTime: '11 Mar 2026  12:10',
    severity: AlertSeverity.suspended,
  ),
  AlertRecord(
    id: 'ALT-004',
    holderName: 'Noura Al Shamsi',
    credentialName: 'Engineering Cert',
    description: 'Credential data mismatch detected — possible tampering.',
    dateTime: '10 Mar 2026  17:03',
    severity: AlertSeverity.tampered,
  ),
  AlertRecord(
    id: 'ALT-005',
    holderName: 'Hessa Al Ketbi',
    credentialName: 'CPA Certificate',
    description: 'Status changed from Active to Revoked.',
    dateTime: '10 Mar 2026  15:21',
    severity: AlertSeverity.revoked,
  ),
  AlertRecord(
    id: 'ALT-006',
    holderName: 'Shamma Al Qubaisi',
    credentialName: 'Fire Safety Cert',
    description: 'Subscription expired — credential monitoring has ended.',
    dateTime: '10 Mar 2026  11:44',
    severity: AlertSeverity.expired,
  ),
  AlertRecord(
    id: 'ALT-007',
    holderName: 'Moza Al Sulaiti',
    credentialName: 'Cyber Security Cert',
    description: 'Credential data mismatch detected — possible tampering.',
    dateTime: '09 Mar 2026  16:55',
    severity: AlertSeverity.tampered,
  ),
  AlertRecord(
    id: 'ALT-008',
    holderName: 'Ibrahim Al Bloushi',
    credentialName: 'Bachelor of Arts',
    description: 'Subscription expired — credential monitoring has ended.',
    dateTime: '09 Mar 2026  10:30',
    severity: AlertSeverity.expired,
  ),
  AlertRecord(
    id: 'ALT-009',
    holderName: 'Waleed Al Suwaidi',
    credentialName: 'HR Professional',
    description: 'Status changed from Active to Revoked.',
    dateTime: '08 Mar 2026  15:12',
    severity: AlertSeverity.revoked,
  ),
  AlertRecord(
    id: 'ALT-010',
    holderName: 'Ahmed Al Mansoori',
    credentialName: 'Bachelor of Science',
    description: 'Credential renewed — new expiry date: 01 Jan 2028.',
    dateTime: '07 Mar 2026  09:00',
    severity: AlertSeverity.renewed,
  ),
  AlertRecord(
    id: 'ALT-011',
    holderName: 'Khalid Al Rashidi',
    credentialName: 'Diploma in Finance',
    description: 'Status changed from Active to Suspended until 15 May 2026.',
    dateTime: '06 Mar 2026  14:22',
    severity: AlertSeverity.suspended,
  ),
  AlertRecord(
    id: 'ALT-012',
    holderName: 'Rashed Al Nuaimi',
    credentialName: 'Bachelor of Laws',
    description: 'Credential reissued by University of Sharjah.',
    dateTime: '05 Mar 2026  11:05',
    severity: AlertSeverity.reissued,
  ),
  AlertRecord(
    id: 'ALT-013',
    holderName: 'Saeed Al Matrooshi',
    credentialName: 'PhD Computer Science',
    description: 'Status changed from Active to Suspended until 20 Apr 2026.',
    dateTime: '04 Mar 2026  16:40',
    severity: AlertSeverity.suspended,
  ),
  AlertRecord(
    id: 'ALT-014',
    holderName: 'Khaled Al Mulla',
    credentialName: 'CFA Level 1',
    description: 'Credential data mismatch detected — possible tampering.',
    dateTime: '03 Mar 2026  13:18',
    severity: AlertSeverity.tampered,
  ),
  AlertRecord(
    id: 'ALT-015',
    holderName: 'Nashwa Al Kaabi',
    credentialName: 'Driving License',
    description: 'Status changed from Active to Revoked.',
    dateTime: '02 Mar 2026  10:55',
    severity: AlertSeverity.revoked,
  ),
];

// ─── POLICY STATUS ────────────────────────────────────────────────────────────

enum PolicyStatus { active, inactive, draft }

extension PolicyStatusX on PolicyStatus {
  String get label {
    switch (this) {
      case PolicyStatus.active:
        return 'Active';
      case PolicyStatus.inactive:
        return 'Inactive';
      case PolicyStatus.draft:
        return 'Draft';
    }
  }

  Color get fg {
    switch (this) {
      case PolicyStatus.active:
        return AppColors.valid;
      case PolicyStatus.inactive:
        return AppColors.textMuted;
      case PolicyStatus.draft:
        return const Color(0xFF60A5FA);
    }
  }
}

// ─── POLICY RECORD ────────────────────────────────────────────────────────────

class PolicyRecord {
  final String id;
  final String policyName;
  final String appliesTo;
  final String createdDate;
  final String createdBy;
  final PolicyStatus status;

  const PolicyRecord({
    required this.id,
    required this.policyName,
    required this.appliesTo,
    required this.createdDate,
    required this.createdBy,
    required this.status,
  });
}

// ─── POLICY MOCK DATA ─────────────────────────────────────────────────────────

final kMockPolicies = <PolicyRecord>[
  PolicyRecord(
    id: 'POL-001',
    policyName: 'Credential Expiry Check',
    appliesTo: 'All Credentials',
    createdDate: '01 Jan 2026',
    createdBy: 'Sara K.',
    status: PolicyStatus.active,
  ),
  PolicyRecord(
    id: 'POL-002',
    policyName: 'Issuer Authorisation Verification',
    appliesTo: 'All Credentials',
    createdDate: '05 Jan 2026',
    createdBy: 'Omar A.',
    status: PolicyStatus.active,
  ),
  PolicyRecord(
    id: 'POL-003',
    policyName: 'Academic Credential Schema Match',
    appliesTo: 'Academic Credentials',
    createdDate: '10 Jan 2026',
    createdBy: 'Mohammed A.',
    status: PolicyStatus.active,
  ),
  PolicyRecord(
    id: 'POL-004',
    policyName: 'Medical Licence Renewal Threshold',
    appliesTo: 'Medical Credentials',
    createdDate: '15 Jan 2026',
    createdBy: 'Sara K.',
    status: PolicyStatus.active,
  ),
  PolicyRecord(
    id: 'POL-005',
    policyName: 'Revocation List Cross-Check',
    appliesTo: 'All Credentials',
    createdDate: '20 Jan 2026',
    createdBy: 'Omar A.',
    status: PolicyStatus.inactive,
  ),
  PolicyRecord(
    id: 'POL-006',
    policyName: 'Professional Licence Scope Validator',
    appliesTo: 'Professional Licences',
    createdDate: '25 Jan 2026',
    createdBy: 'Mohammed A.',
    status: PolicyStatus.active,
  ),
  PolicyRecord(
    id: 'POL-007',
    policyName: 'Holder Identity Binding Check',
    appliesTo: 'All Credentials',
    createdDate: '01 Feb 2026',
    createdBy: 'Sara K.',
    status: PolicyStatus.draft,
  ),
  PolicyRecord(
    id: 'POL-008',
    policyName: 'Government Document Integrity Rule',
    appliesTo: 'Government Documents',
    createdDate: '05 Feb 2026',
    createdBy: 'Omar A.',
    status: PolicyStatus.active,
  ),
  PolicyRecord(
    id: 'POL-009',
    policyName: 'Suspension Status Alert Policy',
    appliesTo: 'All Credentials',
    createdDate: '10 Feb 2026',
    createdBy: 'Mohammed A.',
    status: PolicyStatus.draft,
  ),
  PolicyRecord(
    id: 'POL-010',
    policyName: 'Blockchain Timestamp Validation',
    appliesTo: 'All Credentials',
    createdDate: '14 Feb 2026',
    createdBy: 'Sara K.',
    status: PolicyStatus.active,
  ),
  PolicyRecord(
    id: 'POL-011',
    policyName: 'Schema Version Compatibility Check',
    appliesTo: 'Academic Credentials',
    createdDate: '18 Feb 2026',
    createdBy: 'Omar A.',
    status: PolicyStatus.active,
  ),
  PolicyRecord(
    id: 'POL-012',
    policyName: 'Credential Tamper Detection Rule',
    appliesTo: 'All Credentials',
    createdDate: '22 Feb 2026',
    createdBy: 'Mohammed A.',
    status: PolicyStatus.inactive,
  ),
  PolicyRecord(
    id: 'POL-013',
    policyName: 'MOH Licence Validity Period Rule',
    appliesTo: 'Medical Credentials',
    createdDate: '25 Feb 2026',
    createdBy: 'Sara K.',
    status: PolicyStatus.active,
  ),
  PolicyRecord(
    id: 'POL-014',
    policyName: 'Engineering Certificate Scope Policy',
    appliesTo: 'Professional Licences',
    createdDate: '01 Mar 2026',
    createdBy: 'Omar A.',
    status: PolicyStatus.draft,
  ),
  PolicyRecord(
    id: 'POL-015',
    policyName: 'Minimum Credential Age Requirement',
    appliesTo: 'All Credentials',
    createdDate: '05 Mar 2026',
    createdBy: 'Mohammed A.',
    status: PolicyStatus.active,
  ),
];

// ─── AUDIT LOG ────────────────────────────────────────────────────────────────
//
// Append-only record of every portal action.
// Cannot be edited or deleted — blockchain transactions are recorded on-chain
// separately; this log covers internal portal activity only.

enum AuditAction {
  issued,
  revoked,
  suspended,
  restored,
  verified,
  verificationFailed,
  staffAdded,
  staffRemoved,
  settingsChanged,
  schemaCreated,
  schemaArchived,
  policyCreated,
  policyDeleted,
  batchIssued,
  exported,
  login,
  logout,
}

extension AuditActionX on AuditAction {
  String get label {
    switch (this) {
      case AuditAction.issued:
        return 'Issued';
      case AuditAction.revoked:
        return 'Revoked';
      case AuditAction.suspended:
        return 'Suspended';
      case AuditAction.restored:
        return 'Restored';
      case AuditAction.verified:
        return 'Verified';
      case AuditAction.verificationFailed:
        return 'Verify Failed';
      case AuditAction.staffAdded:
        return 'Staff Added';
      case AuditAction.staffRemoved:
        return 'Staff Removed';
      case AuditAction.settingsChanged:
        return 'Settings Changed';
      case AuditAction.schemaCreated:
        return 'Schema Created';
      case AuditAction.schemaArchived:
        return 'Schema Archived';
      case AuditAction.policyCreated:
        return 'Policy Created';
      case AuditAction.policyDeleted:
        return 'Policy Deleted';
      case AuditAction.batchIssued:
        return 'Batch Issued';
      case AuditAction.exported:
        return 'Exported';
      case AuditAction.login:
        return 'Login';
      case AuditAction.logout:
        return 'Logout';
    }
  }

  Color get colour {
    switch (this) {
      case AuditAction.issued:
      case AuditAction.restored:
      case AuditAction.batchIssued:
        return AppColors.valid;
      case AuditAction.revoked:
      case AuditAction.verificationFailed:
      case AuditAction.staffRemoved:
      case AuditAction.policyDeleted:
        return AppColors.revoked;
      case AuditAction.suspended:
        return AppColors.suspended;
      case AuditAction.verified:
      case AuditAction.login:
        return AppColors.issuingLight;
      case AuditAction.staffAdded:
      case AuditAction.schemaCreated:
      case AuditAction.policyCreated:
        return const Color(0xFF818CF8); // indigo
      case AuditAction.settingsChanged:
      case AuditAction.schemaArchived:
      case AuditAction.exported:
      case AuditAction.logout:
        return AppColors.textMuted;
    }
  }
}

class AuditLogRecord {
  final String id;
  final AuditAction action;
  final String details;
  final String performedBy;
  final String performedByRole;
  final String ipAddress;
  final String timestamp;

  const AuditLogRecord({
    required this.id,
    required this.action,
    required this.details,
    required this.performedBy,
    required this.performedByRole,
    required this.ipAddress,
    required this.timestamp,
  });
}

// ─── AUDIT LOG MOCK DATA ──────────────────────────────────────────────────────
// Names, credential IDs, schema IDs, policy IDs and staff members are all drawn
// from existing IssuingMockData / kMockPolicies — no new entities invented.

final kMockAuditLog = <AuditLogRecord>[
  AuditLogRecord(
    id: 'AUD-001',
    action: AuditAction.login,
    details: 'Admin logged in to the portal.',
    performedBy: 'Admin',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '12 Mar 2026  08:01',
  ),
  AuditLogRecord(
    id: 'AUD-002',
    action: AuditAction.issued,
    details: 'Credential QC-2025-009182 issued to Mohammed Ali.',
    performedBy: 'Registrar Ali',
    performedByRole: 'Issuer Staff',
    ipAddress: '10.0.1.55',
    timestamp: '12 Mar 2026  08:14',
  ),
  AuditLogRecord(
    id: 'AUD-003',
    action: AuditAction.issued,
    details: 'Credential QC-2025-009004 issued to Ahmed Al Rashidi.',
    performedBy: 'Registrar Ali',
    performedByRole: 'Issuer Staff',
    ipAddress: '10.0.1.55',
    timestamp: '12 Mar 2026  08:17',
  ),
  AuditLogRecord(
    id: 'AUD-004',
    action: AuditAction.verified,
    details: 'Credential QC-2025-009182 verified via QR scan — result: Valid.',
    performedBy: 'Omar A.',
    performedByRole: 'Issuer Staff',
    ipAddress: '172.16.0.9',
    timestamp: '12 Mar 2026  09:03',
  ),
  AuditLogRecord(
    id: 'AUD-005',
    action: AuditAction.policyCreated,
    details: 'Policy POL-015 "Minimum Credential Age Requirement" created.',
    performedBy: 'Mohammed A.',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '12 Mar 2026  09:22',
  ),
  AuditLogRecord(
    id: 'AUD-006',
    action: AuditAction.exported,
    details: 'Credential list exported as XLSX (29 records).',
    performedBy: 'Admin',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '12 Mar 2026  09:45',
  ),
  AuditLogRecord(
    id: 'AUD-007',
    action: AuditAction.login,
    details: 'Sara K. logged in to the portal.',
    performedBy: 'Sara K.',
    performedByRole: 'Issuer Staff',
    ipAddress: '192.168.1.18',
    timestamp: '11 Mar 2026  08:05',
  ),
  AuditLogRecord(
    id: 'AUD-008',
    action: AuditAction.issued,
    details: 'Credential QC-2026-000031 issued to Fatima Al Hashimi.',
    performedBy: 'Sara K.',
    performedByRole: 'Issuer Staff',
    ipAddress: '192.168.1.18',
    timestamp: '11 Mar 2026  08:31',
  ),
  AuditLogRecord(
    id: 'AUD-009',
    action: AuditAction.batchIssued,
    details: 'Batch issue completed — 6 credentials issued, 2 rows skipped.',
    performedBy: 'Registrar Ali',
    performedByRole: 'Issuer Staff',
    ipAddress: '10.0.1.55',
    timestamp: '11 Mar 2026  10:00',
  ),
  AuditLogRecord(
    id: 'AUD-010',
    action: AuditAction.verificationFailed,
    details:
        'Credential QC-2023-000374 verification failed — credential is Suspended.',
    performedBy: 'Omar A.',
    performedByRole: 'Issuer Staff',
    ipAddress: '172.16.0.9',
    timestamp: '11 Mar 2026  11:14',
  ),
  AuditLogRecord(
    id: 'AUD-011',
    action: AuditAction.suspended,
    details:
        'Credential QC-2025-006831 suspended — reason: Audit review in progress.',
    performedBy: 'Compliance Officer',
    performedByRole: 'Issuer Staff',
    ipAddress: '10.0.1.61',
    timestamp: '10 Mar 2026  14:05',
  ),
  AuditLogRecord(
    id: 'AUD-012',
    action: AuditAction.settingsChanged,
    details:
        'Signing algorithm changed from ECDSA to Dilithium (CRYSTALS-Dilithium3).',
    performedBy: 'Admin',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '10 Mar 2026  15:30',
  ),
  AuditLogRecord(
    id: 'AUD-013',
    action: AuditAction.schemaCreated,
    details: 'Schema SCH-006 "Medical License" created with 4 fields.',
    performedBy: 'Sara K.',
    performedByRole: 'Issuer Staff',
    ipAddress: '192.168.1.18',
    timestamp: '09 Mar 2026  09:10',
  ),
  AuditLogRecord(
    id: 'AUD-014',
    action: AuditAction.policyCreated,
    details: 'Policy POL-013 "MOH Licence Validity Period Rule" created.',
    performedBy: 'Sara K.',
    performedByRole: 'Issuer Staff',
    ipAddress: '192.168.1.18',
    timestamp: '09 Mar 2026  09:44',
  ),
  AuditLogRecord(
    id: 'AUD-015',
    action: AuditAction.staffAdded,
    details:
        'Staff member Fatima Al Zahra (STF-005) added with role Issuer Staff.',
    performedBy: 'Admin',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '08 Mar 2026  10:20',
  ),
  AuditLogRecord(
    id: 'AUD-016',
    action: AuditAction.revoked,
    details: 'Credential QC-2025-007192 revoked — reason: Disciplinary action.',
    performedBy: 'Admin',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '07 Mar 2026  14:22',
  ),
  AuditLogRecord(
    id: 'AUD-017',
    action: AuditAction.verified,
    details:
        'Credential QC-2025-008841 verified via manual entry — result: Valid.',
    performedBy: 'Omar A.',
    performedByRole: 'Issuer Staff',
    ipAddress: '172.16.0.9',
    timestamp: '07 Mar 2026  11:05',
  ),
  AuditLogRecord(
    id: 'AUD-018',
    action: AuditAction.policyCreated,
    details: 'Policy POL-010 "Blockchain Timestamp Validation" created.',
    performedBy: 'Sara K.',
    performedByRole: 'Issuer Staff',
    ipAddress: '192.168.1.18',
    timestamp: '06 Mar 2026  16:00',
  ),
  AuditLogRecord(
    id: 'AUD-019',
    action: AuditAction.exported,
    details: 'Audit log exported as PDF.',
    performedBy: 'Admin',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '06 Mar 2026  16:45',
  ),
  AuditLogRecord(
    id: 'AUD-020',
    action: AuditAction.logout,
    details: 'Registrar Ali logged out of the portal.',
    performedBy: 'Registrar Ali',
    performedByRole: 'Issuer Staff',
    ipAddress: '10.0.1.55',
    timestamp: '05 Mar 2026  18:00',
  ),
  AuditLogRecord(
    id: 'AUD-021',
    action: AuditAction.schemaArchived,
    details: 'Schema SCH-008 "Employee ID" archived.',
    performedBy: 'Admin',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '04 Mar 2026  10:11',
  ),
  AuditLogRecord(
    id: 'AUD-022',
    action: AuditAction.restored,
    details:
        'Credential QC-2024-005917 restored — suspension lifted by Compliance Officer.',
    performedBy: 'Compliance Officer',
    performedByRole: 'Issuer Staff',
    ipAddress: '10.0.1.61',
    timestamp: '03 Mar 2026  09:30',
  ),
  AuditLogRecord(
    id: 'AUD-023',
    action: AuditAction.issued,
    details: 'Credential QC-2026-000018 issued to Nour Ibrahim.',
    performedBy: 'Mohammed A.',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '02 Mar 2026  11:55',
  ),
  AuditLogRecord(
    id: 'AUD-024',
    action: AuditAction.staffAdded,
    details:
        'Staff member Omar Nasser (STF-006) invited with role Issuer Staff.',
    performedBy: 'Admin',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '01 Mar 2026  09:00',
  ),
  AuditLogRecord(
    id: 'AUD-025',
    action: AuditAction.policyCreated,
    details: 'Policy POL-008 "Government Document Integrity Rule" created.',
    performedBy: 'Omar A.',
    performedByRole: 'Issuer Staff',
    ipAddress: '172.16.0.9',
    timestamp: '28 Feb 2026  14:05',
  ),
  AuditLogRecord(
    id: 'AUD-026',
    action: AuditAction.batchIssued,
    details: 'Batch issue completed — 12 credentials issued, 0 rows skipped.',
    performedBy: 'Registrar Ali',
    performedByRole: 'Issuer Staff',
    ipAddress: '10.0.1.55',
    timestamp: '27 Feb 2026  08:45',
  ),
  AuditLogRecord(
    id: 'AUD-027',
    action: AuditAction.settingsChanged,
    details:
        'Issuer profile display name updated to "University of Sharjah — Registrar Office".',
    performedBy: 'Admin',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '26 Feb 2026  11:22',
  ),
  AuditLogRecord(
    id: 'AUD-028',
    action: AuditAction.verificationFailed,
    details:
        'Credential QC-2022-000098 verification failed — credential is Revoked.',
    performedBy: 'Fatima Al Zahra',
    performedByRole: 'Issuer Staff',
    ipAddress: '192.168.1.20',
    timestamp: '25 Feb 2026  13:44',
  ),
  AuditLogRecord(
    id: 'AUD-029',
    action: AuditAction.schemaCreated,
    details: 'Schema SCH-007 "Research Fellowship" created with 4 fields.',
    performedBy: 'Mohammed A.',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '24 Feb 2026  10:05',
  ),
  AuditLogRecord(
    id: 'AUD-030',
    action: AuditAction.revoked,
    details:
        'Credential QC-2022-000098 revoked — reason: Fellowship terminated early.',
    performedBy: 'Mohammed A.',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '23 Feb 2026  09:15',
  ),
  AuditLogRecord(
    id: 'AUD-031',
    action: AuditAction.issued,
    details: 'Credential QC-2025-008312 issued to Mariam Yusuf.',
    performedBy: 'Sara K.',
    performedByRole: 'Issuer Staff',
    ipAddress: '192.168.1.18',
    timestamp: '22 Feb 2026  14:30',
  ),
  AuditLogRecord(
    id: 'AUD-032',
    action: AuditAction.policyDeleted,
    details: 'Policy POL-005 "Revocation List Cross-Check" deleted by Admin.',
    performedBy: 'Admin',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '21 Feb 2026  16:05',
  ),
  AuditLogRecord(
    id: 'AUD-033',
    action: AuditAction.login,
    details: 'Compliance Officer logged in to the portal.',
    performedBy: 'Compliance Officer',
    performedByRole: 'Issuer Staff',
    ipAddress: '10.0.1.61',
    timestamp: '20 Feb 2026  08:00',
  ),
  AuditLogRecord(
    id: 'AUD-034',
    action: AuditAction.suspended,
    details:
        'Credential QC-2023-000374 suspended — reason: License renewal under review.',
    performedBy: 'Compliance Officer',
    performedByRole: 'Issuer Staff',
    ipAddress: '10.0.1.61',
    timestamp: '19 Feb 2026  10:50',
  ),
  AuditLogRecord(
    id: 'AUD-035',
    action: AuditAction.verified,
    details:
        'Credential QC-2025-009004 verified via file upload — result: Valid.',
    performedBy: 'Fatima Al Zahra',
    performedByRole: 'Issuer Staff',
    ipAddress: '192.168.1.20',
    timestamp: '18 Feb 2026  11:30',
  ),
  AuditLogRecord(
    id: 'AUD-036',
    action: AuditAction.schemaCreated,
    details: 'Schema SCH-001 "BSc Degree" created with 5 fields.',
    performedBy: 'Admin',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '17 Feb 2026  09:00',
  ),
  AuditLogRecord(
    id: 'AUD-037',
    action: AuditAction.exported,
    details: 'Verification history exported as JSON (30 records).',
    performedBy: 'Omar A.',
    performedByRole: 'Issuer Staff',
    ipAddress: '172.16.0.9',
    timestamp: '16 Feb 2026  15:10',
  ),
  AuditLogRecord(
    id: 'AUD-038',
    action: AuditAction.staffRemoved,
    details: 'Staff member STF-006 Omar Nasser removed from the portal.',
    performedBy: 'Admin',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '15 Feb 2026  17:00',
  ),
  AuditLogRecord(
    id: 'AUD-039',
    action: AuditAction.batchIssued,
    details: 'Batch issue completed — 8 credentials issued, 0 rows skipped.',
    performedBy: 'Registrar Ali',
    performedByRole: 'Issuer Staff',
    ipAddress: '10.0.1.55',
    timestamp: '14 Feb 2026  09:30',
  ),
  AuditLogRecord(
    id: 'AUD-040',
    action: AuditAction.policyCreated,
    details: 'Policy POL-001 "Credential Expiry Check" created.',
    performedBy: 'Sara K.',
    performedByRole: 'Issuer Staff',
    ipAddress: '192.168.1.18',
    timestamp: '13 Feb 2026  10:00',
  ),
  AuditLogRecord(
    id: 'AUD-041',
    action: AuditAction.settingsChanged,
    details: 'Two-factor authentication enabled for all staff accounts.',
    performedBy: 'Admin',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '12 Feb 2026  14:20',
  ),
  AuditLogRecord(
    id: 'AUD-042',
    action: AuditAction.restored,
    details: 'Credential QC-2024-004211 restored — suspension lifted.',
    performedBy: 'Compliance Officer',
    performedByRole: 'Issuer Staff',
    ipAddress: '10.0.1.61',
    timestamp: '11 Feb 2026  11:05',
  ),
  AuditLogRecord(
    id: 'AUD-043',
    action: AuditAction.login,
    details: 'Mohammed A. logged in to the portal.',
    performedBy: 'Mohammed A.',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '10 Feb 2026  08:02',
  ),
  AuditLogRecord(
    id: 'AUD-044',
    action: AuditAction.issued,
    details: 'Credential QC-2024-005199 issued to Tariq Al Nasser.',
    performedBy: 'Registrar Ali',
    performedByRole: 'Issuer Staff',
    ipAddress: '10.0.1.55',
    timestamp: '09 Feb 2026  08:55',
  ),
  AuditLogRecord(
    id: 'AUD-045',
    action: AuditAction.schemaCreated,
    details:
        'Schema SCH-005 "Higher Training Certificate" created with 4 fields.',
    performedBy: 'Mohammed A.',
    performedByRole: 'Issuer Admin',
    ipAddress: '10.0.1.42',
    timestamp: '08 Feb 2026  09:40',
  ),
];

// ─── VERIFIER ROLE ────────────────────────────────────────────────────────────

enum VerifierRole { admin, verifier, policyManager }

extension VerifierRoleX on VerifierRole {
  String get label {
    switch (this) {
      case VerifierRole.admin:
        return 'Verifier Admin';
      case VerifierRole.verifier:
        return 'Verifier Staff';
      case VerifierRole.policyManager:
        return 'Policy Manager';
    }
  }

  String get description {
    switch (this) {
      case VerifierRole.admin:
        return 'Full verification access + manage staff + settings';
      case VerifierRole.verifier:
        return 'Run verifications, cannot manage staff or policies';
      case VerifierRole.policyManager:
        return 'Manage policies only, cannot run verifications';
    }
  }
}

// ─── VERIFIER STAFF MEMBER ────────────────────────────────────────────────────

class VerifierStaffMember {
  final String id;
  final String name;
  final String email;
  final VerifierRole role;
  final String addedDate;
  final StaffStatus status; // reuses StaffStatus from issuing_models.dart

  const VerifierStaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.addedDate,
    required this.status,
  });
}

// ─── VERIFIER STAFF MOCK DATA ─────────────────────────────────────────────────

final kMockVerifierStaff = <VerifierStaffMember>[
  VerifierStaffMember(
    id: 'VST-001',
    name: 'Omar Al Nasser',
    email: 'o.nasser@verify.ae',
    role: VerifierRole.admin,
    addedDate: '01 Jan 2026',
    status: StaffStatus.active,
  ),
  VerifierStaffMember(
    id: 'VST-002',
    name: 'Compliance Officer',
    email: 'compliance@verify.ae',
    role: VerifierRole.verifier,
    addedDate: '15 Jan 2026',
    status: StaffStatus.active,
  ),
  VerifierStaffMember(
    id: 'VST-003',
    name: 'Fatima Al Mansoori',
    email: 'f.mansoori@verify.ae',
    role: VerifierRole.verifier,
    addedDate: '01 Feb 2026',
    status: StaffStatus.active,
  ),
  VerifierStaffMember(
    id: 'VST-004',
    name: 'Policy Coordinator',
    email: 'policy@verify.ae',
    role: VerifierRole.policyManager,
    addedDate: '10 Feb 2026',
    status: StaffStatus.invited,
  ),
  VerifierStaffMember(
    id: 'VST-005',
    name: 'Khalid Al Suwaidi',
    email: 'k.suwaidi@verify.ae',
    role: VerifierRole.verifier,
    addedDate: '20 Feb 2026',
    status: StaffStatus.active,
  ),
  VerifierStaffMember(
    id: 'VST-006',
    name: 'Hessa Al Zaabi',
    email: 'h.zaabi@verify.ae',
    role: VerifierRole.verifier,
    addedDate: '01 Mar 2026',
    status: StaffStatus.invited,
  ),
];
