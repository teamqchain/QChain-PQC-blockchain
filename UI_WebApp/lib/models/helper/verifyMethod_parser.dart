import 'package:qportal_webapp/models/VERIFIER/verificationHistory_model.dart';

VerifyMethod parseVerifyMethod(String s) {
    switch (s) {
      case 'qrScan':
        return VerifyMethod.qrScan;
      case 'fileUpload':
        return VerifyMethod.fileUpload;
      case 'batch':
        return VerifyMethod.batch;
      default:
        return VerifyMethod.manual;
    }
  }