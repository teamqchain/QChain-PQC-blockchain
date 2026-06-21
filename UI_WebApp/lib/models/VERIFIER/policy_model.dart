import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';

class PolicyCheck {
  final String label;
  final bool passed;
  final String? note;

  const PolicyCheck({required this.label, required this.passed, this.note});
}

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
