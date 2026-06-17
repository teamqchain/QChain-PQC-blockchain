// issuing/issuing_models.dart
// All models and mock data for the issuing section pages.

// ─── ENUMS ────────────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:qportal_webapp/screens/verifier/subscription_page.dart';
import 'package:qportal_webapp/theme/appColours.dart';

enum CredentialStatus { valid, revoked, suspended, expired }

extension CredentialStatusX on CredentialStatus {
  String get label {
    switch (this) {
      case CredentialStatus.valid:
        return 'VALID';
      case CredentialStatus.revoked:
        return 'REVOKED';
      case CredentialStatus.suspended:
        return 'SUSPENDED';
      case CredentialStatus.expired:
        return 'EXPIRED';
    }
  }

  Color get bg {
    switch (this) {
      case CredentialStatus.valid:
        return AppColors.valid.withOpacity(0.13);
      case CredentialStatus.revoked:
        return AppColors.revoked.withOpacity(0.13);
      case CredentialStatus.suspended:
        return AppColors.suspended.withOpacity(0.13);
      case CredentialStatus.expired:
        return AppColors.expired.withOpacity(0.13);
    }
  }

  Color get fg {
    switch (this) {
      case CredentialStatus.valid:
        return AppColors.valid;
      case CredentialStatus.revoked:
        return AppColors.revoked;
      case CredentialStatus.suspended:
        return AppColors.suspended;
      case CredentialStatus.expired:
        return AppColors.expired;
    }
  }
}

enum SchemaFieldType { text, number, date, yesNo, dropdown }

extension SchemaFieldTypeX on SchemaFieldType {
  String get label {
    switch (this) {
      case SchemaFieldType.text:
        return 'Text';
      case SchemaFieldType.number:
        return 'Number';
      case SchemaFieldType.date:
        return 'Date';
      case SchemaFieldType.yesNo:
        return 'Yes / No';
      case SchemaFieldType.dropdown:
        return 'Dropdown';
    }
  }
}

enum BatchRowState { valid, warning, error }

enum IssuerRole { admin, staff, schemaManager }

extension IssuerRoleX on IssuerRole {
  String get label {
    switch (this) {
      case IssuerRole.admin:
        return 'Issuer Admin';
      case IssuerRole.staff:
        return 'Issuer Staff';
      case IssuerRole.schemaManager:
        return 'Schema Manager';
    }
  }

  String get description {
    switch (this) {
      case IssuerRole.admin:
        return 'Full issuing access + manage staff + settings';
      case IssuerRole.staff:
        return 'Issue and revoke, cannot manage staff or schemas';
      case IssuerRole.schemaManager:
        return 'Manage schemas only, cannot issue';
    }
  }
}

enum StaffStatus { active, invited }

extension StaffStatusX on StaffStatus {
  String get label {
    switch (this) {
      case StaffStatus.active:
        return 'Active';
      case StaffStatus.invited:
        return 'Invited';
    }
  }
}

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

// ─── HOLDER MODEL ─────────────────────────────────────────────────────────────

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

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }
}

// ─── CREDENTIAL MODEL ─────────────────────────────────────────────────────────

class CredentialRecord {
  final String holderEmiratesID;
  final String id;
  final String holderName;
  final String holderEmail;
  final String holderId;
  final String credentialType;
  final String issuedBy;
  final String issueDate;
  final String? expiryDate;
  final CredentialStatus status;
  final String? revokedBy;
  final String? revokedDate;
  final String? revokedReason;
  final String? suspendedReason;
  final String? suspendedUntil;
  final List<AuditEntry> auditTrail;
  final Map<String, String> attributes;
  final String signingAlgorithm;
  final String signatureHash;
  final String blockchainTxId;
  final String ipfsReference;

  const CredentialRecord({
    required this.holderEmiratesID,
    required this.id,
    required this.holderName,
    required this.holderEmail,
    required this.holderId,
    required this.credentialType,
    required this.issuedBy,
    required this.issueDate,
    this.expiryDate,
    required this.status,
    this.revokedBy,
    this.revokedDate,
    this.revokedReason,
    this.suspendedReason,
    this.suspendedUntil,
    required this.auditTrail,
    required this.attributes,
    this.signingAlgorithm = 'Dilithium (CRYSTALS-Dilithium3)',
    this.signatureHash = 'a3f9c2e1b8d74f6a...9c2b1',
    this.blockchainTxId = 'TXN-HLF-00291847',
    this.ipfsReference = 'ipfs://QmXf9a2...k8dP',
  });

  /// Derives the credential category from [credentialType].
  String get category {
    final t = credentialType.toLowerCase();
    if (t.contains('Bachelors') ||
        t.contains('Masters') ||
        t.contains('phd') ||
        t.contains('diploma')) {
      return 'Academic';
    }
    if (t.contains('medical') ||
        t.contains('nursing') ||
        t.contains('pharmaceutical')) {
      return 'Medical';
    }
    if (t.contains('training') || t.contains('certificate')) {
      return 'Professional';
    }
    if (t.contains('fellowship') || t.contains('research')) return 'Research';
    if (t.contains('employee')) return 'Corporate';
    return 'General';
  }

  /// Derives the issuing organisation from the credential type.
  String get issuerOrg {
    final t = credentialType.toLowerCase();
    if (t.contains('medical') ||
        t.contains('nursing') ||
        t.contains('pharmaceutical')) {
      return 'Ministry of Health';
    }
    if (t.contains('employee')) return 'Human Resources Dept.';
    if (t.contains('fellowship') || t.contains('research')) {
      return 'Research & Innovation Office';
    }
    return 'University of Sharjah';
  }
}

class AuditEntry {
  final String action;
  final String performedBy;
  final String date;
  final String? note;
  const AuditEntry({
    required this.action,
    required this.performedBy,
    required this.date,
    this.note,
  });
}

// ─── SCHEMA MODEL ─────────────────────────────────────────────────────────────

enum SchemaStatus { active, archived }

extension SchemaStatusX on SchemaStatus {
  String get label {
    switch (this) {
      case SchemaStatus.active:
        return 'Active';
      case SchemaStatus.archived:
        return 'Archived';
    }
  }
}

class SchemaRecord {
  final String id;
  final String name;
  final String description;
  final String category;
  final List<String> requirements;
  final int fieldsCount;
  final int credentialsIssued;
  final bool isActive;
  final List<SchemaField> fields;
  final String createdDate;
  final SchemaStatus schemaStatus;

  const SchemaRecord({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.requirements,
    required this.fieldsCount,
    required this.credentialsIssued,
    required this.isActive,
    required this.fields,
    this.createdDate = '01 Jan 2024',
    this.schemaStatus = SchemaStatus.active,
  });
}

class SchemaField {
  final String id;
  String label;
  SchemaFieldType type;
  bool required;
  bool visibleToVerifier;
  List<String> dropdownOptions;

  SchemaField({
    required this.id,
    required this.label,
    required this.type,
    this.required = true,
    this.visibleToVerifier = true,
    this.dropdownOptions = const [],
  });
}

// ─── STAFF MODEL ──────────────────────────────────────────────────────────────

class StaffMember {
  final String id;
  final String name;
  final String email;
  final IssuerRole role;
  final String addedDate;
  final StaffStatus status;

  const StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.addedDate,
    required this.status,
  });
}

// ─── BATCH ROW MODEL ──────────────────────────────────────────────────────────
//
// Columns used in the batch upload template (Bachelors Degree schema):
//   Student ID  |  Degree Title  |  College  |  Grade  |  Graduation Year  |  Expiry Date
//
// Student ID doubles as the Holder ID — it is used to look up the registered
// holder in the system.  The template uses "Student ID" as the user-facing
// column name because it is more familiar to university staff.
//
// fieldErrors maps column name → human-readable validation message.
// Errors are shown inline below the offending cell in the validation table.

class BatchRow {
  final int rowNumber;
  final String holderId; // = Holder ID in the system
  final String holderName;
  final Map<String, String> fields; // column label → value
  final Map<String, String>
  fieldErrors; // column label → error text (empty = no error)
  final BatchRowState state;

  const BatchRow({
    required this.rowNumber,
    required this.holderId,
    required this.holderName,
    required this.fields,
    this.fieldErrors = const {},
    required this.state,
  });

  /// Returns a copy with [state] and [fieldErrors] replaced.
  BatchRow copyWith({BatchRowState? state, Map<String, String>? fieldErrors}) {
    return BatchRow(
      rowNumber: rowNumber,
      holderId: holderId,
      holderName: holderName,
      fields: fields,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      state: state ?? this.state,
    );
  }
}

// ─── REVOKE/SUSPEND ACTION LOG ────────────────────────────────────────────────

class ActionLogEntry {
  final String credentialId;
  final String holderName;
  final String action;
  final String reason;
  final String doneBy;
  final String timestamp;

  const ActionLogEntry({
    required this.credentialId,
    required this.holderName,
    required this.action,
    required this.reason,
    required this.doneBy,
    required this.timestamp,
  });
}

// ─── MOCK DATA ─────────────────────────────────────────────────────────────────
abstract class IssuingMockData {
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
      'College of Computing & Informatic': [
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
  // ── Schemas ────────────────────────────────────────────────────────────────
  static final schemas = [
    SchemaRecord(
      id: 'SCH-001',
      name: 'Bachelors Degree',
      description:
          'Bachelor of Science academic degree awarded upon successful completion of an undergraduate programme.',
      category: 'Academic',
      requirements: [
        'Student must have completed all required credit hours',
        'Minimum CGPA of 2.0 required',
        'Student ID and full legal name',
        'College and major information',
        'Official graduation year',
      ],
      fieldsCount: 5,
      credentialsIssued: 248,
      isActive: true,
      fields: [
        SchemaField(
          id: 'f1',
          label: 'College',
          type: SchemaFieldType.dropdown,

        ),
        SchemaField(
          id: 'f2',
          label: 'Degree Title',
          type: SchemaFieldType.dropdown,
        ),
        SchemaField(id: 'f3', label: 'Student ID', type: SchemaFieldType.text),
        SchemaField(
          id: 'f4',
          label: 'Grade',
          type: SchemaFieldType.dropdown,
          dropdownOptions: ['Pass', 'Merit', 'Distinction'],
        ),
        SchemaField(
          id: 'f5',
          label: 'Graduation Year',
          type: SchemaFieldType.number,
        ),
      ],

      createdDate: '12 Mar 2022',
      schemaStatus: SchemaStatus.active,
    ),
    SchemaRecord(
      id: 'SCH-002',
      name: 'Masters Degree',
      description:
          'Master of Science postgraduate degree awarded upon completion of a master\'s programme.',
      category: 'Academic',
      requirements: [
        'Completion of all postgraduate modules',
        'Approved thesis or capstone project',
        'Student ID and full legal name',
        'Specialisation track',
        'Graduation year',
      ],
      fieldsCount: 5,
      credentialsIssued: 87,
      isActive: true,
      fields: [
        SchemaField(
          id: 'f1',
          label: 'College',
          type: SchemaFieldType.dropdown,
        ),
        SchemaField(
          id: 'f2',
          label: 'Degree Title',
          type: SchemaFieldType.dropdown,
        ),
        SchemaField(id: 'f3', label: 'Student ID', type: SchemaFieldType.text),
        SchemaField(
          id: 'f4',
          label: 'Track',
          type: SchemaFieldType.dropdown,
          dropdownOptions: ['Thesis Track', 'Coursework Track'],
        ),
        SchemaField(
          id: 'f5',
          label: 'Graduation Year',
          type: SchemaFieldType.number,
        ),
      ],

      createdDate: '12 Mar 2022',
      schemaStatus: SchemaStatus.active,
    ),
    SchemaRecord(
      id: 'SCH-003',
      name: 'PhD Degree',
      description:
          'Doctor of Philosophy credential awarded to candidates who have successfully defended an original research dissertation.',
      category: 'Academic',
      requirements: [
        'Successful dissertation defence',
        'Published research or accepted papers',
        'Student ID and full legal name',
        'Research field and college',
        'Graduation year',
      ],
      fieldsCount: 4,
      credentialsIssued: 34,
      isActive: true,
      fields: [
        SchemaField(
          id: 'f1',
          label: 'Research Field',
          type: SchemaFieldType.text,
        ),
        SchemaField(
          id: 'f2',
          label: 'College',
          type: SchemaFieldType.dropdown,
          dropdownOptions: [
            'College of Engineering',
            'College of Computing & Informatics',
            'College of Science',
          ],
        ),
        SchemaField(id: 'f3', label: 'Student ID', type: SchemaFieldType.text),
        SchemaField(
          id: 'f4',
          label: 'Graduation Year',
          type: SchemaFieldType.number,
        ),
      ],

      createdDate: '15 Jun 2022',
      schemaStatus: SchemaStatus.active,
    ),
    SchemaRecord(
      id: 'SCH-004',
      name: 'Diploma',
      description:
          'Undergraduate diploma awarded upon completion of a two-year professional programme.',
      category: 'Academic',
      requirements: [
        'Completion of all diploma modules',
        'Minimum CGPA of 2.0',
        'Student ID and full legal name',
        'Programme name',
      ],
      fieldsCount: 4,
      credentialsIssued: 112,
      isActive: true,
      fields: [
        SchemaField(
          id: 'f1',
          label: 'Programme Name',
          type: SchemaFieldType.text,
        ),
        SchemaField(
          id: 'f2',
          label: 'College',
          type: SchemaFieldType.dropdown,
          dropdownOptions: [
            'College of Engineering',
            'College of Business Administration',
            'College of Arts & Humanities',
          ],
        ),
        SchemaField(id: 'f3', label: 'Student ID', type: SchemaFieldType.text),
        SchemaField(
          id: 'f4',
          label: 'Grade',
          type: SchemaFieldType.dropdown,
          dropdownOptions: ['Pass', 'Merit', 'Distinction'],
        ),
      ],

      createdDate: '20 Aug 2022',
      schemaStatus: SchemaStatus.active,
    ),
    SchemaRecord(
      id: 'SCH-005',
      name: 'Higher Training Certificate',
      description:
          'Professional certificate awarded upon completion of an accredited higher training or continuing education programme.',
      category: 'Academic',
      requirements: [
        'Completion of training hours (minimum 120 hours)',
        'Passing assessment score of 70% or above',
        'Participant full name and ID',
        'Programme title and duration',
      ],
      fieldsCount: 4,
      credentialsIssued: 203,
      isActive: true,
      fields: [
        SchemaField(
          id: 'f1',
          label: 'Programme Title',
          type: SchemaFieldType.text,
        ),
        SchemaField(
          id: 'f2',
          label: 'Training Hours',
          type: SchemaFieldType.number,
        ),
        SchemaField(
          id: 'f3',
          label: 'Assessment Result',
          type: SchemaFieldType.dropdown,
          dropdownOptions: ['Pass', 'Distinction'],
        ),
        SchemaField(
          id: 'f4',
          label: 'Participant ID',
          type: SchemaFieldType.text,
        ),
      ],

      createdDate: '01 Nov 2022',
      schemaStatus: SchemaStatus.active,
    ),
    SchemaRecord(
      id: 'SCH-006',
      name: 'Medical License',
      description:
          'Professional medical practitioner license issued by an accredited healthcare institution.',
      category: 'Medical',
      requirements: [
        'Valid practitioner registration number',
        'Verified medical degree on file',
        'Specialty board certification (if applicable)',
        'Active standing with professional body',
      ],
      fieldsCount: 4,
      credentialsIssued: 92,
      isActive: true,
      fields: [
        SchemaField(
          id: 'f1',
          label: 'License Type',
          type: SchemaFieldType.text,
        ),
        SchemaField(id: 'f2', label: 'License No', type: SchemaFieldType.text),
        SchemaField(
          id: 'f3',
          label: 'Specialty',
          type: SchemaFieldType.dropdown,
          dropdownOptions: [
            'General Practice',
            'Surgery',
            'Pediatrics',
            'Internal Medicine',
            'Radiology',
            'Psychiatry',
          ],
        ),
        SchemaField(
          id: 'f4',
          label: 'Board Certified',
          type: SchemaFieldType.yesNo,
        ),
      ],

      createdDate: '10 Jan 2023',
      schemaStatus: SchemaStatus.active,
    ),
    SchemaRecord(
      id: 'SCH-007',
      name: 'Research Fellowship',
      description:
          'Credential awarded to researchers granted a formal fellowship position at the university.',
      category: 'Academic',
      requirements: [
        'Appointment letter from the Research Office',
        'Researcher ID',
        'Department and research group assignment',
        'Fellowship duration and type',
      ],
      fieldsCount: 4,
      credentialsIssued: 19,
      isActive: true,
      fields: [
        SchemaField(
          id: 'f1',
          label: 'Fellowship Title',
          type: SchemaFieldType.text,
        ),
        SchemaField(
          id: 'f2',
          label: 'Department',
          type: SchemaFieldType.dropdown,
          dropdownOptions: [
            'Artificial Intelligence',
            'Cybersecurity',
            'Biomedical Research',
            'Environmental Science',
            'Quantum Computing',
          ],
        ),
        SchemaField(
          id: 'f3',
          label: 'Researcher ID',
          type: SchemaFieldType.text,
        ),
        SchemaField(
          id: 'f4',
          label: 'Fellowship Type',
          type: SchemaFieldType.dropdown,
          dropdownOptions: ['Full-Time', 'Part-Time', 'Visiting'],
        ),
      ],

      createdDate: '05 Apr 2023',
      schemaStatus: SchemaStatus.active,
    ),
    SchemaRecord(
      id: 'SCH-008',
      name: 'Employee ID',
      description:
          'Corporate employee identification credential for active staff members.',
      category: 'Corporate',
      requirements: [
        'Active employment contract on file',
        'Employee number assigned by HR',
        'Department assignment confirmed',
        'Job level approved by line manager',
      ],
      fieldsCount: 3,
      credentialsIssued: 0,
      isActive: false,
      fields: [
        SchemaField(id: 'f1', label: 'Department', type: SchemaFieldType.text),
        SchemaField(id: 'f2', label: 'Employee No', type: SchemaFieldType.text),
        SchemaField(id: 'f3', label: 'Level', type: SchemaFieldType.text),
      ],

      createdDate: '01 Sep 2023',
      schemaStatus: SchemaStatus.archived,
    ),
  ];

  // ── Batch preview rows ─────────────────────────────────────────────────────
  static const batchPreview = [
    BatchRow(
      rowNumber: 1,
      holderId: 'HC-00291',
      holderName: 'Mohammed Ali',
      fields: {
        'Student ID': 'HC-00291',
        'Degree Title': 'Bachelors Computer Science',
        'College': 'College of Computing & Informatics',
        'Grade': 'Distinction',
        'Graduation Year': '2025',
        'Expiry Date': '30 Jun 2030',
      },
      state: BatchRowState.valid,
    ),
    BatchRow(
      rowNumber: 2,
      holderId: 'HC-00101',
      holderName: 'Ahmed Al Rashidi',
      fields: {
        'Student ID': 'HC-00101',
        'Degree Title': 'Bachelors Electrical Engineering',
        'College': 'College of Engineering',
        'Grade': 'Merit',
        'Graduation Year': '2025',
        'Expiry Date': '30 Jun 2030',
      },
      state: BatchRowState.valid,
    ),
    BatchRow(
      rowNumber: 3,
      holderId: 'HC-00547',
      holderName: 'Layla Khalid',
      fields: {
        'Student ID': 'HC-00547',
        'Degree Title': 'BA English Literature',
        'College': 'College of Arts & Humanities',
        'Grade': 'Pass',
        'Graduation Year': '2025',
        'Expiry Date': '',
      },
      fieldErrors: {'Expiry Date': 'missing'},
      state: BatchRowState.warning,
    ),
    BatchRow(
      rowNumber: 4,
      holderId: 'HC-00312',
      holderName: 'Fatima Al Hashimi',
      fields: {
        'Student ID': 'HC-00312',
        'Degree Title': 'Bachelors Business Administration',
        'College': 'College of Business Administration',
        'Grade': 'Merit',
        'Graduation Year': '2025',
        'Expiry Date': '30 Jun 2030',
      },
      state: BatchRowState.valid,
    ),
    BatchRow(
      rowNumber: 5,
      holderId: '',
      holderName: 'Unknown Student',
      fields: {
        'Student ID': '',
        'Degree Title': 'Bachelors Physics',
        'College': 'College of Science',
        'Grade': '',
        'Graduation Year': '2025',
        'Expiry Date': '30 Jun 2030',
      },
      fieldErrors: {'Student ID': 'Holder not found', 'Grade': 'required'},
      state: BatchRowState.error,
    ),
    BatchRow(
      rowNumber: 6,
      holderId: 'HC-00601',
      holderName: 'Nour Ibrahim',
      fields: {
        'Student ID': 'HC-00601',
        'Degree Title': 'Masters Mechanical Engineering',
        'College': 'College of Engineering',
        'Grade': 'Distinction',
        'Graduation Year': '2025',
        'Expiry Date': '30 Jun 2030',
      },
      state: BatchRowState.valid,
    ),
    BatchRow(
      rowNumber: 7,
      holderId: 'HC-00852',
      holderName: 'Hessa Al Mazrouei',
      fields: {
        'Student ID': 'HC-00852',
        'Degree Title': 'Bachelors Pharmaceutical Sciences',
        'College': 'College of Pharmacy',
        'Grade': '',
        'Graduation Year': '',
        'Expiry Date': '30 Jun 2030',
      },
      fieldErrors: {'Grade': 'required', 'Graduation Year': 'required'},
      state: BatchRowState.error,
    ),
    BatchRow(
      rowNumber: 8,
      holderId: 'HC-00724',
      holderName: 'Reem Al Zaabi',
      fields: {
        'Student ID': 'HC-00724',
        'Degree Title': 'LLB Law',
        'College': 'College of Law',
        'Grade': 'Merit',
        'Graduation Year': '2025',
        'Expiry Date': '',
      },
      fieldErrors: {'Expiry Date': 'missing'},
      state: BatchRowState.warning,
    ),
  ];
}
