import 'package:flutter/material.dart';

import '../../data/account_options.dart';
import '../../services/account_controller.dart';
import '../../services/validators.dart';
import '../../theme/medivo_palette.dart';
import '../../theme/medivo_text.dart';
import '../../widgets/form_message.dart';
import '../../widgets/medivo_app_bar.dart';
import 'sign_in_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _country = TextEditingController(text: 'Uganda');
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String _accountType = 'professional';
  String? _profession;
  bool _hidePassword = true;
  bool _acceptedTerms = false;
  bool _busy = false;
  String? _error;

  bool get _needsProfession => _accountType != 'patient';

  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final formValid = _formKey.currentState!.validate();
    if (!_acceptedTerms) {
      setState(() => _error = 'Please confirm the statement about clinical judgement.');
      return;
    }
    if (!formValid) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await AccountController.instance.signUp(
      fullName: _name.text,
      email: _email.text,
      password: _password.text,
      accountType: _accountType,
      country: _country.text,
      profession: _needsProfession ? _profession : null,
    );
    if (!mounted) return;

    if (result.error != null) {
      setState(() {
        _busy = false;
        _error = result.error;
      });
      return;
    }

    if (result.needsConfirmation) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Check your email'),
          content: Text(
            'We sent a confirmation link to ${_email.text.trim()}. '
            'Open it, then come back and sign in.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: medivoAppBar(context, 'Create account'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('I am a', style: MedivoText.label.copyWith(color: p.muted)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in accountTypes.entries)
                            ChoiceChip(
                              label: Text(entry.value),
                              selected: _accountType == entry.key,
                              onSelected: _busy
                                  ? null
                                  : (_) => setState(() {
                                        _accountType = entry.key;
                                        _profession = null;
                                      }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Full name'),
                        validator: (v) => Validators.notEmpty(v, 'full name'),
                      ),
                      if (_needsProfession) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_accountType),
                          initialValue: _profession,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: _accountType == 'student'
                                ? 'What are you studying?'
                                : 'Profession',
                          ),
                          items: [
                            for (final profession in professions)
                              DropdownMenuItem(value: profession, child: Text(profession)),
                          ],
                          onChanged: _busy ? null : (value) => setState(() => _profession = value),
                          validator: (value) => value == null ? 'Choose one' : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _country,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Country'),
                        validator: (v) => Validators.notEmpty(v, 'country'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        obscureText: _hidePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText: 'At least 8 characters, with letters and numbers',
                          suffixIcon: IconButton(
                            tooltip: _hidePassword ? 'Show password' : 'Hide password',
                            icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                        validator: Validators.password,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirm,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(labelText: 'Confirm password'),
                        validator: (v) =>
                            v == _password.text ? null : 'Passwords do not match',
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        value: _acceptedTerms,
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _acceptedTerms = value ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'I understand that Medivo Clinical supports clinical judgement '
                          'and does not replace it.',
                          style: MedivoText.bodySm.copyWith(color: p.ink),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        FormMessage(message: _error!),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : const Text('Create account'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
                                ),
                        child: const Text('Already have an account? Sign in'),
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
