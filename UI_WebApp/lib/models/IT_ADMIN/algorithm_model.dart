enum SigningAlgorithm { dilithium, ecdsa }

extension SigningAlgorithmX on SigningAlgorithm {
  String get label {
    switch (this) {
      case SigningAlgorithm.dilithium:
        return 'Dilithium (CRYSTALS-Dilithium3)';
      case SigningAlgorithm.ecdsa:
        return 'ECDSA (Classical)';
    }
  }

  bool get isQuantumSafe => this == SigningAlgorithm.dilithium;
}
