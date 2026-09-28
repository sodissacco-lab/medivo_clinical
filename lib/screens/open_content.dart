import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../calculators/calculator_registry.dart';
import '../data/emergency_protocols.dart';
import '../data/guideline_library.dart';
import '../offline/offline_service.dart';
import '../services/calculator_catalog.dart';
import '../theme/medivo_palette.dart';
import 'algorithms/algorithm_screen.dart';
import 'calculators/calculator_screen.dart';
import 'emergency/emergency_protocol_screen.dart';
import 'guidelines/guideline_screen.dart';
import 'reference/topic_screen.dart';

/// Opens any content by its code in the right screen: calculators,
/// emergency protocols and algorithms have their own layouts; everything
/// else opens as a reading topic.
Future<void> openContent(BuildContext context, String code) async {
  final Widget screen;
  if (code.startsWith('CALC-')) {
    final calc = calculatorByCode(code);
    if (calc == null || !CalculatorCatalog.instance.canOpen(code)) {
      _notYet(context);
      return;
    }
    screen = CalculatorScreen(calculator: calc);
  } else if (code.startsWith('EMR-')) {
    screen = EmergencyProtocolScreen(code: code);
  } else if (code.startsWith('ALG-')) {
    screen = AlgorithmScreen(code: code);
  } else if (code.startsWith('GDL-')) {
    screen = GuidelineScreen(code: code);
  } else {
    screen = TopicScreen(code: code);
  }
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}

void _notYet(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('This is still being clinically reviewed.')),
  );
}

/// Content codes written in clinical text, e.g. EMR-004 or CALC-EM-001.
final RegExp contentCodePattern = RegExp(r'\b(?:EMR|ALG|DIS|DRG|LAB|RAD|GDL|CALC)-[A-Z0-9]+(?:-[A-Z0-9]+)*\b');

/// Every distinct content code in [text], in order of first appearance.
List<String> codesIn(String text) {
  final seen = <String>{};
  return [
    for (final m in contentCodePattern.allMatches(text))
      if (RegExp(r'\d$').hasMatch(m.group(0)!) && seen.add(m.group(0)!)) m.group(0)!,
  ];
}

/// Titles of topics looked up by code (from the phone, then online).
class ContentTitles {
  static final Map<String, String> _titles = {};
  static final Set<String> _tried = {};

  static String? of(String code) => _titles[code];

  /// Looks up any codes not yet known. Returns true if something new was found.
  static Future<bool> resolve(Iterable<String> codes) async {
    final missing = codes.where((c) => !_titles.containsKey(c) && _tried.add(c)).toList();
    if (missing.isEmpty) return false;
    var found = false;
    final offline = OfflineService.instance;
    if (offline.supported && offline.ready) {
      for (final code in missing) {
        final item = await offline.itemByCode(code);
        if (item != null) {
          _titles[code] = item.title;
          found = true;
        }
      }
    }
    final still = missing.where((c) => !_titles.containsKey(c)).toList();
    if (still.isEmpty) return found;
    try {
      final rows = await Supabase.instance.client
          .from('content_items')
          .select('code, title')
          .inFilter('code', still)
          .timeout(const Duration(seconds: 10));
      for (final r in rows) {
        _titles[r['code'] as String] = r['title'] as String;
        found = true;
      }
    } catch (_) {
      _tried.removeAll(still); // try again next time
    }
    return found;
  }
}

/// A friendly name for a code, when the app knows it.
String labelFor(String code) {
  final known = ContentTitles.of(code);
  if (known != null) return known;
  if (code.startsWith('CALC-')) return calculatorByCode(code)?.title ?? code;
  for (final g in guidelineLibrary) {
    if (g.code == code) return g.title;
  }
  return protocolEntry(code)?.title ?? code;
}

/// Tappable links to other content, e.g. "Severe malaria" or "GCS".
/// Calculator codes the app does not have are left out.
class ContentLinkChips extends StatefulWidget {
  const ContentLinkChips({super.key, required this.codes, this.exclude});

  final List<String> codes;

  /// Usually the code of the page itself.
  final String? exclude;

  @override
  State<ContentLinkChips> createState() => _ContentLinkChipsState();
}

class _ContentLinkChipsState extends State<ContentLinkChips> {
  @override
  void initState() {
    super.initState();
    ContentTitles.resolve(widget.codes.where((c) => !c.startsWith('CALC-'))).then((found) {
      if (found && mounted) setState(() {});
    });
  }

  List<String> get codes => widget.codes;
  String? get exclude => widget.exclude;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shown = [
      for (final c in codes)
        if (c != exclude && !(c.startsWith('CALC-') && calculatorByCode(c) == null)) c,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final code in shown)
          ActionChip(
            avatar: Icon(_iconFor(code), size: 18, color: code.startsWith('EMR-') ? p.alert : p.brand),
            label: Text(labelFor(code)),
            onPressed: () => openContent(context, code),
          ),
      ],
    );
  }

  static IconData _iconFor(String code) {
    if (code.startsWith('CALC-')) return Icons.calculate_outlined;
    if (code.startsWith('EMR-')) return Icons.emergency;
    if (code.startsWith('ALG-')) return Icons.account_tree_outlined;
    if (code.startsWith('GDL-')) return Icons.menu_book_outlined;
    return Icons.article_outlined;
  }
}