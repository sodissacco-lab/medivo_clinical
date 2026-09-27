import 'package:flutter/material.dart';

import '../data/content_options.dart';
import '../services/account_controller.dart';
import '../theme/medivo_palette.dart';
import '../theme/medivo_text.dart';
import '../version.dart';
import '../widgets/form_message.dart';
import '../widgets/medivo_app_bar.dart';
import '../widgets/medivo_panel.dart';
import 'admin/licences_screen.dart';
import 'admin/users_roles_screen.dart';
import 'auth/sign_in_screen.dart';
import 'auth/sign_up_screen.dart';
import 'differentials/ddx_review_screen.dart';
import 'edit_profile_screen.dart';
import 'interactions/interaction_review_screen.dart';
import 'offline_library_screen.dart';
import 'studio/studio_screen.dart';

/// The "Me" tab: account, profile and cloud connection (blueprint §24).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final account = AccountController.instance;

    return Scaffold(
      appBar: medivoAppBar(context, 'Me'),
      body: ListenableBuilder(
        listenable: account,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      account.isSignedIn
                          ? _SignedInPanel(account: account)
                          : const _SignedOutPanel(),
                      const SizedBox(height: 16),
                      MedivoPanel(
                        title: 'OFFLINE LIBRARY',
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.download_for_offline_outlined),
                            label: const Text('Manage offline library'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const OfflineLibraryScreen()),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _ConnectionPanel(),
                      const SizedBox(height: 24),
                      Text(
                        'Medivo Clinical ${AppVersion.version} · ${AppVersion.phase}',
                        textAlign: TextAlign.center,
                        style: MedivoText.bodySm.copyWith(color: p.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SignedOutPanel extends StatelessWidget {
  const _SignedOutPanel();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MedivoPanel(
      title: 'ACCOUNT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'You can use Medivo without an account. Signing in keeps your profile, '
            'and later your bookmarks, CPD record and subscription, on every device.',
            style: MedivoText.body.copyWith(color: p.ink),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
            ),
            child: const Text('Sign in'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
            ),
            child: const Text('Create account'),
          ),
        ],
      ),
    );
  }
}

class _SignedInPanel extends StatelessWidget {
  const _SignedInPanel({required this.account});

  final AccountController account;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final profile = account.profile;
    final email = account.user?.email ?? '';

    if (profile == null) {
      return MedivoPanel(
        title: 'ACCOUNT',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (account.loadingProfile)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Text('Signed in as $email', style: MedivoText.body.copyWith(color: p.ink)),
              if (account.profileError != null) ...[
                const SizedBox(height: 12),
                FormMessage(message: account.profileError!),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: account.refreshProfile,
                child: const Text('Try again'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(onPressed: account.signOut, child: const Text('Sign out')),
          ],
        ),
      );
    }

    final details = <String>[
      if (profile.profession != null) profile.profession!,
      if (profile.institution != null) profile.institution!,
      profile.country,
    ];

    return MedivoPanel(
      title: 'ACCOUNT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: p.tint,
                foregroundColor: p.brand,
                child: Text(profile.initials, style: MedivoText.heading.copyWith(color: p.brand)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName.isEmpty ? email : profile.fullName,
                      style: MedivoText.heading.copyWith(color: p.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(details.join(' · '),
                        style: MedivoText.bodySm.copyWith(color: p.muted)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.tint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(profile.roleLabel.toUpperCase(),
                          style: MedivoText.label.copyWith(color: p.ink)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(email, style: MedivoText.bodySm.copyWith(color: p.muted)),
          if (profile.registrationNumber != null)
            Text('Registration: ${profile.registrationNumber}',
                style: MedivoText.bodySm.copyWith(color: p.muted)),
          if (profile.specialties.isNotEmpty)
            Text('Interests: ${profile.specialties.join(', ')}',
                style: MedivoText.bodySm.copyWith(color: p.muted)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => EditProfileScreen(profile: profile)),
            ),
          ),
          if (contentStaffRoles.contains(profile.role)) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Content studio'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const StudioScreen()),
              ),
            ),
          ],
          if (profile.isSuperAdmin) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Users and roles'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const UsersRolesScreen()),
              ),
            ),
          ],
          if (contentStaffRoles.contains(profile.role)) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Licence register'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LicencesScreen()),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.compare_arrows),
              label: const Text('Interaction review'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const InteractionReviewScreen()),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.manage_search),
              label: const Text('Differential review'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DdxReviewScreen()),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: p.alert),
            onPressed: account.signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionPanel extends StatefulWidget {
  const _ConnectionPanel();

  @override
  State<_ConnectionPanel> createState() => _ConnectionPanelState();
}

class _ConnectionPanelState extends State<_ConnectionPanel> {
  ConnectionResult? _result;
  bool _checking = false;

  Future<void> _test() async {
    setState(() => _checking = true);
    final result = await AccountController.instance.testConnection();
    if (!mounted) return;
    setState(() {
      _result = result;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final (String status, Color colour, IconData icon) = _checking
        ? ('Checking…', p.muted, Icons.cloud_sync_outlined)
        : switch (_result) {
            null => ('Not tested yet', p.muted, Icons.cloud_outlined),
            ConnectionResult.connected =>
              ('Connected to Medivo cloud', p.brand, Icons.cloud_done_outlined),
            ConnectionResult.setupMissing => (
                'Connected, but the Phase 2 database setup has not been run yet',
                p.alert,
                Icons.construction_outlined
              ),
            ConnectionResult.wrongKey => (
                'Reached Supabase, but the settings in config.dart are wrong',
                p.alert,
                Icons.key_off_outlined
              ),
            ConnectionResult.offline => (
                'Could not reach Medivo cloud. Check your internet connection.',
                p.alert,
                Icons.cloud_off_outlined
              ),
          };

    return MedivoPanel(
      title: 'CLOUD CONNECTION',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: colour),
              const SizedBox(width: 8),
              Expanded(child: Text(status, style: MedivoText.body.copyWith(color: colour))),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _checking ? null : _test,
              child: const Text('Test connection'),
            ),
          ),
        ],
      ),
    );
  }
}