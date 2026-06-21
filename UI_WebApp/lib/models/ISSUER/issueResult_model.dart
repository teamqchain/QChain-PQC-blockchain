class IssueResult {
  final bool success;
  final String credentialID;
  final String? error;

  const IssueResult({
    required this.success,
    required this.credentialID,
    this.error,
  });
}

