class OrgDirectoryRecord {
  final String name;
  final String email;

  OrgDirectoryRecord({required this.name, required this.email});

  factory OrgDirectoryRecord.fromJson(Map<String, dynamic> json) {
    return OrgDirectoryRecord(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }
}
