import 'calc_emergency.dart';
import 'calc_engine.dart';
import 'calc_general.dart';
import 'calc_obstetrics.dart';
import 'calc_paediatrics.dart';

/// Every calculator in the app, in the blueprint §12 order.
final List<Calculator> allCalculators = [
  ...generalCalculators,
  ...emergencyCalculators,
  ...paediatricCalculators,
  ...obstetricCalculators,
];

const List<String> calculatorCategories = ['General', 'Emergency', 'Paediatrics', 'Obstetrics'];

Calculator? calculatorByCode(String code) {
  for (final c in allCalculators) {
    if (c.code == code) return c;
  }
  return null;
}
