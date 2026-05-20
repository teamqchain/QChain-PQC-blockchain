// issuing/issuing_models.dart
// All models and mock data for the issuing section pages.

// ─── ENUMS ────────────────────────────────────────────────────────────────────

import 'package:qportal_webapp/screens/verifier/subscription_page.dart';

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
    if (t.contains('bsc') ||
        t.contains('msc') ||
        t.contains('phd') ||
        t.contains('diploma'))
      return 'Academic';
    if (t.contains('medical') ||
        t.contains('nursing') ||
        t.contains('pharmaceutical'))
      return 'Medical';
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
        t.contains('pharmaceutical'))
      return 'Ministry of Health';
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
// Columns used in the batch upload template (BSc Degree schema):
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
  // ── Holders ────────────────────────────────────────────────────────────────
  static const holders = [
    HolderRecord(
      id: 'H-0001',
      fullName: 'Ahmed Al Mansouri',
      email: 'ahmed.mansouri@student.uos.ae',
      type: HolderType.bachelorStudent,
      college: 'College of Computing & Informatics',
      walletAddress: 'QW-A1B2C3D4',
      emiratesID: '784-1990-1234567-1',
    ),
    HolderRecord(
      id: 'H-0002',
      fullName: 'Sara Al Hashimi',
      email: 'sara.hashimi@student.uos.ae',
      type: HolderType.bachelorStudent,
      college: 'College of Business Administration',
      walletAddress: 'QW-E5F6A7B8',
      emiratesID: '784-1995-7654321-2',
    ),

    // HolderRecord(
    //   id: 'HC-00101',
    //   fullName: 'Ahmed Al Rashidi',
    //   email: 'a.rashidi@student.uos.ae',
    //   type: HolderType.bachelorStudent,
    //   college: 'College of Engineering',
    //   walletAddress: 'QW-1A2B3C4D',
    //   emiratesID: 'xxx-xxxx-xxxxxxx-x',
    // ),
    // HolderRecord(
    //   id: 'HC-00184',
    //   fullName: 'Dr. Sara Al Mansoori',
    //   email: 's.mansoori@uos.ae',
    //   type: HolderType.medical,
    //   college: 'College of Medicine',
    //   walletAddress: 'QW-9F8E7D6C',
    //   emiratesID: 'xxx-xxxx-xxxxxxx-x',
    // ),
    // HolderRecord(
    //   id: 'HC-00291',
    //   fullName: 'Mohammed Ali',
    //   email: 'm.ali@student.uos.ae',
    //   type: HolderType.bachelorStudent,
    //   college: 'College of Computing & Informatics',
    //   walletAddress: 'QW-2C3D4E5F',
    //   emiratesID: 'xxx-xxxx-xxxxxxx-x',
    // ),
    // HolderRecord(
    //   id: 'HC-00312',
    //   fullName: 'Fatima Al Hashimi',
    //   email: 'f.hashimi@student.uos.ae',
    //   type: HolderType.masterStudent,
    //   college: 'College of Business Administration',
    //   walletAddress: 'QW-3E4F5A6B',
    //   emiratesID: 'xxx-xxxx-xxxxxxx-x',
    // ),
    // HolderRecord(
    //   id: 'HC-00392',
    //   fullName: 'Khalid Hassan',
    //   email: 'k.hassan@uos.ae',
    //   type: HolderType.employee,
    //   college: 'N/A',
    //   walletAddress: 'QW-5B6C7D8E',
    //   emiratesID: 'xxx-xxxx-xxxxxxx-x',
    // ),
    // HolderRecord(
    //   id: 'HC-00445',
    //   fullName: 'Mariam Yusuf',
    //   email: 'm.yusuf@student.uos.ae',
    //   type: HolderType.phdStudent,
    //   college: 'College of Science',
    //   walletAddress: 'QW-6C7D8E9F',
    //   emiratesID: 'xxx-xxxx-xxxxxxx-x',
    // ),
    // HolderRecord(
    //   id: 'HC-00547',
    //   fullName: 'Layla Khalid',
    //   email: 'l.khalid@student.uos.ae',
    //   type: HolderType.bachelorStudent,
    //   college: 'College of Arts & Humanities',
    //   walletAddress: 'QW-7D8E9F0A',
    //   emiratesID: 'xxx-xxxx-xxxxxxx-x',

    // ),
    // HolderRecord(
    //   id: 'HC-00601',
    //   fullName: 'Nour Ibrahim',
    //   email: 'n.ibrahim@student.uos.ae',
    //   type: HolderType.masterStudent,
    //   college: 'College of Engineering',
    //   walletAddress: 'QW-8E9F0A1B',
    //   emiratesID: 'xxx-xxxx-xxxxxxx-x',
    // ),
    // HolderRecord(
    //   id: 'HC-00618',
    //   fullName: 'Omar Saeed',
    //   email: 'o.saeed@uos.ae',
    //   type: HolderType.employee,
    //   college: 'N/A',
    //   walletAddress: 'QW-9F0A1B2C',
    //   emiratesID: 'xxx-xxxx-xxxxxxx-x',
    // ),
    // HolderRecord(
    //   id: 'HC-00724',
    //   fullName: 'Reem Al Zaabi',
    //   email: 'r.zaabi@student.uos.ae',
    //   type: HolderType.phdStudent,
    //   college: 'College of Law',
    //   walletAddress: 'QW-0A1B2C3D',
    //   emiratesID: 'xxx-xxxx-xxxxxxx-x',
    // ),
    // HolderRecord(
    //   id: 'HC-00801',
    //   fullName: 'Tariq Al Nasser',
    //   email: 't.nasser@student.uos.ae',
    //   type: HolderType.masterStudent,
    //   college: 'College of Computing & Informatics',
    //   walletAddress: 'QW-1B2C3D4E',
    //   emiratesID: 'xxx-xxxx-xxxxxxx-x',
    // ),
    // HolderRecord(
    //   id: 'HC-00852',
    //   fullName: 'Hessa Al Mazrouei',
    //   email: 'h.mazrouei@student.uos.ae',
    //   type: HolderType.bachelorStudent,
    //   college: 'College of Pharmacy',
    //   walletAddress: 'QW-2C3D4E5F',
    //   emiratesID: 'xxx-xxxx-xxxxxxx-x',
    // ),
  ];

  // ── Schemas ────────────────────────────────────────────────────────────────
  static final schemas = [
    SchemaRecord(
      id: 'SCH-001',
      name: 'BSc Degree',
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
          label: 'Degree Title',
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
            'College of Business Administration',
            'College of Arts & Humanities',
            'College of Law',
            'College of Medicine',
            'College of Pharmacy',
          ],
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
      name: 'MSc Degree',
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
          label: 'Degree Title',
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
            'College of Business Administration',
          ],
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

  // ── Credentials ────────────────────────────────────────────────────────────
  static final credentials = [
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2025-009182',
      holderName: 'Mohammed Ali',
      holderEmail: 'm.ali@student.uos.ae',
      holderId: 'HC-00291',
      credentialType: 'BSc Computer Science',
      issuedBy: 'Registrar Ali',
      issueDate: '15 Jan 2024',
      expiryDate: '15 Jan 2029',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Registrar Ali',
          date: '15 Jan 2024',
        ),
      ],
      attributes: {
        'Degree Title': 'BSc Computer Science',
        'Grade': 'Distinction',
        'Student ID': 'HC-00291',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2025-008741',
      holderName: 'Dr. Sara Al Mansoori',
      holderEmail: 's.mansoori@uos.ae',
      holderId: 'HC-00184',
      credentialType: 'Medical License',
      issuedBy: 'Compliance Officer',
      issueDate: '01 Mar 2022',
      expiryDate: '01 Mar 2027',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Compliance Officer',
          date: '01 Mar 2022',
        ),
      ],
      attributes: {
        'License Type': 'Full Practicing',
        'License No': 'ML-2022-0184',
        'Specialty': 'Internal Medicine',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2025-007192',
      holderName: 'Khalid Hassan',
      holderEmail: 'k.hassan@uos.ae',
      holderId: 'HC-00392',
      credentialType: 'Higher Training Certificate',
      issuedBy: 'Mohammed A.',
      issueDate: '10 Aug 2023',
      status: CredentialStatus.revoked,
      revokedBy: 'Mohammed A.',
      revokedDate: '10 May 2025',
      revokedReason: 'Disciplinary action',
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Mohammed A.',
          date: '10 Aug 2023',
        ),
        AuditEntry(
          action: 'Revoked',
          performedBy: 'Mohammed A.',
          date: '10 May 2025',
          note: 'Disciplinary action',
        ),
      ],
      attributes: {
        'Programme Title': 'PMP Certification',
        'Training Hours': '40',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2025-006831',
      holderName: 'Layla Khalid',
      holderEmail: 'l.khalid@student.uos.ae',
      holderId: 'HC-00547',
      credentialType: 'Higher Training Certificate',
      issuedBy: 'Registrar Ali',
      issueDate: '05 Jan 2025',
      expiryDate: '05 Jan 2026',
      status: CredentialStatus.suspended,
      suspendedReason: 'Audit review in progress',
      suspendedUntil: '05 Aug 2025',
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Registrar Ali',
          date: '05 Jan 2025',
        ),
        AuditEntry(
          action: 'Suspended',
          performedBy: 'Compliance Officer',
          date: '15 Jul 2025',
        ),
      ],
      attributes: {
        'Programme Title': 'Information Security Awareness',
        'Training Hours': '8',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2024-005210',
      holderName: 'Omar Saeed',
      holderEmail: 'o.saeed@uos.ae',
      holderId: 'HC-00618',
      credentialType: 'Employee ID',
      issuedBy: 'Mohammed A.',
      issueDate: '01 Jun 2024',
      expiryDate: '01 Jun 2025',
      status: CredentialStatus.expired,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Mohammed A.',
          date: '01 Jun 2024',
        ),
      ],
      attributes: {
        'Department': 'Information Technology',
        'Employee No': 'EMP-2024-0618',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2025-004817',
      holderName: 'Ahmed Al Rashidi',
      holderEmail: 'a.rashidi@student.uos.ae',
      holderId: 'HC-00101',
      credentialType: 'BSc Electrical Engineering',
      issuedBy: 'Registrar Ali',
      issueDate: '20 Feb 2025',
      expiryDate: '20 Feb 2030',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Registrar Ali',
          date: '20 Feb 2025',
        ),
      ],
      attributes: {
        'Degree Title': 'BSc Electrical Engineering',
        'Grade': 'Merit',
        'Student ID': 'HC-00101',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2025-004312',
      holderName: 'Fatima Al Hashimi',
      holderEmail: 'f.hashimi@student.uos.ae',
      holderId: 'HC-00312',
      credentialType: 'MSc Business Administration',
      issuedBy: 'Registrar Ali',
      issueDate: '10 Mar 2025',
      expiryDate: '10 Mar 2030',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Registrar Ali',
          date: '10 Mar 2025',
        ),
      ],
      attributes: {
        'Degree Title': 'MSc Business Administration',
        'Grade': 'Merit',
        'Student ID': 'HC-00312',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2025-003991',
      holderName: 'Mariam Yusuf',
      holderEmail: 'm.yusuf@student.uos.ae',
      holderId: 'HC-00445',
      credentialType: 'Research Fellowship',
      issuedBy: 'Mohammed A.',
      issueDate: '01 Sep 2024',
      expiryDate: '01 Sep 2026',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Mohammed A.',
          date: '01 Sep 2024',
        ),
      ],
      attributes: {
        'Fellowship Title': 'Postdoctoral Research Fellow',
        'Department': 'Quantum Computing',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2025-003654',
      holderName: 'Nour Ibrahim',
      holderEmail: 'n.ibrahim@student.uos.ae',
      holderId: 'HC-00601',
      credentialType: 'MSc Mechanical Engineering',
      issuedBy: 'Registrar Ali',
      issueDate: '15 Apr 2025',
      expiryDate: '15 Apr 2030',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Registrar Ali',
          date: '15 Apr 2025',
        ),
      ],
      attributes: {
        'Degree Title': 'MSc Mechanical Engineering',
        'Grade': 'Distinction',
        'Student ID': 'HC-00601',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2025-003208',
      holderName: 'Reem Al Zaabi',
      holderEmail: 'r.zaabi@student.uos.ae',
      holderId: 'HC-00724',
      credentialType: 'PhD Quantum Machine Learning',
      issuedBy: 'Mohammed A.',
      issueDate: '01 Jun 2025',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Mohammed A.',
          date: '01 Jun 2025',
        ),
      ],
      attributes: {
        'Research Field': 'Quantum Machine Learning',
        'Student ID': 'HC-00724',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2025-002971',
      holderName: 'Tariq Al Nasser',
      holderEmail: 't.nasser@student.uos.ae',
      holderId: 'HC-00801',
      credentialType: 'MSc Cybersecurity',
      issuedBy: 'Registrar Ali',
      issueDate: '22 Jan 2025',
      expiryDate: '22 Jan 2030',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Registrar Ali',
          date: '22 Jan 2025',
        ),
      ],
      attributes: {
        'Degree Title': 'MSc Cybersecurity',
        'Grade': 'Merit',
        'Student ID': 'HC-00801',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2025-002640',
      holderName: 'Hessa Al Mazrouei',
      holderEmail: 'h.mazrouei@student.uos.ae',
      holderId: 'HC-00852',
      credentialType: 'BSc Pharmaceutical Sciences',
      issuedBy: 'Compliance Officer',
      issueDate: '05 May 2025',
      expiryDate: '05 May 2030',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Compliance Officer',
          date: '05 May 2025',
        ),
      ],
      attributes: {
        'Degree Title': 'BSc Pharmaceutical Sciences',
        'Grade': 'Pass',
        'Student ID': 'HC-00852',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2024-002301',
      holderName: 'Saeed Al Hamdan',
      holderEmail: 's.hamdan@student.uos.ae',
      holderId: 'HC-00931',
      credentialType: 'Diploma in Business Technology',
      issuedBy: 'Registrar Ali',
      issueDate: '10 Dec 2023',
      expiryDate: '10 Dec 2025',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Registrar Ali',
          date: '10 Dec 2023',
        ),
      ],
      attributes: {
        'Programme Name': 'Diploma in Business Technology',
        'Grade': 'Merit',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2024-002088',
      holderName: 'Mona Al Suwaidi',
      holderEmail: 'm.suwaidi@uos.ae',
      holderId: 'HC-00955',
      credentialType: 'Medical License',
      issuedBy: 'Compliance Officer',
      issueDate: '18 Nov 2023',
      expiryDate: '18 Nov 2028',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Compliance Officer',
          date: '18 Nov 2023',
        ),
      ],
      attributes: {
        'License Type': 'Full Practicing',
        'Specialty': 'Pediatrics',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2024-001876',
      holderName: 'Faisal Al Blooshi',
      holderEmail: 'f.blooshi@student.uos.ae',
      holderId: 'HC-01002',
      credentialType: 'BSc Civil Engineering',
      issuedBy: 'Registrar Ali',
      issueDate: '30 Sep 2023',
      expiryDate: '30 Sep 2028',
      status: CredentialStatus.revoked,
      revokedBy: 'Mohammed A.',
      revokedDate: '01 Feb 2025',
      revokedReason: 'Academic misconduct',
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Registrar Ali',
          date: '30 Sep 2023',
        ),
        AuditEntry(
          action: 'Revoked',
          performedBy: 'Mohammed A.',
          date: '01 Feb 2025',
          note: 'Academic misconduct',
        ),
      ],
      attributes: {'Degree Title': 'BSc Civil Engineering', 'Grade': 'Pass'},
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2024-001543',
      holderName: 'Aisha Bin Laden',
      holderEmail: 'a.binladen@student.uos.ae',
      holderId: 'HC-01045',
      credentialType: 'Higher Training Certificate',
      issuedBy: 'Mohammed A.',
      issueDate: '14 Jul 2023',
      expiryDate: '14 Jul 2024',
      status: CredentialStatus.expired,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Mohammed A.',
          date: '14 Jul 2023',
        ),
      ],
      attributes: {
        'Programme Title': 'Project Management Foundations',
        'Training Hours': '60',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2024-001290',
      holderName: 'Yousef Al Marzouqi',
      holderEmail: 'y.marzouqi@student.uos.ae',
      holderId: 'HC-01089',
      credentialType: 'BSc Mathematics',
      issuedBy: 'Registrar Ali',
      issueDate: '20 Jun 2023',
      expiryDate: '20 Jun 2028',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Registrar Ali',
          date: '20 Jun 2023',
        ),
      ],
      attributes: {'Degree Title': 'BSc Mathematics', 'Grade': 'Distinction'},
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2024-001102',
      holderName: 'Shahd Al Owais',
      holderEmail: 's.owais@student.uos.ae',
      holderId: 'HC-01122',
      credentialType: 'BSc Biomedical Engineering',
      issuedBy: 'Compliance Officer',
      issueDate: '05 May 2023',
      expiryDate: '05 May 2028',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Compliance Officer',
          date: '05 May 2023',
        ),
      ],
      attributes: {
        'Degree Title': 'BSc Biomedical Engineering',
        'Grade': 'Merit',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2024-000891',
      holderName: 'Hamad Al Ketbi',
      holderEmail: 'h.ketbi@uos.ae',
      holderId: 'HC-01198',
      credentialType: 'Research Fellowship',
      issuedBy: 'Mohammed A.',
      issueDate: '01 Mar 2023',
      expiryDate: '01 Mar 2025',
      status: CredentialStatus.expired,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Mohammed A.',
          date: '01 Mar 2023',
        ),
      ],
      attributes: {
        'Fellowship Title': 'Visiting Research Fellow',
        'Department': 'Cybersecurity',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2024-000712',
      holderName: 'Lujain Al Dhaheri',
      holderEmail: 'l.dhaheri@student.uos.ae',
      holderId: 'HC-01234',
      credentialType: 'MSc Artificial Intelligence',
      issuedBy: 'Registrar Ali',
      issueDate: '15 Feb 2023',
      expiryDate: '15 Feb 2028',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Registrar Ali',
          date: '15 Feb 2023',
        ),
      ],
      attributes: {
        'Degree Title': 'MSc Artificial Intelligence',
        'Grade': 'Distinction',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2023-000598',
      holderName: 'Khamis Al Muhairi',
      holderEmail: 'k.muhairi@student.uos.ae',
      holderId: 'HC-01301',
      credentialType: 'Diploma in IT',
      issuedBy: 'Registrar Ali',
      issueDate: '01 Dec 2022',
      expiryDate: '01 Dec 2024',
      status: CredentialStatus.expired,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Registrar Ali',
          date: '01 Dec 2022',
        ),
      ],
      attributes: {
        'Programme Name': 'Diploma in Information Technology',
        'Grade': 'Pass',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2023-000487',
      holderName: 'Noura Al Shamsi',
      holderEmail: 'n.shamsi@student.uos.ae',
      holderId: 'HC-01355',
      credentialType: 'BSc Architecture',
      issuedBy: 'Registrar Ali',
      issueDate: '10 Oct 2022',
      expiryDate: '10 Oct 2027',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Registrar Ali',
          date: '10 Oct 2022',
        ),
      ],
      attributes: {'Degree Title': 'BSc Architecture', 'Grade': 'Distinction'},
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2023-000374',
      holderName: 'Abdullah Al Kaabi',
      holderEmail: 'a.kaabi@uos.ae',
      holderId: 'HC-01402',
      credentialType: 'Medical License',
      issuedBy: 'Compliance Officer',
      issueDate: '20 Aug 2022',
      expiryDate: '20 Aug 2027',
      status: CredentialStatus.suspended,
      suspendedReason: 'License renewal under review',
      suspendedUntil: '20 Oct 2025',
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Compliance Officer',
          date: '20 Aug 2022',
        ),
        AuditEntry(
          action: 'Suspended',
          performedBy: 'Compliance Officer',
          date: '10 Jun 2025',
        ),
      ],
      attributes: {'License Type': 'Full Practicing', 'Specialty': 'Surgery'},
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2023-000261',
      holderName: 'Maryam Al Falasi',
      holderEmail: 'm.falasi@student.uos.ae',
      holderId: 'HC-01448',
      credentialType: 'Higher Training Certificate',
      issuedBy: 'Mohammed A.',
      issueDate: '05 Jun 2022',
      expiryDate: '05 Jun 2023',
      status: CredentialStatus.expired,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Mohammed A.',
          date: '05 Jun 2022',
        ),
      ],
      attributes: {
        'Programme Title': 'Data Science Bootcamp',
        'Training Hours': '120',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2023-000189',
      holderName: 'Sultan Al Qubaisi',
      holderEmail: 's.qubaisi@student.uos.ae',
      holderId: 'HC-01501',
      credentialType: 'BSc Environmental Science',
      issuedBy: 'Registrar Ali',
      issueDate: '20 Apr 2022',
      expiryDate: '20 Apr 2027',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Registrar Ali',
          date: '20 Apr 2022',
        ),
      ],
      attributes: {
        'Degree Title': 'BSc Environmental Science',
        'Grade': 'Merit',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2022-000147',
      holderName: 'Wafa Al Nuaimi',
      holderEmail: 'w.nuaimi@student.uos.ae',
      holderId: 'HC-01567',
      credentialType: 'MSc Finance',
      issuedBy: 'Registrar Ali',
      issueDate: '15 Feb 2022',
      expiryDate: '15 Feb 2027',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Registrar Ali',
          date: '15 Feb 2022',
        ),
      ],
      attributes: {'Degree Title': 'MSc Finance', 'Grade': 'Merit'},
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2022-000098',
      holderName: 'Jasim Al Hammadi',
      holderEmail: 'j.hammadi@uos.ae',
      holderId: 'HC-01622',
      credentialType: 'Research Fellowship',
      issuedBy: 'Mohammed A.',
      issueDate: '01 Jan 2022',
      expiryDate: '01 Jan 2024',
      status: CredentialStatus.revoked,
      revokedBy: 'Mohammed A.',
      revokedDate: '15 Mar 2023',
      revokedReason: 'Fellowship terminated early',
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Mohammed A.',
          date: '01 Jan 2022',
        ),
        AuditEntry(
          action: 'Revoked',
          performedBy: 'Mohammed A.',
          date: '15 Mar 2023',
          note: 'Fellowship terminated early',
        ),
      ],
      attributes: {
        'Fellowship Title': 'Part-Time Research Fellow',
        'Department': 'Biomedical Research',
      },
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2022-000051',
      holderName: 'Amna Al Hajri',
      holderEmail: 'a.hajri@student.uos.ae',
      holderId: 'HC-01678',
      credentialType: 'BSc Nursing',
      issuedBy: 'Compliance Officer',
      issueDate: '10 Nov 2021',
      expiryDate: '10 Nov 2026',
      status: CredentialStatus.valid,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Compliance Officer',
          date: '10 Nov 2021',
        ),
      ],
      attributes: {'Degree Title': 'BSc Nursing', 'Grade': 'Distinction'},
    ),
    CredentialRecord(
      holderEmiratesID: 'xxx-xxxx-xxxxxxx-x',
      id: 'QC-2022-000019',
      holderName: 'Rashid Al Mansoori',
      holderEmail: 'r.mansoori@student.uos.ae',
      holderId: 'HC-01712',
      credentialType: 'Diploma in Business Technology',
      issuedBy: 'Registrar Ali',
      issueDate: '01 Sep 2021',
      expiryDate: '01 Sep 2023',
      status: CredentialStatus.expired,
      auditTrail: [
        AuditEntry(
          action: 'Issued',
          performedBy: 'Registrar Ali',
          date: '01 Sep 2021',
        ),
      ],
      attributes: {
        'Programme Name': 'Diploma in Business Technology',
        'Grade': 'Pass',
      },
    ),
  ];

  // ── Staff ─────────────────────────────────────────────────────────────────
  static const staff = [
    StaffMember(
      id: 'STF-001',
      name: 'Mohammed A.',
      email: 'm.admin@org.ae',
      role: IssuerRole.admin,
      addedDate: '01 Jan 2024',
      status: StaffStatus.active,
    ),
    StaffMember(
      id: 'STF-002',
      name: 'Registrar Ali',
      email: 'r.ali@org.ae',
      role: IssuerRole.staff,
      addedDate: '10 Jan 2024',
      status: StaffStatus.active,
    ),
    StaffMember(
      id: 'STF-003',
      name: 'Compliance Officer',
      email: 'c.officer@org.ae',
      role: IssuerRole.staff,
      addedDate: '15 Feb 2024',
      status: StaffStatus.active,
    ),
    StaffMember(
      id: 'STF-004',
      name: 'Schema Manager',
      email: 'schema@org.ae',
      role: IssuerRole.schemaManager,
      addedDate: '01 Mar 2025',
      status: StaffStatus.invited,
    ),
    StaffMember(
      id: 'STF-005',
      name: 'Fatima Al Zahra',
      email: 'f.zahra@org.ae',
      role: IssuerRole.staff,
      addedDate: '20 Apr 2025',
      status: StaffStatus.active,
    ),
    StaffMember(
      id: 'STF-006',
      name: 'Omar Nasser',
      email: 'o.nasser@org.ae',
      role: IssuerRole.staff,
      addedDate: '05 Jun 2024',
      status: StaffStatus.invited,
    ),
  ];

  // ── Action Log ─────────────────────────────────────────────────────────────
  static const actionLog = [
    ActionLogEntry(
      credentialId: 'QC-2025-007192',
      holderName: 'Khalid Hassan',
      action: 'REVOKED',
      reason: 'Disciplinary action',
      doneBy: 'Admin',
      timestamp: '10 May 2025  14:22',
    ),
    ActionLogEntry(
      credentialId: 'QC-2025-006831',
      holderName: 'Layla Khalid',
      action: 'SUSPENDED',
      reason: 'Audit review in progress',
      doneBy: 'Compliance Officer',
      timestamp: '15 Jul 2025  09:10',
    ),
  ];

  // ── Batch preview rows ─────────────────────────────────────────────────────
  //
  // Fields map uses the exact column names from the upload template:
  //   Student ID · Degree Title · College · Grade · Graduation Year · Expiry Date
  //
  // fieldErrors maps column name → validation message shown inline under the cell.
  //
  static const batchPreview = [
    BatchRow(
      rowNumber: 1,
      holderId: 'HC-00291',
      holderName: 'Mohammed Ali',
      fields: {
        'Student ID': 'HC-00291',
        'Degree Title': 'BSc Computer Science',
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
        'Degree Title': 'BSc Electrical Engineering',
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
        'Degree Title': 'BSc Business Administration',
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
        'Degree Title': 'BSc Physics',
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
        'Degree Title': 'MSc Mechanical Engineering',
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
        'Degree Title': 'BSc Pharmaceutical Sciences',
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
