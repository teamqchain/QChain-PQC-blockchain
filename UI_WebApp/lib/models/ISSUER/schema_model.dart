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


abstract class SchemaMockData {
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
        SchemaField(id: 'f1', label: 'College', type: SchemaFieldType.dropdown),
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
        SchemaField(id: 'f1', label: 'College', type: SchemaFieldType.dropdown),
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
}
