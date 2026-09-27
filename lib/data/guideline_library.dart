/// The guideline library tree from blueprint §18. The entries themselves
/// are content items of type 'guideline' (codes GDL-…), shown to users
/// only once published.
class GuidelineEntry {
  const GuidelineEntry(this.code, this.title, this.group);

  final String code;
  final String title;
  final String group;
}

const List<String> ugandaGuidelineGroups = [
  'Uganda Clinical Guidelines',
  'National treatment guidelines',
  'HIV guidelines',
  'TB guidelines',
  'Malaria guidelines',
  'Maternal health',
  'Child health',
  'NCD guidelines',
];

const List<String> internationalGuidelineGroups = ['WHO', 'CDC', 'NICE', 'IDSA', 'Other approved sources'];

const List<GuidelineEntry> guidelineLibrary = [
  GuidelineEntry('GDL-UG-001', 'Uganda Clinical Guidelines 2023', 'Uganda Clinical Guidelines'),
  GuidelineEntry('GDL-UG-002', 'Essential Medicines and Health Supplies List for Uganda (EMHSLU) 2023', 'National treatment guidelines'),
  GuidelineEntry('GDL-UG-003', 'Consolidated Guidelines for the Prevention and Treatment of HIV and AIDS in Uganda', 'HIV guidelines'),
  GuidelineEntry('GDL-UG-004', 'Manual for Management and Control of Tuberculosis and Leprosy in Uganda', 'TB guidelines'),
  GuidelineEntry('GDL-UG-005', 'Malaria treatment in Uganda (national guidance)', 'Malaria guidelines'),
  GuidelineEntry('GDL-UG-006', 'Essential Maternal and Newborn Clinical Care Guidelines for Uganda', 'Maternal health'),
  GuidelineEntry('GDL-UG-007', 'Uganda National IMNCI Chart Booklet', 'Child health'),
  GuidelineEntry('GDL-UG-008', 'Uganda Integrated Guidelines for the Management of NCDs', 'NCD guidelines'),
  GuidelineEntry('GDL-INT-001', 'WHO Guidelines for malaria', 'WHO'),
  GuidelineEntry('GDL-INT-002', 'WHO consolidated guidelines on HIV', 'WHO'),
  GuidelineEntry('GDL-INT-003', 'WHO consolidated guidelines on tuberculosis', 'WHO'),
  GuidelineEntry('GDL-INT-004', 'WHO Pocket Book of Hospital Care for Children', 'WHO'),
  GuidelineEntry('GDL-INT-005', 'The WHO AWaRe antibiotic book', 'WHO'),
  GuidelineEntry('GDL-INT-006', 'CDC Sexually Transmitted Infections Treatment Guidelines', 'CDC'),
  GuidelineEntry('GDL-INT-007', 'NICE NG136: Hypertension in adults', 'NICE'),
  GuidelineEntry('GDL-INT-008', 'IDSA practice guidelines', 'IDSA'),
];

/// How Medivo may use a source (matches the licence_status values).
const Map<String, String> licenceLabels = {
  'link_only': 'Summary and official link',
  'open_licence': 'Open licence',
  'granted': 'Permission granted',
  'to_confirm': 'Licence to be confirmed',
  'requested': 'Permission requested',
  'refused': 'Not permitted',
};

/// Only these allow a guideline to be approved and published.
const List<String> publishableLicences = ['link_only', 'open_licence', 'granted'];
