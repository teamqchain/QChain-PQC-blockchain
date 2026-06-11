// ─── VARIANT ENUM ────────────────────────────────────────────────────────────

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

  // String get description {
  //   switch (this) {
  //     case DashboardVariant.issuerOnly:
  //       return 'Issuer permissions only';
  //     case DashboardVariant.verifierOnly:
  //       return 'Verifier permissions only';
  //   }
  // }

  bool get canIssue => this == DashboardVariant.issuerOnly;
  bool get canVerify => this == DashboardVariant.verifierOnly;
  bool get canManage => this == DashboardVariant.ITadmin;
}

// ─── MOCK DATA MODELS ─────────────────────────────────────────────────────────

// class ActivityItem {
//   final String text;
//   final String time;
//   final String type; // issued | batch | revoked | reissued
//   const ActivityItem({
//     required this.text,
//     required this.time,
//     required this.type,
//   });
// }

// class ExpiryItem {
//   final String name;
//   final String credential;
//   final int daysLeft;
//   const ExpiryItem({
//     required this.name,
//     required this.credential,
//     required this.daysLeft,
//   });
// }

// class VerificationItem {
//   final String credential;
//   final String holderName;
//   final String status; // VALID | REVOKED | SUSPENDED | EXPIRED
//   final String time;
//   const VerificationItem({
//     required this.credential,
//     required this.holderName,
//     required this.status,
//     required this.time,
//   });
// }

// class AlertItem {
//   final String name;
//   final String credential;
//   final String event;
//   final String time;
//   const AlertItem({
//     required this.name,
//     required this.credential,
//     required this.event,
//     required this.time,
//   });
// }

// class BarDataPoint {
//   final String label;
//   final double value;
//   const BarDataPoint({required this.label, required this.value});
// }

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

// ─── MOCK DATA ─────────────────────────────────────────────────────────────────

// abstract class MockData {
//   static const recentIssued = [
//     ActivityItem(
//       text: 'BSc Degree issued to Mohammed Ali',
//       time: '10 mins ago',
//       type: 'issued',
//     ),
//     ActivityItem(
//       text: 'Batch of 50 training certs issued',
//       time: 'Today 09:00',
//       type: 'batch',
//     ),
//     ActivityItem(
//       text: 'Medical license REVOKED — Dr. Hamad',
//       time: '1 hour ago',
//       type: 'revoked',
//     ),
//     ActivityItem(
//       text: 'BSc Degree re-issued to Sara (correction)',
//       time: 'Yesterday',
//       type: 'reissued',
//     ),
//     ActivityItem(
//       text: 'Employee ID issued to Khalid',
//       time: 'Yesterday',
//       type: 'issued',
//     ),
//   ];

//   static const expiryWarnings = [
//     ExpiryItem(name: 'Mohammed Ali', credential: 'BSc Degree', daysLeft: 8),
//     ExpiryItem(name: 'Dr. Sara', credential: 'Medical License', daysLeft: 22),
//     ExpiryItem(
//       name: 'Engineer Hassan',
//       credential: 'Professional Cert',
//       daysLeft: 28,
//     ),
//   ];

//   static const recentVerifications = [
//     VerificationItem(
//       credential: 'BSc Degree',
//       holderName: 'Fatima Hassan',
//       status: 'VALID',
//       time: '25 mins ago',
//     ),
//     VerificationItem(
//       credential: 'Medical License',
//       holderName: 'Dr. Rashid',
//       status: 'REVOKED',
//       time: '2 hours ago',
//     ),
//     VerificationItem(
//       credential: 'Passport',
//       holderName: 'Ahmed Noor',
//       status: 'VALID',
//       time: 'Yesterday',
//     ),
//     VerificationItem(
//       credential: 'Training Cert',
//       holderName: 'Layla Khalid',
//       status: 'VALID',
//       time: 'Yesterday',
//     ),
//     VerificationItem(
//       credential: 'Employee ID',
//       holderName: 'Omar Saeed',
//       status: 'EXPIRED',
//       time: '2 days ago',
//     ),
//   ];

//   static const statusAlerts = [
//     AlertItem(
//       name: 'Dr. Sara Al Mansoori',
//       credential: 'License',
//       event: 'EXPIRED',
//       time: 'Today',
//     ),
//     AlertItem(
//       name: 'Engineer Khalid',
//       credential: 'Certificate',
//       event: 'REVOKED',
//       time: 'Yesterday',
//     ),
//   ];

//   static const weeklyIssuedData = [
//     BarDataPoint(label: 'Wk 1', value: 34),
//     BarDataPoint(label: 'Wk 2', value: 58),
//     BarDataPoint(label: 'Wk 3', value: 41),
//     BarDataPoint(label: 'Wk 4', value: 72),
//   ];

//   static const dailyVerifiedData = [
//     BarDataPoint(label: 'Mon', value: 12),
//     BarDataPoint(label: 'Tue', value: 27),
//     BarDataPoint(label: 'Wed', value: 19),
//     BarDataPoint(label: 'Thu', value: 43),
//     BarDataPoint(label: 'Fri', value: 38),
//     BarDataPoint(label: 'Sat', value: 9),
//     BarDataPoint(label: 'Sun', value: 5),
//   ];
// }

