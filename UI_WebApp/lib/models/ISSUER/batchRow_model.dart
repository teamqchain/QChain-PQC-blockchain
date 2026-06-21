
enum BatchRowState { valid, warning, error }

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

abstract class BatchMockData {
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
