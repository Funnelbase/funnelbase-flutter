import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../nav/routes.dart';
import '../theme.dart';

/// Sign-in. Any username and any password are accepted — there is no auth backend, by design.
///
/// The username is not decoration: it is hashed into the `user_id` every event afterwards carries,
/// so signing in as the same name twice is the same person. The "Pro plan" switch stands in for
/// billing: a pro account's `$identify` carries the day its plan renews (`AppState.signIn`).
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  var _pro = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    AppScope.of(context).signIn(_username.text, pro: _pro);
    // Onboarding is finished: cleared, so back from the dashboard does not return to a login form.
    Navigator.pushNamedAndRemoveUntil(context, Routes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          Text(
            'Welcome back. Any credentials work — this demo has no authentication server.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: TradeColors.textSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            obscureText: true,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pro plan'),
            value: _pro,
            onChanged: (value) => setState(() => _pro = value),
          ),
          const SizedBox(height: 20),
          FilledButton(
            // The password is genuinely unchecked, but an empty username would hash to a shared id
            // for everyone who left the field blank.
            onPressed: _username.text.trim().isEmpty ? null : _submit,
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Sign in')),
          ),
        ],
      ),
    );
  }
}
