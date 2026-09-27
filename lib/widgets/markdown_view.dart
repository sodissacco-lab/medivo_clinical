import 'package:flutter/material.dart';

import '../theme/medivo_palette.dart';
import '../theme/medivo_text.dart';

/// Shows clinical content written with simple formatting marks
/// (## headings, **bold**, *italic*, - bullets, 1. numbers, > notes,
/// | tables |) as clean, readable text. No marks are shown to the reader.
class MarkdownView extends StatelessWidget {
  const MarkdownView({super.key, required this.text, this.hideColumnsContaining});

  final String text;

  /// Table columns whose header contains this text are hidden, e.g.
  /// '(Conventional)' when a reader has chosen SI units.
  final String? hideColumnsContaining;

  @override
  Widget build(BuildContext context) {
    final blocks = _parse(text, hideColumnsContaining);
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final block in blocks) block.build(context)],
      ),
    );
  }

  static List<_Block> _parse(String source, String? hide) {
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    final blocks = <_Block>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isNotEmpty) {
        blocks.add(_Paragraph(paragraph.join(' ')));
        paragraph.clear();
      }
    }

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        flushParagraph();
        i++;
        continue;
      }

      final heading = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        flushParagraph();
        blocks.add(_Heading(heading.group(1)!.length, heading.group(2)!));
        i++;
        continue;
      }

      if (trimmed.startsWith('|')) {
        flushParagraph();
        final rows = <List<String>>[];
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          final row = lines[i].trim();
          final isDivider = RegExp(r'^\|?[\s:\-|]+\|?$').hasMatch(row) && row.contains('-');
          if (!isDivider) {
            var cells = row.split('|');
            if (cells.isNotEmpty && cells.first.trim().isEmpty) cells = cells.sublist(1);
            if (cells.isNotEmpty && cells.last.trim().isEmpty) {
              cells = cells.sublist(0, cells.length - 1);
            }
            rows.add(cells.map((c) => c.trim()).toList());
          }
          i++;
        }
        if (rows.isNotEmpty) blocks.add(_TableBlock(rows, hide));
        continue;
      }

      if (trimmed.startsWith('>')) {
        flushParagraph();
        final quote = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          quote.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        blocks.add(_Note(quote.join(' ')));
        continue;
      }

      final bullet = RegExp(r'^[-*•]\s+(.*)$').firstMatch(trimmed);
      final number = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(trimmed);
      if (bullet != null || number != null) {
        flushParagraph();
        final indent = line.length - line.trimLeft().length;
        blocks.add(_ListItem(
          marker: bullet != null ? '•' : '${number!.group(1)}.',
          text: bullet != null ? bullet.group(1)! : number!.group(2)!,
          level: indent >= 2 ? 1 : 0,
        ));
        i++;
        continue;
      }

      paragraph.add(trimmed);
      i++;
    }
    flushParagraph();
    return blocks;
  }
}

/// Turns **bold** and *italic* into styled text, without showing the marks.
List<InlineSpan> _inline(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|(?<![A-Za-z0-9])_(.+?)_(?![A-Za-z0-9])');
  var last = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(text: text.substring(last, match.start), style: base));
    }
    if (match.group(1) != null) {
      spans.add(TextSpan(
          text: match.group(1), style: base.copyWith(fontWeight: FontWeight.w700)));
    } else {
      spans.add(TextSpan(
          text: match.group(2) ?? match.group(3),
          style: base.copyWith(fontStyle: FontStyle.italic)));
    }
    last = match.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: base));
  return spans;
}

abstract class _Block {
  Widget build(BuildContext context);
}

class _Heading implements _Block {
  _Heading(this.level, this.text);

  final int level;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = switch (level) {
      1 => MedivoText.title.copyWith(color: p.ink),
      2 => MedivoText.heading.copyWith(color: p.brand),
      _ => MedivoText.body.copyWith(color: p.ink, fontWeight: FontWeight.w700),
    };
    return Padding(
      padding: EdgeInsets.only(top: level <= 2 ? 20 : 12, bottom: 6),
      child: Text.rich(TextSpan(children: _inline(text, style))),
    );
  }
}

class _Paragraph implements _Block {
  _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(TextSpan(children: _inline(text, MedivoText.body.copyWith(color: p.ink)))),
    );
  }
}

class _ListItem implements _Block {
  _ListItem({required this.marker, required this.text, required this.level});

  final String marker;
  final String text;
  final int level;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = MedivoText.body.copyWith(color: p.ink);
    return Padding(
      padding: EdgeInsets.only(left: 4.0 + level * 20, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(marker, style: style.copyWith(color: p.brand, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text.rich(TextSpan(children: _inline(text, style)))),
        ],
      ),
    );
  }
}

class _Note implements _Block {
  _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(TextSpan(
          children: _inline(text, MedivoText.bodySm.copyWith(color: p.ink, fontWeight: FontWeight.w600)))),
    );
  }
}

class _TableBlock implements _Block {
  _TableBlock(List<List<String>> allRows, String? hide) : rows = _dropColumns(allRows, hide);

  final List<List<String>> rows;

  static List<List<String>> _dropColumns(List<List<String>> rows, String? hide) {
    if (hide == null || rows.isEmpty) return rows;
    final header = rows.first;
    final keep = [
      for (var c = 0; c < header.length; c++)
        if (!header[c].toLowerCase().contains(hide.toLowerCase())) c,
    ];
    if (keep.length == header.length) return rows;
    return [
      for (final row in rows) [for (final c in keep) c < row.length ? row[c] : ''],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final columns = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    TableRow row(List<String> cells, {bool header = false}) {
      final base = header
          ? MedivoText.bodySm.copyWith(color: p.ink, fontWeight: FontWeight.w700)
          : MedivoText.bodySm.copyWith(color: p.ink);
      return TableRow(
        decoration: header ? BoxDecoration(color: p.tint) : null,
        children: [
          for (var c = 0; c < columns; c++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text.rich(TextSpan(
                  children: _inline(c < cells.length ? cells[c] : '', base))),
            ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: p.line, borderRadius: BorderRadius.circular(8)),
          children: [
            row(rows.first, header: true),
            for (final r in rows.skip(1)) row(r),
          ],
        ),
      ),
    );
  }
}


/// A top-level section of a topic, split at each "## " heading.
class MarkdownSection {
  const MarkdownSection({required this.title, required this.text});

  /// Null for any text before the first heading.
  final String? title;

  /// The section's text, including its own heading line.
  final String text;
}

List<MarkdownSection> splitSections(String source) {
  final sections = <MarkdownSection>[];
  String? title;
  final buffer = StringBuffer();

  void flush() {
    final text = buffer.toString().trim();
    if (text.isNotEmpty) sections.add(MarkdownSection(title: title, text: text));
    buffer.clear();
  }

  for (final line in source.replaceAll('\r\n', '\n').split('\n')) {
    final match = RegExp(r'^##\s+(.*)$').firstMatch(line.trim());
    if (match != null && !line.trim().startsWith('###')) {
      flush();
      title = match.group(1)!.trim();
    }
    buffer.writeln(line);
  }
  flush();
  return sections;
}