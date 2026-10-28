import 'package:flutter/material.dart';

import '../nav/routes.dart';
import '../theme.dart';

/// Reported as `welcome` by the navigator observer, like every pushed screen.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.trending_up, size: 72, color: TradeColors.accent),
              const SizedBox(height: 24),
              Text('Trade Demo', style: text.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Markets, portfolio and orders — a sample app instrumented with the in-house analytics SDK.',
                style: text.bodyMedium?.copyWith(color: TradeColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: () => Navigator.pushNamed(context, Routes.signUp),
                child: const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Create account')),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, Routes.signIn),
                child: const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Sign in')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
