import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../theme/medivo_palette.dart';
import '../theme/medivo_text.dart';
import '../widgets/medivo_app_bar.dart';

/// The "Me" tab. Accounts arrive in Phase 2; for now it holds the
/// cloud connection check used to confirm Phase 1.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum _Connection { untested, checking, connected, wrongKey, unreachable }

class _ProfileScreenState extends State<ProfileScreen> {
  _Connection _state = _Connection.untested;
  String _detail = '';

  Future<void> _testConnection() async {
    setState(() {
      _state = _Connection.checking;
      _detail = '';
    });

    _Connection result;
    String detail = '';
    try {
      // This table does not exist yet. If Supabase answers "table not found",
      // the app reached the server with a valid key, which is what we want.
      await Supabase.instance.client.from('connection_check').select().limit(1);
      result = _Connection.connected;
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('api key') || msg.contains('jwt') || e.code == '401') {
        result = _Connection.wrongKey;
      } else {
        result = _Connection.connected;
      }
      detail = e.message;
    } catch (e) {
      result = _Connection.unreachable;
      detail = e.toString();
    }

    if (!mounted) return;
    setState(() {
      _state = result;
      _detail = detail;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final (String status, Color colour, IconData icon) = switch (_state) {
      _Connection.untested => ('Not tested yet', p.muted, Icons.cloud_outlined),
      _Connection.checking => ('Checking…', p.muted, Icons.cloud_sync_outlined),
      _Connection.connected => ('Connected to Medivo cloud', p.brand, Icons.cloud_done_outlined),
      _Connection.wrongKey => (
          'Reached Supabase, but the key in config.dart is wrong',
          p.alert,
          Icons.key_off_outlined
        ),
      _Connection.unreachable => (
          'Could not reach Supabase. Check your internet and the URL in config.dart.',
          p.alert,
          Icons.cloud_off_outlined
        ),
    };

    return Scaffold(
      appBar: medivoAppBar(context, 'Me'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Panel(
            title: 'ACCOUNT',
            child: Text(
              'Sign in, your profession and your profile arrive in Phase 2.',
              style: MedivoText.body.copyWith(color: p.ink),
            ),
          ),
          const SizedBox(height: 16),
          _Panel(
            title: 'CLOUD CONNECTION',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: colour),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(status, style: MedivoText.body.copyWith(color: colour)),
                    ),
                  ],
                ),
                if (_detail.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_detail, style: MedivoText.bodySm.copyWith(color: p.muted)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _state == _Connection.checking ? null : _testConnection,
                  child: const Text('Test connection'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Medivo Clinical ${AppConfig.appVersion} · ${AppConfig.buildPhase}',
            textAlign: TextAlign.center,
            style: MedivoText.bodySm.copyWith(color: p.muted),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: MedivoText.label.copyWith(color: p.muted)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
