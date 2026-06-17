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
  final String credID;
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
    required this.credID,
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

class SubscriptionRecord {
  final String id;
  final String credentialID;
  final String holderName;
  final String holderId;
  final String credentialType;
  final String issuer;
  final String subscribedDate; // '—' when still pending / rejected
  final String expiryDate; // '—' when no expiry set yet
  final SubStatus status;

  const SubscriptionRecord({
    required this.id,
    required this.credentialID,
    required this.holderName,
    required this.holderId,
    required this.credentialType,
    required this.issuer,
    required this.subscribedDate,
    required this.expiryDate,
    required this.status,
  });
}


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


