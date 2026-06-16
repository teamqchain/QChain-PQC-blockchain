class SubscriptionModel {
  final String id;
  final String credentialID;
  final String credentialType;
  final String verifierName;
  final String status;
  final DateTime createdAt;

  SubscriptionModel({
    required this.id,
    required this.credentialID,
    required this.credentialType,
    required this.verifierName,
    required this.status,
    required this.createdAt,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['subscriptionID'] ?? '',
      credentialID: json['credentialID'] ?? '',
      credentialType: json['credentialType'] ?? 'Unknown Credential',
      verifierName: json['verifierName'] ?? 'System Verifier',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);

    // Safeguard against negative differences (future times)
    if (diff.isNegative)
      return 'Negative Time'; // Or handle it however you prefer

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }
}
