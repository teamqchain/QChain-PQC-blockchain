enum IssuerRole {
  admin('Issuer Admin', 'Full issuing access + manage staff + settings'),
  staff('Issuer Staff', 'Issue and revoke, cannot manage staff or schemas'),
  schemaManager('Schema Manager', 'Manage schemas only, cannot issue');

  final String label;
  final String description;

  const IssuerRole(this.label, this.description);

  static IssuerRole fromString(String role) {
    return IssuerRole.values.firstWhere(
      (e) => e.name == role,
      orElse: () => IssuerRole.staff,
    );
  }
}
