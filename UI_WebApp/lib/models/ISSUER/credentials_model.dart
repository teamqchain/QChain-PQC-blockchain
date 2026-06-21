import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/IT_ADMIN/audit_model.dart';
import 'package:qportal_webapp/models/helper/statusParser.dart';
import 'package:qportal_webapp/theme/appColours.dart';
import 'package:qportal_webapp/utils/dateFormatter.dart';

enum CredentialStatus { valid, revoked, suspended, expired }

extension CredentialStatusX on CredentialStatus {
  String get label {
    switch (this) {
      case CredentialStatus.valid:
        return 'VALID';
      case CredentialStatus.revoked:
        return 'REVOKED';
      case CredentialStatus.suspended:
        return 'SUSPENDED';
      case CredentialStatus.expired:
        return 'EXPIRED';
    }
  }

  Color get bg {
    switch (this) {
      case CredentialStatus.valid:
        return AppColors.valid.withOpacity(0.13);
      case CredentialStatus.revoked:
        return AppColors.revoked.withOpacity(0.13);
      case CredentialStatus.suspended:
        return AppColors.suspended.withOpacity(0.13);
      case CredentialStatus.expired:
        return AppColors.expired.withOpacity(0.13);
    }
  }

  Color get fg {
    switch (this) {
      case CredentialStatus.valid:
        return AppColors.valid;
      case CredentialStatus.revoked:
        return AppColors.revoked;
      case CredentialStatus.suspended:
        return AppColors.suspended;
      case CredentialStatus.expired:
        return AppColors.expired;
    }
  }
}

class CredentialRecord {
  final String holderEmiratesID;
  final String id;
  final String holderName;
  final String holderEmail;
  final String holderId;
  final String credentialType;
  final String issuedBy;
  final String issueDate;
  final String? expiryDate;
  final CredentialStatus status;
  final String? revokedBy;
  final String? revokedDate;
  final String? revokedReason;
  final String? suspendedReason;
  final String? suspendedUntil;
  final List<AuditEntry> auditTrail;
  final Map<String, String> attributes;
  final String signingAlgorithm;
  final String signatureHash;
  final String blockchainTxId;
  final String ipfsReference;

  const CredentialRecord({
    required this.holderEmiratesID,
    required this.id,
    required this.holderName,
    required this.holderEmail,
    required this.holderId,
    required this.credentialType,
    required this.issuedBy,
    required this.issueDate,
    this.expiryDate,
    required this.status,
    this.revokedBy,
    this.revokedDate,
    this.revokedReason,
    this.suspendedReason,
    this.suspendedUntil,
    required this.auditTrail,
    required this.attributes,
    this.signingAlgorithm = 'Dilithium (CRYSTALS-Dilithium3)',
    this.signatureHash = 'a3f9c2e1b8d74f6a...9c2b1',
    this.blockchainTxId = 'TXN-HLF-00291847',
    this.ipfsReference = 'ipfs://QmXf9a2...k8dP',
  });

  factory CredentialRecord.fromJson(Map<String, dynamic> e) {
    final rawExpiry = e['expiryDate'] as String?;

    return CredentialRecord(
      id: e['credentialID'] as String? ?? '',
      holderName: e['holderName'] as String? ?? '',
      holderEmail: e['holderEmail'] as String? ?? '',
      holderId: e['holderID'] as String? ?? '',
      holderEmiratesID: e['holderEID'] as String? ?? '',
      credentialType: e['credentialType'] as String? ?? '',
      issuedBy: e['issuedBy'] as String? ?? '',
      issueDate: e['issuedAt'] as String? ?? '',
      // expiryDate: e['expiryDate'] as String?,
      expiryDate: (rawExpiry != null && rawExpiry.trim().isNotEmpty)
          ? rawExpiry
          : null,
      status: parseStatus(e['status'] as String? ?? ''),
      auditTrail: const [],
      attributes: const {},
    );
  }

  factory CredentialRecord.fromJsonWithAudit(Map<String, dynamic> e) {
    final rawTrail = e['auditTrail'] as List? ?? [];
    final auditTrail = rawTrail.map((entry) {
      final m = entry as Map<String, dynamic>;
      return AuditEntry(
        date: m['date'] as String? ?? '',
        action: m['action'] as String? ?? '',
        performedBy: m['performedBy'] as String? ?? '',
        note: m['note'] as String?,
      );
    }).toList();

    final issueAt = e['issuedAt'] as String? ?? '';

    return CredentialRecord(
      id: e['credentialID'] as String? ?? '',
      holderName: e['holderName'] as String? ?? '',
      holderEmail: e['holderEmail'] as String? ?? '',
      holderId: e['holderID'] as String? ?? '',
      holderEmiratesID: e['holderEID'] as String? ?? '',
      credentialType: e['credentialType'] as String? ?? '',
      issuedBy: e['issuedBy'] as String? ?? '',
      issueDate: DateFormatter.formatIsoDateAndTime(issueAt),
      expiryDate: e['expiryDate'] as String?,
      status: parseStatus(e['status'] as String? ?? ''),
      auditTrail: auditTrail,
      attributes: const {},
    );
  }

  /// Derives the credential category from [credentialType].
  String get category {
    final t = credentialType.toLowerCase();
    if (t.contains('Bachelors') ||
        t.contains('Masters') ||
        t.contains('phd') ||
        t.contains('diploma')) {
      return 'Academic';
    }
    if (t.contains('medical') ||
        t.contains('nursing') ||
        t.contains('pharmaceutical')) {
      return 'Medical';
    }
    if (t.contains('training') || t.contains('certificate')) {
      return 'Professional';
    }
    if (t.contains('fellowship') || t.contains('research')) return 'Research';
    if (t.contains('employee')) return 'Corporate';
    return 'General';
  }

  /// Derives the issuing organisation from the credential type.
  String get issuerOrg {
    final t = credentialType.toLowerCase();
    if (t.contains('medical') ||
        t.contains('nursing') ||
        t.contains('pharmaceutical')) {
      return 'Ministry of Health';
    }
    if (t.contains('employee')) return 'Human Resources Dept.';
    if (t.contains('fellowship') || t.contains('research')) {
      return 'Research & Innovation Office';
    }
    return 'University of Sharjah';
  }

  
}
