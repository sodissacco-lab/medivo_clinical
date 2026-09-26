import 'package:flutter/material.dart';

/// A card on the Home dashboard (blueprint §5).
class HomeCategory {
  const HomeCategory({
    required this.title,
    required this.icon,
    required this.phase,
    required this.summary,
    this.emergency = false,
  });

  final String title;
  final IconData icon;

  /// Build phase in which this module arrives.
  final int phase;
  final String summary;

  /// Emergency uses the reserved alert colour.
  final bool emergency;
}

const List<HomeCategory> homeCategories = [
  HomeCategory(
    title: 'Diseases',
    icon: Icons.local_hospital_outlined,
    phase: 5,
    summary: 'Every condition on one standard template: overview, clinical features, diagnosis, management, referral and references.',
  ),
  HomeCategory(
    title: 'Drugs',
    icon: Icons.medication_outlined,
    phase: 5,
    summary: 'Indications, adult and paediatric dosing, pregnancy, renal and hepatic adjustment, adverse effects and monitoring.',
  ),
  HomeCategory(
    title: 'Guidelines',
    icon: Icons.menu_book_outlined,
    phase: 9,
    summary: 'Uganda national guidelines first, then other approved sources, once licensing is confirmed.',
  ),
  HomeCategory(
    title: 'Calculators',
    icon: Icons.calculate_outlined,
    phase: 7,
    summary: 'BMI, eGFR, GCS, NEWS2, paediatric fluids, EDD and more, calculated by tested code, never by AI.',
  ),
  HomeCategory(
    title: 'Emergency',
    icon: Icons.emergency,
    phase: 8,
    summary: 'Fast, step-by-step protocols for cardiac arrest, anaphylaxis, severe malaria, sepsis and other emergencies.',
    emergency: true,
  ),
  HomeCategory(
    title: 'Interactions',
    icon: Icons.compare_arrows,
    phase: 10,
    summary: 'Check two or more drugs for interactions, with mechanism, consequence and clinical action.',
  ),
  HomeCategory(
    title: 'Laboratory',
    icon: Icons.science_outlined,
    phase: 5,
    summary: 'Reference ranges by age and sex, causes of high and low results, and SI or conventional units.',
  ),
  HomeCategory(
    title: 'Radiology',
    icon: Icons.document_scanner_outlined,
    phase: 5,
    summary: 'Indications, preparation, normal and abnormal findings, and red flags for each investigation.',
  ),
];
