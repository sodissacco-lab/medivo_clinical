import 'package:flutter/material.dart';

import '../data/account_options.dart';
import '../services/account_controller.dart';
import '../services/validators.dart';
import '../theme/medivo_palette.dart';
import '../theme/medivo_text.dart';
import '../widgets/form_message.dart';
import '../widgets/medivo_app_bar.dart';

/// Blueprint §24: name, profession, country, registration number,
/// institution, specialties. The role is shown but cannot be edited.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _country;
  late final TextEditingController _registration;
  late final TextEditingController _institution;
  late final TextEditingController _specialties;
  String? _profession;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p.fullName);
    _country = TextEditingController(text: p.country);
    _registration = TextEditingController(text: p.registrationNumber ?? '');
    _institution = TextEditingController(text: p.institution ?? '');
    _specialties = TextEditingController(text: p.specialties.join(', '));
    _profession = professions.contains(p.profession) ? p.profession : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    _registration.dispose();
    _institution.dispose();
    _specialties.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final specialties = _specialties.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final error = await AccountController.instance.updateProfile(
      fullName: _name.text,
      country: _country.text,
      profession: _profession,
      registrationNumber: _registration.text,
      institution: _institution.text,
      specialties: specialties,
    );
    if (!mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: medivoAppBar(context, 'Edit profile'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Full name'),
                        validator: (v) => Validators.notEmpty(v, 'full name'),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _profession,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Profession'),
                        items: [
                          for (final profession in professions)
                            DropdownMenuItem(value: profession, child: Text(profession)),
                        ],
                        onChanged: _busy ? null : (value) => setState(() => _profession = value),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _country,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Country'),
                        validator: (v) => Validators.notEmpty(v, 'country'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _registration,
                        decoration: const InputDecoration(
                          labelText: 'Registration number (optional)',
                          helperText: 'Your professional council registration number',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _institution,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Institution (optional)',
                          helperText: 'Hospital, health centre, clinic or school',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _specialties,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Specialties and interests (optional)',
                          helperText: 'Separate with commas, e.g. Paediatrics, HIV care',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.badge_outlined, color: p.muted, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Account role: ${widget.profile.roleLabel}. '
                              'Roles are changed by a Medivo administrator.',
                              style: MedivoText.bodySm.copyWith(color: p.muted),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        FormMessage(message: _error!),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
