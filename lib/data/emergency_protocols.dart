import 'package:flutter/material.dart';

/// A fixed entry on the Emergency or Algorithms screen (blueprint §16, §17).
/// The clinical text itself comes from the content item with this code.
class ProtocolEntry {
  const ProtocolEntry(this.code, this.title, this.icon);

  final String code;
  final String title;
  final IconData icon;
}

/// Blueprint §16, in the blueprint's order.
const List<ProtocolEntry> emergencyProtocols = [
  ProtocolEntry('EMR-001', 'Cardiac arrest', Icons.heart_broken),
  ProtocolEntry('EMR-002', 'Anaphylaxis', Icons.warning_amber),
  ProtocolEntry('EMR-003', 'Severe asthma', Icons.air),
  ProtocolEntry('EMR-004', 'Severe malaria', Icons.bug_report),
  ProtocolEntry('EMR-005', 'Sepsis', Icons.coronavirus),
  ProtocolEntry('EMR-006', 'Shock', Icons.water_drop),
  ProtocolEntry('EMR-007', 'Status epilepticus', Icons.bolt),
  ProtocolEntry('EMR-008', 'Hypoglycaemia', Icons.cookie),
  ProtocolEntry('EMR-009', 'DKA', Icons.bloodtype),
  ProtocolEntry('EMR-010', 'Severe trauma', Icons.personal_injury),
  ProtocolEntry('EMR-011', 'Burns', Icons.local_fire_department),
  ProtocolEntry('EMR-012', 'Poisoning', Icons.dangerous),
  ProtocolEntry('EMR-013', 'Acute stroke', Icons.psychology),
  ProtocolEntry('EMR-014', 'Acute coronary syndrome', Icons.favorite),
  ProtocolEntry('EMR-015', 'Respiratory failure', Icons.masks),
  ProtocolEntry('EMR-016', 'Obstetric emergencies', Icons.pregnant_woman),
  ProtocolEntry('EMR-017', 'Paediatric emergencies', Icons.child_care),
];

/// Blueprint §17 examples.
const List<ProtocolEntry> clinicalAlgorithms = [
  ProtocolEntry('ALG-001', 'Fever', Icons.thermostat),
  ProtocolEntry('ALG-002', 'Cough', Icons.sick_outlined),
  ProtocolEntry('ALG-003', 'Chest pain', Icons.monitor_heart_outlined),
  ProtocolEntry('ALG-004', 'Abdominal pain', Icons.accessibility_new),
  ProtocolEntry('ALG-005', 'Headache', Icons.psychology_outlined),
  ProtocolEntry('ALG-006', 'Diarrhoea', Icons.water_drop_outlined),
  ProtocolEntry('ALG-007', 'Anaemia', Icons.bloodtype_outlined),
  ProtocolEntry('ALG-008', 'Hypertension', Icons.speed),
  ProtocolEntry('ALG-009', 'Diabetes', Icons.science_outlined),
  ProtocolEntry('ALG-010', 'Shortness of breath', Icons.air),
];

ProtocolEntry? protocolEntry(String code) {
  for (final e in [...emergencyProtocols, ...clinicalAlgorithms]) {
    if (e.code == code) return e;
  }
  return null;
}
