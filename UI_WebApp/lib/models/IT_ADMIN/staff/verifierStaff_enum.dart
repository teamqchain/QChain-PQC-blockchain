enum VerifierRole {
  admin('Verifier Admin', 'Full verification access + manage staff + settings'),
  verifier(
    'Verifier Staff',
    'Run verifications, cannot manage staff or policies',
  ),
  policyManager(
    'Policy Manager',
    'Manage policies only, cannot run verifications',
  );

  final String label;
  final String description;

  const VerifierRole(this.label, this.description);

  static VerifierRole fromString(String role) {
    return VerifierRole.values.firstWhere(
      (e) => e.name == role,
      orElse: () => VerifierRole.verifier,
    );
  }
}
