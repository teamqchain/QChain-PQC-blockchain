enum HolderType {
  bachelorStudent,
  masterStudent,
  phdStudent,
  employee,
  medical,
}

extension HolderTypeX on HolderType {
  String get label {
    switch (this) {
      case HolderType.bachelorStudent:
        return 'Bachelor Student';
      case HolderType.masterStudent:
        return 'Master Student';
      case HolderType.phdStudent:
        return 'PhD Student';
      case HolderType.employee:
        return 'Employee';
      case HolderType.medical:
        return 'Medical Professional';
    }
  }
}

class HolderRecord {
  final String id;
  final String fullName;
  final String email;
  final HolderType type;
  final String college;
  final String? walletAddress;
  final String emiratesID;

  const HolderRecord({
    required this.id,
    required this.fullName,
    required this.email,
    required this.type,
    required this.college,
    this.walletAddress,
    required this.emiratesID,
  });

  factory HolderRecord.fromJson(Map<String, dynamic> e) {
    return HolderRecord(
      id: e['holderID'] as String? ?? '',
      fullName: e['fullName'] as String? ?? '',
      email: e['email'] as String? ?? '',
      emiratesID: e['emiratesID'] as String? ?? '',
      type: _parseHolderType(e['type'] as String? ?? ''),
      college: e['college'] as String? ?? '',
    );
  }

  // Holder Model
  static HolderType _parseHolderType(String s) {
    switch (s) {
      case 'masterStudent':
        return HolderType.masterStudent;
      case 'phdStudent':
        return HolderType.phdStudent;
      case 'employee':
        return HolderType.employee;
      case 'medical':
        return HolderType.medical;
      default:
        return HolderType.bachelorStudent;
    }
  }

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }
}
