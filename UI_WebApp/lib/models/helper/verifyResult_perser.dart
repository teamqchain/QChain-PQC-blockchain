// Verification Detail Model
import 'package:qportal_webapp/models/VERIFIER/verifyResult_enum.dart';

VerifyResult parseVerifyResult(String s) {
    switch (s) {
      case 'revoked':
        return VerifyResult.revoked;
      case 'suspended':
        return VerifyResult.suspended;
      case 'expired':
        return VerifyResult.expired;
      case 'tampered':
        return VerifyResult.tampered;
      case 'notFound':
        return VerifyResult.notFound;
      default:
        return VerifyResult.valid;
    }
  }