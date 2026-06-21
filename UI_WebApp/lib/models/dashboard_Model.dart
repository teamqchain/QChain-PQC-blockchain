

enum DashboardVariant { issuerOnly, verifierOnly, ITadmin }

extension DashboardVariantX on DashboardVariant {
  String get label {
    switch (this) {
      case DashboardVariant.issuerOnly:
        return 'Variant A — Issuer';
      case DashboardVariant.verifierOnly:
        return 'Variant B — Verifier';
      case DashboardVariant.ITadmin:
        return 'Variant C — IT Admin';
    }
  }


  bool get canIssue => this == DashboardVariant.issuerOnly;
  bool get canVerify => this == DashboardVariant.verifierOnly;
  bool get canManage => this == DashboardVariant.ITadmin;
}

class ActivityItem {
  final String text;
  final String time;
  final String type;
  const ActivityItem({
    required this.text,
    required this.time,
    required this.type,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
    text: json['text']?.toString() ?? '',
    time: json['time']?.toString() ?? '',
    type: json['type']?.toString() ?? '',
  );
}

class ExpiryItem {
  final String name;
  final String credential;
  final int daysLeft;
  const ExpiryItem({
    required this.name,
    required this.credential,
    required this.daysLeft,
  });

  factory ExpiryItem.fromJson(Map<String, dynamic> json) => ExpiryItem(
    name: json['name']?.toString() ?? '',
    credential: json['credential']?.toString() ?? '',
    daysLeft: (json['daysLeft'] as num?)?.toInt() ?? 0,
  );
}

class VerificationItem {
  final String credential;
  final String holderName;
  final String status;
  final String time;
  const VerificationItem({
    required this.credential,
    required this.holderName,
    required this.status,
    required this.time,
  });

  factory VerificationItem.fromJson(Map<String, dynamic> json) =>
      VerificationItem(
        credential: json['credential']?.toString() ?? '',
        holderName: json['holderName']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        time: json['time']?.toString() ?? '',
      );
}

class AlertItem {
  final String name;
  final String credential;
  final String event;
  final String time;
  const AlertItem({
    required this.name,
    required this.credential,
    required this.event,
    required this.time,
  });

  factory AlertItem.fromJson(Map<String, dynamic> json) => AlertItem(
    name: json['name']?.toString() ?? '',
    credential: json['credential']?.toString() ?? '',
    event: json['event']?.toString() ?? '',
    time: json['time']?.toString() ?? '',
  );
}

class BarDataPoint {
  final String label;
  final double value;
  const BarDataPoint({required this.label, required this.value});

  factory BarDataPoint.fromJson(Map<String, dynamic> json) => BarDataPoint(
    label: json['label']?.toString() ?? '',
    value: (json['value'] as num?)?.toDouble() ?? 0.0,
  );
}

class AdminAuditItem {
  final String details;
  final String performedBy;
  final String role;
  final String timestamp;
  final String action;

  const AdminAuditItem({
    required this.details,
    required this.performedBy,
    required this.role,
    required this.timestamp,
    required this.action,
  });

  factory AdminAuditItem.fromJson(Map<String, dynamic> json) => AdminAuditItem(
    details: json['details']?.toString() ?? '',
    performedBy: json['performedBy']?.toString() ?? '',
    role: json['role']?.toString() ?? '',
    timestamp: json['timestamp']?.toString() ?? '',
    action: json['action']?.toString() ?? '',
  );
}

class AdminRoleSplit {
  final String label;
  final int count;

  const AdminRoleSplit({required this.label, required this.count});

  factory AdminRoleSplit.fromJson(Map<String, dynamic> json) => AdminRoleSplit(
    label: json['label']?.toString() ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
  );
}

