/// Shared certificate template helpers.
///
/// Both QPortal and QWallet build a [CertificateData] from the credential they
/// already hold in memory and hand it to [CertificateSheet] (see
/// certificate_viewer.dart), which renders the SVG background via flutter_svg
/// and overlays the field values as Flutter [Text] widgets on top. Nothing is
/// uploaded, saved, or persisted.

class CertificateData {
  final String holderName;
  final String studentId;
  final String degree;
  final String college;
  final String grade;
  final String graduationYear;
  final String issueDate;

  const CertificateData({
    required this.holderName,
    required this.studentId,
    required this.degree,
    required this.college,
    required this.grade,
    required this.graduationYear,
    required this.issueDate,
  });

  @override
  bool operator ==(Object other) {
    return other is CertificateData &&
        other.holderName == holderName &&
        other.studentId == studentId &&
        other.degree == degree &&
        other.college == college &&
        other.grade == grade &&
        other.graduationYear == graduationYear &&
        other.issueDate == issueDate;
  }

  @override
  int get hashCode => Object.hash(
        holderName,
        studentId,
        degree,
        college,
        grade,
        graduationYear,
        issueDate,
      );

  /// Builds certificate data from a label→value field map (QPortal form /
  /// QWallet attributes) plus holder/date context.
  factory CertificateData.fromFields({
    required String holderName,
    required String issueDate,
    required Map<String, String> fields,
    String? credentialType,
  }) {
    String pick(List<String> keys, [String fallback = '—']) {
      for (final key in keys) {
        for (final entry in fields.entries) {
          if (entry.key.toLowerCase().trim() == key.toLowerCase().trim() &&
              entry.value.trim().isNotEmpty) {
            return entry.value.trim();
          }
        }
      }
      return fallback;
    }

    final degree = pick(const [
      'Degree Title',
      'Programme Name',
      'Programme Title',
      'Fellowship Title',
      'Research Field',
    ], credentialType?.trim().isNotEmpty == true ? credentialType!.trim() : '—');

    return CertificateData(
      holderName: holderName.trim().isEmpty ? '—' : holderName.trim(),
      studentId: pick(const [
        'Student ID',
        'Participant ID',
        'Researcher ID',
        'Employee No',
      ]),
      degree: degree,
      college: pick(const ['College', 'Department']),
      grade: pick(const [
        'Grade',
        'Track',
        'Assessment Result',
        'Fellowship Type',
        'Level',
      ]),
      graduationYear: pick(const ['Graduation Year']),
      issueDate: issueDate.trim().isEmpty ? '—' : issueDate.trim(),
    );
  }
}
