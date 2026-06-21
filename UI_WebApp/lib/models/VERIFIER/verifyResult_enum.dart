import 'package:flutter/material.dart';
import 'package:qportal_webapp/theme/appColours.dart';

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
