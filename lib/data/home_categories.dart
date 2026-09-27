import 'package:flutter/material.dart';

/// A card on the Home dashboard (blueprint §5).
class HomeCategory {
  const HomeCategory({
    required this.title,
    required this.icon,
    required this.phase,
    required this.summary,
    this.emergency = false,
    this.contentType,
  });

  final String title;
  final IconData icon;

  /// Build phase in which this module arrives.
  final int phase;
  final String summary;

  /// Emergency uses the reserved alert colour.
  final bool emergency;

  /// When set, the card opens that reference list (built modules).
  final String? contentType;
}

const List<HomeCategory> homeCategories = [
  HomeCategory(
    title: 'Diseases',
    icon: Icons.local_hospital_outlined,
    phase: 5,
    summary: 'Every condition on one standard template: overview, clinical features, diagnosis, management, referral and references.',
    contentType: 'disease',
  ),
  HomeCategory(
    title: 'Drugs',
    icon: Icons.medication_outlined,
    phase: 5,
    summary: 'Indications, adult and paediatric dosing, pregnancy, renal and hepatic adjustment, adverse effects and monitoring.',
    contentType: 'drug',
  ),
  HomeCategory(
    title: 'Guidelines',
    icon: Icons.menu_book_outlined,
    phase: 9,
    summary: 'Uganda national guidelines first, then other approved sources, once licensing is confirmed.',
    contentType: 'guideline',
  ),
  HomeCategory(
    title: 'Calculators',
    icon: Icons.calculate_outlined,
    phase: 7,
    summary: 'BMI, eGFR, GCS, NEWS2, paediatric fluids, EDD and more, calculated by tested code, never by AI.',
    contentType: 'calculator',
  ),
  HomeCategory(
    title: 'Emergency',
    icon: Icons.emergency,
    phase: 8,
    summary: 'Fast, step-by-step protocols for cardiac arrest, anaphylaxis, severe malaria, sepsis and other emergencies.',
    emergency: true,
    contentType: 'emergency',
  ),
  HomeCategory(
    title: 'Interactions',
    icon: Icons.compare_arrows,
    phase: 10,
    summary: 'Check two or more drugs for interactions, with mechanism, consequence and clinical action.',
    contentType: 'interaction',
  ),
  HomeCategory(
    title: 'Laboratory',
    icon: Icons.science_outlined,
    phase: 5,
    summary: 'Reference ranges by age and sex, causes of high and low results, and SI or conventional units.',
    contentType: 'lab_test',
  ),
  HomeCategory(
    title: 'Radiology',
    icon: Icons.document_scanner_outlined,
    phase: 5,
    summary: 'Indications, preparation, normal and abnormal findings, and red flags for each investigation.',
    contentType: 'radiology',
  ),
  HomeCategory(
    title: 'Algorithms',
    icon: Icons.account_tree_outlined,
    phase: 8,
    summary: 'Symptom pathways: fever, cough, chest pain, headache and more, red flags first.',
    contentType: 'algorithm',
  ),
  HomeCategory(
    title: 'Differentials',
    icon: Icons.manage_search,
    phase: 11,
    summary: 'Enter symptoms and signs; see conditions to consider, dangerous ones first, each linked to its page.',
    contentType: 'ddx',
  ),
];