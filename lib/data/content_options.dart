/// Labels for the content engine (blueprint §29–§31).

const Map<String, String> contentTypes = {
  'disease': 'Disease',
  'drug': 'Drug',
  'lab_test': 'Laboratory test',
  'radiology': 'Radiology topic',
  'calculator': 'Calculator',
  'emergency': 'Emergency protocol',
  'algorithm': 'Clinical algorithm',
  'guideline': 'Guideline',
  'article': 'Article',
};

/// Suggested start of the content code for each type, e.g. DIS-INF-011.
const Map<String, String> contentCodePrefixes = {
  'disease': 'DIS-',
  'drug': 'DRG-',
  'lab_test': 'LAB-',
  'radiology': 'RAD-',
  'calculator': 'CALC-',
  'emergency': 'EMR-',
  'algorithm': 'ALG-',
  'guideline': 'GDL-',
  'article': 'ART-',
};

/// Disease categories from blueprint §7.
const List<String> diseaseCategories = [
  'Cardiology',
  'Dermatology',
  'Endocrinology',
  'Gastroenterology',
  'Haematology',
  'Infectious Diseases',
  'Neurology',
  'Nephrology',
  'Obstetrics',
  'Gynaecology',
  'Oncology',
  'Ophthalmology',
  'ENT',
  'Paediatrics',
  'Psychiatry',
  'Respiratory',
  'Rheumatology',
  'Urology',
  'Emergency Medicine',
  'General Medicine',
  'Surgery',
];

/// Laboratory sections from blueprint §13.
const List<String> labCategories = [
  'Haematology',
  'Clinical Chemistry',
  'Microbiology',
  'Parasitology',
  'Immunology',
  'Endocrinology',
  'Urinalysis',
  'Coagulation',
  'Blood Bank',
];

/// Radiology categories from blueprint §14.
const List<String> radiologyCategories = [
  'Chest X-ray',
  'Abdominal X-ray',
  'Musculoskeletal',
  'CT',
  'MRI',
  'Ultrasound',
  'Obstetric ultrasound',
  'Neuroimaging',
];

/// Fixed category lists, where the blueprint defines them.
/// Calculator groups from blueprint §12.
const List<String> calculatorCategoryOptions = ['General', 'Emergency', 'Paediatrics', 'Obstetrics'];

const Map<String, List<String>> fixedCategories = {
  'calculator': calculatorCategoryOptions,
  'emergency': ['Emergency'],
  'algorithm': ['Symptom pathway'],
  'disease': diseaseCategories,
  'lab_test': labCategories,
  'radiology': radiologyCategories,
};

/// Plural names for the reference lists.
const Map<String, String> contentTypePlurals = {
  'disease': 'Diseases',
  'drug': 'Drugs',
  'lab_test': 'Laboratory',
  'radiology': 'Radiology',
  'calculator': 'Calculators',
  'emergency': 'Emergency',
  'algorithm': 'Clinical algorithms',
  'guideline': 'Guidelines',
  'article': 'Articles',
};

/// Workflow stages from blueprint §30.
const Map<String, String> statusLabels = {
  'draft': 'Draft',
  'editor_review': 'Medical editor',
  'peer_review': 'Peer review',
  'clinical_approval': 'Clinical approval',
  'approved': 'Approved',
  'published': 'Published',
  'superseded': 'Superseded',
  'archived': 'Archived',
};

const List<String> reviewStatuses = ['editor_review', 'peer_review', 'clinical_approval'];

const Set<String> contentStaffRoles = {'content_editor', 'medical_reviewer', 'super_admin'};

const Map<String, String> actionLabels = {
  'created': 'Created',
  'imported': 'Imported',
  'revision_started': 'Revision started',
  'submit': 'Submit for review',
  'editor_pass': 'Pass medical editor check',
  'peer_pass': 'Pass peer review',
  'approve': 'Give clinical approval',
  'request_changes': 'Request changes',
  'withdraw': 'Withdraw to draft',
  'publish': 'Publish',
  'confirm_review': 'Confirm still current',
  'archive': 'Archive',
};

/// Past-tense wording for the history list.
const Map<String, String> actionHistoryLabels = {
  'created': 'Created',
  'imported': 'Imported as a draft',
  'revision_started': 'Revision started',
  'submit': 'Submitted for review',
  'editor_pass': 'Passed medical editor check',
  'peer_pass': 'Passed peer review',
  'approve': 'Clinically approved',
  'request_changes': 'Changes requested',
  'withdraw': 'Withdrawn to draft',
  'publish': 'Published',
  'confirm_review': 'Periodic review confirmed',
  'archive': 'Archived',
};

/// Actions that must include a note.
const Set<String> actionsNeedingNote = {'request_changes', 'archive'};