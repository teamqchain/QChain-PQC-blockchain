import 'package:qportal_webapp/models/ISSUER/credentials_model.dart';

CredentialStatus parseStatus(String s) {
    switch (s.toLowerCase()) {
      case 'revoked':
        return CredentialStatus.revoked;
      case 'suspended':
        return CredentialStatus.suspended;
      case 'expired':
        return CredentialStatus.expired;
      default:
        return CredentialStatus.valid;
    }
  }