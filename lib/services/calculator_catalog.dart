import 'package:flutter/foundation.dart';

import '../calculators/calc_engine.dart';
import '../calculators/calculator_registry.dart';
import '../data/content_options.dart';
import 'account_controller.dart';
import 'reference_repository.dart';

/// Decides which calculators a person can open.
///
/// The formulas are built into the app, but each calculator also has a
/// content item (e.g. CALC-GEN-001) holding its specification, bands and
/// references. A calculator is shown to users only once that item has been
/// clinically reviewed and PUBLISHED (blueprint §30). Content staff can
/// preview unpublished calculators so they can check them.
class CalculatorCatalog extends ChangeNotifier {
  CalculatorCatalog._();
  static final CalculatorCatalog instance = CalculatorCatalog._();

  Set<String> _published = {};
  bool loaded = false;
  bool fromDevice = false;

  Future<void> refresh() async {
    try {
      final result = await ReferenceRepository.list('calculator');
      _published = {for (final t in result.topics) t.code};
      fromDevice = result.fromDevice;
    } catch (e) {
      debugPrint('Calculator list not refreshed: $e');
    }
    loaded = true;
    notifyListeners();
  }

  bool get isStaff => contentStaffRoles.contains(AccountController.instance.profile?.role);

  bool isPublished(String code) => _published.contains(code);

  bool canOpen(String code) => isPublished(code) || isStaff;

  List<Calculator> get visible => allCalculators.where((c) => canOpen(c.code)).toList();
}
