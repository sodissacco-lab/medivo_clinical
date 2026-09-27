/// Choices used by sign-up, profile editing and role management
/// (blueprint §1 target users, §23 account types).

/// Account types a person may choose when signing up.
/// Staff roles are only granted by a super administrator.
const Map<String, String> accountTypes = {
  'professional': 'Health professional',
  'student': 'Student',
  'patient': 'Patient or public',
};

const List<String> professions = [
  'Medical doctor',
  'Medical clinical officer',
  'Assistant medical clinical officer',
  'Nurse',
  'Midwife',
  'Pharmacist',
  'Laboratory professional',
  'Radiographer or radiologist',
  'Allied health professional',
  'Medical student',
  'Nursing student',
  'Clinical medicine student',
  'Other',
];

/// All seven roles from blueprint §23, in order of responsibility.
const Map<String, String> roleLabels = {
  'patient': 'Patient',
  'student': 'Student',
  'professional': 'Professional',
  'content_editor': 'Content editor',
  'medical_reviewer': 'Medical reviewer',
  'institution_admin': 'Institution admin',
  'super_admin': 'Super admin',
};

const Map<String, String> roleDescriptions = {
  'patient': 'Reads patient-friendly information.',
  'student': 'Full reference for learning.',
  'professional': 'Full clinical reference.',
  'content_editor': 'Writes and edits draft clinical content.',
  'medical_reviewer': 'Reviews and approves clinical content.',
  'institution_admin': 'Manages an institution\'s users and subscription.',
  'super_admin': 'Manages the whole platform, including roles.',
};
