import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/account_options.dart';

/// A signed-in person's profile (blueprint §24).
class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.role,
    this.profession,
    this.country = 'Uganda',
    this.registrationNumber,
    this.institution,
    this.specialties = const [],
  });

  final String id;
  final String fullName;
  final String role;
  final String? profession;
  final String country;
  final String? registrationNumber;
  final String? institution;
  final List<String> specialties;

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first;
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  bool get isSuperAdmin => role == 'super_admin';
  String get roleLabel => roleLabels[role] ?? role;

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      fullName: (map['full_name'] as String?) ?? '',
      role: (map['role'] as String?) ?? 'professional',
      profession: map['profession'] as String?,
      country: (map['country'] as String?) ?? 'Uganda',
      registrationNumber: map['registration_number'] as String?,
      institution: map['institution'] as String?,
      specialties: ((map['specialties'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

/// Result of the cloud connection test on the Me tab.
enum ConnectionResult { connected, setupMissing, wrongKey, offline }

/// Holds the sign-in state and profile for the whole app.
/// Screens listen to it with ListenableBuilder.
class AccountController extends ChangeNotifier {
  AccountController._();

  static final AccountController instance = AccountController._();

  SupabaseClient? _client;
  StreamSubscription<AuthState>? _subscription;

  Profile? profile;
  bool loadingProfile = false;
  String? profileError;

  bool get cloudAvailable => _client != null;
  User? get user => _client?.auth.currentUser;
  bool get isSignedIn => user != null;

  /// Call once at start-up, after Supabase.initialize.
  void start() {
    try {
      _client = Supabase.instance.client;
    } catch (e) {
      debugPrint('Medivo cloud unavailable: $e');
      _client = null;
      return;
    }

    _subscription ??= _client!.auth.onAuthStateChange.listen(
      (state) {
        switch (state.event) {
          case AuthChangeEvent.signedOut:
            profile = null;
            profileError = null;
            notifyListeners();
          case AuthChangeEvent.initialSession ||
                AuthChangeEvent.signedIn ||
                AuthChangeEvent.userUpdated:
            refreshProfile();
          default:
            notifyListeners();
        }
      },
      onError: (Object e) => debugPrint('Auth stream error: $e'),
    );
  }

  Future<void> refreshProfile() async {
    final client = _client;
    final currentUser = client?.auth.currentUser;
    if (client == null || currentUser == null) {
      profile = null;
      notifyListeners();
      return;
    }

    loadingProfile = true;
    notifyListeners();
    try {
      final row = await client
          .from('profiles')
          .select()
          .eq('id', currentUser.id)
          .maybeSingle();
      profile = row == null ? null : Profile.fromMap(row);
      profileError = row == null ? 'Your profile could not be found.' : null;
    } catch (e) {
      // Offline: keep the last profile we had.
      profileError = friendlyError(e);
    }
    loadingProfile = false;
    notifyListeners();
  }

  /// Returns null on success, or a message to show.
  Future<String?> signIn({required String email, required String password}) async {
    final client = _client;
    if (client == null) return _notConfigured;
    try {
      await client.auth.signInWithPassword(email: email.trim(), password: password);
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  Future<({String? error, bool needsConfirmation})> signUp({
    required String fullName,
    required String email,
    required String password,
    required String accountType,
    required String country,
    String? profession,
  }) async {
    final client = _client;
    if (client == null) return (error: _notConfigured, needsConfirmation: false);
    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'account_type': accountType,
          'profession': profession ?? '',
          'country': country.trim(),
        },
      );
      return (error: null, needsConfirmation: response.session == null);
    } catch (e) {
      return (error: friendlyError(e), needsConfirmation: false);
    }
  }

  Future<void> signOut() async {
    try {
      await _client?.auth.signOut();
    } catch (e) {
      debugPrint('Sign-out error: $e');
    }
    profile = null;
    notifyListeners();
  }

  /// Updates the signed-in person's own details. The role cannot be
  /// changed here; the database refuses it.
  Future<String?> updateProfile({
    required String fullName,
    required String country,
    String? profession,
    String? registrationNumber,
    String? institution,
    List<String> specialties = const [],
  }) async {
    final client = _client;
    final currentUser = user;
    if (client == null || currentUser == null) return _notConfigured;
    try {
      await client.from('profiles').update({
        'full_name': fullName.trim(),
        'country': country.trim(),
        'profession': _blankToNull(profession),
        'registration_number': _blankToNull(registrationNumber),
        'institution': _blankToNull(institution),
        'specialties': specialties,
      }).eq('id', currentUser.id);
      await refreshProfile();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  /// Super administrators only: every profile, for role management.
  Future<List<Profile>> listProfiles() async {
    final client = _client;
    if (client == null) throw Exception(_notConfigured);
    final rows = await client.from('profiles').select().order('full_name');
    return rows.map(Profile.fromMap).toList();
  }

  /// Super administrators only. The database checks the permission
  /// and records the change in the audit log.
  Future<String?> setRole({required String userId, required String role}) async {
    final client = _client;
    if (client == null) return _notConfigured;
    try {
      await client.rpc('set_user_role', params: {
        'target_user': userId,
        'new_role': role,
      });
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  Future<ConnectionResult> testConnection() async {
    final client = _client;
    if (client == null) return ConnectionResult.wrongKey;
    try {
      await client.from('app_info').select('value').eq('key', 'app_name').maybeSingle();
      return ConnectionResult.connected;
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('api key') || message.contains('jwt') || e.code == '401') {
        return ConnectionResult.wrongKey;
      }
      if (message.contains('could not find the table')) return ConnectionResult.setupMissing;
      return ConnectionResult.connected;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return ConnectionResult.offline;
    }
  }

  static const String _notConfigured =
      'Medivo cloud is not set up. Check the settings in config.dart.';

  static String? _blankToNull(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

/// Turns technical errors into plain messages (never show raw errors).
String friendlyError(Object error) {
  debugPrint('Account error: $error');
  final text = error.toString().toLowerCase();

  if (text.contains('retryablefetch') ||
      text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('clientexception') ||
      text.contains('network')) {
    return 'No internet connection. Check your connection and try again.';
  }
  if (text.contains('invalid login credentials')) {
    return 'Email or password is incorrect.';
  }
  if (text.contains('email not confirmed')) {
    return 'Please confirm your email first. Check your inbox for the link.';
  }
  if (text.contains('already registered') || text.contains('already been registered')) {
    return 'An account with this email already exists. Try signing in instead.';
  }
  if (text.contains('rate limit') || text.contains('too many')) {
    return 'Too many attempts. Please wait a few minutes and try again.';
  }
  if (text.contains('super administrator')) {
    return 'Only a super administrator can change roles.';
  }
  if (text.contains('own role')) {
    return 'You cannot change your own role.';
  }
  if (text.contains('password')) {
    return 'That password is not accepted. Use at least 8 characters with letters and numbers.';
  }
  return 'Something went wrong. Please try again.';
}
