import 'package:funnelbase_flutter/funnelbase_flutter.dart';
import 'package:flutter/material.dart';

import '../../analytics/screens.dart';
import '../../app_state.dart';
import '../../identity/user_id.dart';
import '../nav/routes.dart';
import '../theme.dart';

class _IntroPage {
  const _IntroPage(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

const _introPages = [
  _IntroPage(
    Icons.candlestick_chart,
    'Follow the market',
    'Fifty S&P 500 constituents with live-looking prices. Tap any of them for the company detail, '
        'and favourite the ones you want on your dashboard.',
  ),
  _IntroPage(
    Icons.pie_chart,
    'Watch your portfolio',
    "Positions, cash and the day's move in one figure at the top of the dashboard, recalculated from "
        'the same prices the market list shows.',
  ),
  _IntroPage(
    Icons.receipt_long,
    'Track your orders',
    'Pending, filled and cancelled orders with quantity, price and total cost — and a news feed for '
        'the tickers you follow.',
  ),
];

/// The sign-up flow: three intro pages, then the username step.
///
/// One route showing four screens, so the navigator observer cannot see them (`Routes.screenFor`
/// returns null for it) and this reports its own: a page once it has *settled*, never mid-drag —
/// `onPageChanged` fires as a drag crosses the halfway point and would report pages nobody looked
/// at — and the username step when it appears. Coming back from the username step reports the page
/// it returns to, as arriving anywhere does.
class SignUpFlow extends StatefulWidget {
  const SignUpFlow({super.key});

  @override
  State<SignUpFlow> createState() => _SignUpFlowState();
}

class _SignUpFlowState extends State<SignUpFlow> {
  var _page = 0;
  var _onUsernameStep = false;
  int? _reported;
  late PageController _pages = PageController();

  @override
  void initState() {
    super.initState();
    _reportPage(0);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _reportPage(int page) {
    if (_reported == page) return;
    _reported = page;
    Analytics.screen(Screens.signUpIntro(page));
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    final page = _pages.page?.round();
    if (page != null) _reportPage(page);
    return false;
  }

  void _toUsernameStep() {
    setState(() => _onUsernameStep = true);
    _reported = null;
    Analytics.screen(Screens.signUpUsername);
  }

  void _toPager() {
    _pages.dispose();
    _pages = PageController(initialPage: _page);
    setState(() => _onUsernameStep = false);
    _reportPage(_page);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_onUsernameStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toPager();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_onUsernameStep ? 'Create account' : 'Getting started'),
          leading: BackButton(onPressed: () => _onUsernameStep ? _toPager() : Navigator.pop(context)),
        ),
        body: _onUsernameStep ? const _UsernameStep() : _pager(context),
      ),
    );
  }

  Widget _pager(BuildContext context) {
    final last = _page == _introPages.length - 1;
    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollEndNotification>(
            onNotification: _onScrollEnd,
            child: PageView(
              controller: _pages,
              // Only the indicator and the button follow this; analytics waits for the settle.
              onPageChanged: (page) => setState(() => _page = page),
              children: [for (final page in _introPages) _IntroPageContent(page)],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _introPages.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: i == _page ? 24 : 8,
                  decoration: BoxDecoration(
                    color: i == _page ? TradeColors.accent : TradeColors.outline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(onPressed: _toUsernameStep, child: const Text('Skip')),
              FilledButton(
                onPressed: last
                    ? _toUsernameStep
                    : () => _pages.animateToPage(
                          _page + 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                child: Text(last ? 'Continue' : 'Next'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IntroPageContent extends StatelessWidget {
  const _IntroPageContent(this.page);

  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(page.icon, size: 64, color: TradeColors.accent),
          const SizedBox(height: 28),
          Text(page.title, style: text.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            page.body,
            style: text.bodyMedium?.copyWith(color: TradeColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The final step: the username the whole identity hangs off. The derived id is shown live as you
/// type — the determinism made visible, and the value to paste into a query.
class _UsernameStep extends StatefulWidget {
  const _UsernameStep();

  @override
  State<_UsernameStep> createState() => _UsernameStepState();
}

class _UsernameStepState extends State<_UsernameStep> {
  final _username = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  void _submit() {
    AppScope.of(context).signUp(_username.text);
    Navigator.pushNamedAndRemoveUntil(context, Routes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = _username.text;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        Text(
          'Pick a username. No password, no email — the username is all this demo needs.',
          style: text.bodyMedium?.copyWith(color: TradeColors.textSecondary),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _username,
          decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text('Analytics user id', style: text.labelMedium?.copyWith(color: TradeColors.textSecondary)),
        Text(
          name.trim().isEmpty ? '—' : UserId.forUsername(name),
          style: numericStyle.copyWith(color: TradeColors.accent),
        ),
        Text(
          'Derived from the username, so signing in with it again is the same person.',
          style: text.bodySmall?.copyWith(color: TradeColors.textSecondary),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: name.trim().isEmpty ? null : _submit,
          child: const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Create account')),
        ),
      ],
    );
  }
}
