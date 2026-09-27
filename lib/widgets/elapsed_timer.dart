import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/medivo_palette.dart';
import '../theme/medivo_text.dart';

/// A large stopwatch for resuscitation. With [cycleSeconds] (e.g. 120 for
/// CPR) it also counts down to the next rhythm check.
class ElapsedTimer extends StatefulWidget {
  const ElapsedTimer({super.key, this.cycleSeconds});

  final int? cycleSeconds;

  @override
  State<ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<ElapsedTimer> {
  final Stopwatch _watch = Stopwatch();
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    _watch.start();
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    setState(() {});
  }

  void _stop() {
    _watch.stop();
    setState(() {});
  }

  void _reset() {
    _watch
      ..stop()
      ..reset();
    _ticker?.cancel();
    _ticker = null;
    setState(() {});
  }

  static String _mmss(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final seconds = _watch.elapsed.inSeconds;
    final running = _watch.isRunning;
    final cycle = widget.cycleSeconds;
    final nextCheck = cycle == null || seconds == 0 ? null : cycle - (seconds % cycle);
    final checkDue = cycle != null && seconds > 0 && seconds % cycle < 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: checkDue ? p.alert.withValues(alpha: 0.15) : p.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: running ? p.alert : p.line),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: running ? p.alert : p.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_mmss(seconds), style: MedivoText.value.copyWith(color: p.ink, fontSize: 24)),
                if (checkDue)
                  Text('Rhythm and pulse check now',
                      style: MedivoText.bodySm.copyWith(color: p.alert, fontWeight: FontWeight.w700))
                else if (nextCheck != null)
                  Text('Next check in ${_mmss(nextCheck)} · cycle ${seconds ~/ cycle! + 1}',
                      style: MedivoText.bodySm.copyWith(color: p.muted)),
              ],
            ),
          ),
          if (!running)
            FilledButton(
              onPressed: _start,
              style: FilledButton.styleFrom(backgroundColor: p.alert, minimumSize: const Size(88, 44)),
              child: Text(seconds == 0 ? 'Start' : 'Resume'),
            )
          else
            OutlinedButton(
              onPressed: _stop,
              style: OutlinedButton.styleFrom(minimumSize: const Size(80, 44)),
              child: const Text('Pause'),
            ),
          if (seconds > 0 && !running) ...[
            const SizedBox(width: 6),
            IconButton(tooltip: 'Reset', onPressed: _reset, icon: const Icon(Icons.restart_alt)),
          ],
        ],
      ),
    );
  }
}
