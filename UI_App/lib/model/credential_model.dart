import 'package:flutter/material.dart';
import 'package:qwallet_mobileapp/theme/colors.dart';

class CredentialModel {
  final String credentialID;
  final String credentialType;
  final String holderName;
  final String holderEID;
  final String issuedBy;
  final String issuedAt;
  final String? expiryDate;
  final String status;
  bool isFavorite;
  final String category;

  CredentialModel({
    required this.credentialID,
    required this.credentialType,
    required this.holderName,
    required this.holderEID,
    required this.issuedBy,
    required this.issuedAt,
    this.expiryDate,
    required this.status,
    this.isFavorite = false,
    required this.category,
  });

  factory CredentialModel.fromJson(Map<String, dynamic> json) {
    return CredentialModel(
      credentialID: json['credentialID'] ?? '',
      credentialType: json['credentialType'] ?? 'Document',
      holderName: json['holderName'] ?? 'Unknown',
      holderEID: json['holderEID'] ?? '',
      issuedBy: json['issuedBy'] ?? 'Unknown Issuer',
      issuedAt: json['issuedAt'] ?? '',
      expiryDate: json['expiryDate'],
      status: json['status'] ?? 'active',
      isFavorite: json['isFavorite'] == true || json['isFavorite'] == 1,
      category: json['category'] ?? 'General',
    );
  }

  // ─── UI MAPPERS ────────────────────────────────────────────────────────────

  static const Map<String, Map<String, List<String>>> degreesByCollege = {
    'SCH-001': {
      'College of Sharia & Islamic Studies': [
        'Bachelors in Fundamentals of Religions',
        'Bachelors in Jurisprudence & its fundamentals',
        'Bachelors in Religious Discourse and Community Communication',
      ],
      'College of Arts,Humanities & SocialScience': [
        'Bachelors in Arabic Language & literature',
        'Bachelors in English Language & literature',
        'Bachelors in French Language & literature',
        'Bachelors in Sociology',
        'Bachelors in History & Islamic Civilization',
        'Bachelors in History & Islamic Civilization-Tourist guide',
        'Bachelors in Early Childhood',
        'Bachelors in Arabic for Non‐Native Speakers',
        'Bachelors in Family Counseling and Guidance',
      ],
      'College of Public Policy': ['Bachelors in International relation'],
      'College of Law(Arabic)': ['Bachelors in Law (Arabic)'],
      'College of Law(English)': ['Bachelors in Law (English)'],
      'College of Fine Arts & Design': [
        'Bachelors in Fine Arts',
        'Bachelors in Interior Design',
        'Bachelors in Fashion Design & Textiles',
        'Bachelors in Visual Communication',
        'Bachelors in Art History and Museum Studies',
      ],
      'College of Science': [
        'Bachelors in Chemistry',
        'Bachelors in Applied Physics',
        'Bachelors in Mathematics',
        'Bachelors in Biotechnology',
        'Bachelors in Petroleum Geoscience & Remote Sensing',
      ],
      'College of Business Administration': [
        'Bachelors in Accounting',
        'Bachelors in Business Administration-Management',
        'Bachelors in Business Administration-Marketing',
        'Bachelors in Supply Chain Management',
        'Bachelors in Finance',
        'Bachelors in Economics',
      ],
      'College of Computing & Informatics': [
        'Bachelors in Computer Science',
        'Bachelors in Information Technology-Multimedia',
        'Bachelors in Business Information System',
        'Bachelors in Computer Engineering',
        'Bachelors in CyberSecurity Engineering',
        'Bachelors in Biomedical Informatics',
      ],
      'College of Mass communication': [
        'Bachelors in Public Relations',
        'Bachelors in Communication-Electronic Journalism',
        'Bachelors in Communication-Digital Media Design',
        'Bachelors in Communication-Radio & Television',
        'Bachelors in Mass Communication(Eng)',
        'Bachelors in Strategic Communication and Advertising',
      ],
      'College of Engineering': [
        'Bachelors in Civil Engineering',
        'Bachelors in Architectural Engineering',
        'Bachelors in Nuclear Engineering',
        'Bachelors in Chemical&Water Desalination Engineering',
        'Bachelors in Mechanical Engineering',
        'Bachelors in Mechatronics & Robotics Engineering',
        'Bachelors in Electrical & Electronics Engineering',
        'Bachelors in Sustainable&Renewable Energy Engineering',
        'Bachelors in Industrial Engineering & Engineering Management',
      ],
      'College of Health Sciences': [
        'Bachelors in Medical Laboratory Sciences',
        'Bachelors in Health Services Administration',
        'Bachelors in Environmental Health Sciences',
        'Bachelors in Clinical Nutrition & Dietetics',
        'Bachelors in Medical Diagnostic Imaging',
        'Bachelors in Nursing',
        'Bachelors in Physiotherapy',
        'Bachelors in Audiology and Speech Language Pathology',
      ],
      'College of Pharmacy': ['Bachelors in Pharmacy'],
    },
    'SCH-002': {
      'College of Computing & Informatics': [
        'Masters Computer Science',
        'Masters Cybersecurity',
        'Masters Artificial Intelligence',
      ],
      'College of Engineering': ['Masters Mechanical Engineering'],
      'College of Business Administration': [
        'Masters Business Administration',
        'Masters Finance',
      ],
      'College of Science': [],
    },
  };

  IconData get icon {
    final type = credentialType.toLowerCase();
    if (type.contains('bachelor') || type.contains('science'))
      return Icons.school;
    if (type.contains('health') || type.contains('medical'))
      return Icons.local_hospital;
    if (type.contains('passport') || type.contains('visa'))
      return Icons.menu_book;
    if (type.contains('insurance')) return Icons.shield;
    return Icons.badge;
  }

  Color _getCollegeColor(String collegeName) {
    switch (collegeName) {
      case 'College of Sharia & Islamic Studies':
        return qSharia;
      case 'College of Arts,Humanities & SocialScience':
        return qArts;
      case 'College of Law(Arabic)':
      case 'College of Law(English)':
        return qLaw;
      case 'College of Fine Arts & Design':
        return qFineArts;
      case 'College of Science':
        return qScience;
      case 'College of Business Administration':
        return qBusiness;
      case 'College of Computing & Informatics':
        return qCCI;
      case 'College of Mass communication':
        return qCommunication;
      case 'College of Engineering':
        return qEng;
      case 'College of Health Sciences':
        return qHealthScience;
      case 'College of Pharmacy':
        return qPharm;
      case 'College of Public Policy':
        return qPublicPolicy; 
      default:
        return qPrimary; // Ultimate fallback
    }
  }

  Color get cardColor {
    if (credentialID.isEmpty) return qAzureBlue;

    // Clean the backend degree title for a safe comparison
    final backendDegree = credentialType.toLowerCase().trim();

    // Search the duplicated map
    for (var campusLevel in degreesByCollege.values) {
      for (var collegeEntry in campusLevel.entries) {
        String collegeName = collegeEntry.key;
        List<String> degrees = collegeEntry.value;

        // Check if the current college contains the backend degree
        // Using lowercase matching so you don't have to worry about strict casing
        bool hasMatch = degrees.any(
          (degree) => degree.toLowerCase().trim() == backendDegree,
        );

        if (hasMatch) {
          // We found the college! Return its assigned color.
          return _getCollegeColor(collegeName);
        }
      }
    }

    // Fallback: If the degree isn't in the map at all, hash the ID
    final List<Color> palette = [
      qAzureBlue,
      qOceanTeal,
      qLeafGreen,
      qBurntOrange,
      qCherryRed,
      qMagentaPink,
      qAmethyst,
      qDeepViolet,
      qVibrantIndigo,
      qSlateBlue,
    ];

    return palette[credentialID.hashCode.abs() % palette.length];
  }

  // Color get cardColor {
  String get displayStatus {
    if (status.toLowerCase() == 'active') return 'Valid';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  String get formattedIssueDate {
    if (issuedAt.isEmpty) return 'Unknown';
    // Converts "2025-01-15T10:00:00" to "15 Jan 2025" logic can be expanded here
    try {
      final dt = DateTime.parse(issuedAt);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return issuedAt.split('T').first;
    }
  }

  String get formattedExpiryDate {
    if (expiryDate == null || expiryDate!.isEmpty) return 'No Expiry';
    try {
      final dt = DateTime.parse(expiryDate!);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return expiryDate!;
    }
  }
}
