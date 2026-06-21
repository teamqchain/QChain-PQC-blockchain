import 'package:flutter/material.dart';
import 'package:qportal_webapp/models/IT_ADMIN/staff/issuerStaff_enum.dart';
import 'package:qportal_webapp/models/IT_ADMIN/staff/verifierStaff_enum.dart';
import 'package:qportal_webapp/theme/appColours.dart';

enum StaffStatus {
  active('Active'),
  invited('Invited');

  final String label;
  const StaffStatus(this.label);

  static StaffStatus fromString(String s) {
    return StaffStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => StaffStatus.invited,
    );
  }
}

enum PortalType {
  issuer('Issuer', AppColors.issuingAccent, AppColors.issuingLight),
  verifier('Verifier', AppColors.verifyingAccent, AppColors.verifyingLight);

  final String label;
  final Color accent;
  final Color light;

  const PortalType(this.label, this.accent, this.light);
}

class LiveStaffRecord {
  final String id;
  final String name;
  final String email;
  final PortalType portal;
  final String role;
  final String addedDate;
  final String status;

  LiveStaffRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.portal,
    required this.role,
    required this.addedDate,
    required this.status,
  });

  factory LiveStaffRecord.fromJson(Map<String, dynamic> e) {
    return LiveStaffRecord(
      id: e['id'] as String? ?? '',
      name: e['name'] as String? ?? '',
      email: e['email'] as String? ?? '',
      portal: (e['portal'] as String? ?? '') == 'verifier'
          ? PortalType.verifier
          : PortalType.issuer,
      role: e['role'] as String? ?? '',
      addedDate: e['addedDate'] as String? ?? '',
      status: e['status'] as String? ?? 'invited',
    );
  }
}

class StaffEntry {
  final String id;
  String name;
  String email;
  String addedDate;
  StaffStatus status;
  PortalType portal;
  IssuerRole? issuerRole;
  VerifierRole? verifierRole;

  String get roleLabel {
    if (issuerRole != null) return issuerRole!.label;
    if (verifierRole != null) return verifierRole!.label;
    return '—';
  }

  Color get roleColor {
    if (issuerRole != null) {
      switch (issuerRole!) {
        case IssuerRole.admin:
          return AppColors.issuingAccent;
        case IssuerRole.staff:
          return const Color(0xff00ccff);
        case IssuerRole.schemaManager:
          return const Color(0xffafdbf5);
      }
    }
    if (verifierRole != null) {
      switch (verifierRole!) {
        case VerifierRole.admin:
          return AppColors.verifyingAccent;
        case VerifierRole.verifier:
          return const Color(0xff77dd77);
        case VerifierRole.policyManager:
          return const Color(0xff9c9f84);
      }
    }
    return AppColors.textDim;
  }

  StaffEntry.fromLive(LiveStaffRecord r)
    : id = r.id,
      name = r.name,
      email = r.email,
      addedDate = r.addedDate,
      status = StaffStatus.fromString(r.status),
      portal = r.portal,
      issuerRole = r.portal == PortalType.issuer
          ? IssuerRole.fromString(r.role)
          : null,
      verifierRole = r.portal == PortalType.verifier
          ? VerifierRole.fromString(r.role)
          : null;
}
