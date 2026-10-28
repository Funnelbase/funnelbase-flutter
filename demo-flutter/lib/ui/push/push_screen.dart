import 'dart:io';
import 'dart:math';

import 'package:funnelbase_flutter/funnelbase_flutter.dart';
import 'package:flutter/material.dart';

import '../../push/push_simulation.dart';
import '../common/components.dart';
import '../nav/routes.dart';
import '../theme.dart';

/// Push, from the device's side: whether notifications are allowed, which token this install
/// registered, and a way to see a campaign without waiting for one.
///
/// A demo screen, so it shows the machinery rather than hiding it. The simulate buttons hand the
/// native side the same `data` map the backend sends (`PushSimulation`).
class PushScreen extends StatefulWidget {
  const PushScreen({super.key});

  @override
  State<PushScreen> createState() => _PushScreenState();
}

class _PushScreenState extends State<PushScreen> {
  var _allowed = false;
  String? _token;
  final _manualToken = TextEditingController();
  var _simulated = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _manualToken.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final allowed = await Analytics.push.notificationsEnabled();
    final token = await Analytics.push.registeredToken();
    if (!mounted) return;
    setState(() {
      _allowed = allowed;
      _token = token;
    });
  }

  Future<void> _ask() async {
    // The SDK asks and re-registers the token with the answer: the token's status *is* the
    // permission, so it is re-sent rather than assumed.
    await Analytics.push.requestPermission();
    await _refresh();
  }

  Future<void> _register() async {
    final typed = _manualToken.text.trim();
    final value = typed.isEmpty ? 'opaque-${_randomHex(32)}' : typed;
    await Analytics.push.setToken(value, kind: TokenKinds.opaque);
    _manualToken.clear();
    await _refresh();
  }

  Future<void> _simulate(Map<String, String> Function(String) payload) async {
    await PushSimulation.deliver(payload(PushSimulation.deliveryId()));
    setState(() => _simulated += 1);
  }

  @override
  Widget build(BuildContext context) {
    final permissionNote = Platform.isIOS
        ? 'A push needs the person’s permission. The app asks when it chooses, and the SDK registers '
            'the answer with the token.'
        : 'From Android 13 a push needs the person’s permission. The SDK never asks on its own — the '
            'app decides when — and the SDK reads the answer.';
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          SectionCard(children: [
            SectionHeader(
              'Permission',
              action: Pill(_allowed ? 'Allowed' : 'Blocked', color: _allowed ? TradeColors.up : TradeColors.down),
            ),
            Hint(permissionNote),
            if (!_allowed) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _ask, child: const Text('Allow notifications')),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          SectionCard(children: [
            const SectionHeader('Topics'),
            const Hint(
              'Which kinds of message you want, one switch each. The list is the dashboard’s, and a '
              'campaign sent under a topic skips whoever switched it off.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await Navigator.pushNamed(context, Routes.topics);
                  _refresh();
                },
                child: const Text('Choose topics'),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          SectionCard(children: [
            const SectionHeader("This install's token"),
            if (_token == null)
              const Hint(
                'None registered yet. With Firebase configured, or on iOS with notifications allowed, one '
                'is registered at startup; without it, paste any string below and the dashboard can '
                'target this install through a custom gateway.',
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_token!, style: numericStyle, maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualToken,
              decoration: const InputDecoration(
                labelText: 'A token of your own',
                hintText: 'opaque-…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: _register, child: const Text('Register it')),
            ),
          ]),
          const SizedBox(height: 16),
          SectionCard(children: [
            SectionHeader(
              'See a campaign',
              action: _simulated > 0 ? Pill('$_simulated sent', color: TradeColors.accent) : null,
            ),
            Hint(
              Platform.isIOS
                  ? 'The same payload the platform sends, posted as a local notification a few seconds '
                      'from now — background the app to see it. The text, the buttons and the tap are '
                      'real; the image and the receipt need a real push and the service extension.'
                  : 'The same payload the platform sends, handed to the SDK here. Everything after the '
                      'transport is real: the notification, the receipt event, and the tap.',
            ),
            const SizedBox(height: 12),
            _SimulateButton('Basic notification', () => _simulate(PushSimulation.basic)),
            _SimulateButton('With an image and two buttons', () => _simulate(PushSimulation.rich)),
            _SimulateButton('Collapsing: replaces the last one', () => _simulate(PushSimulation.collapsing)),
            StatRow('Image comes from', PushSimulation.imageHost),
            const Hint(
              'Serve an image on the host\'s port 9099 for it to load; without it the notification '
              'still shows, without its picture.',
              top: 8,
            ),
          ]),
        ],
      ),
    );
  }

  static String _randomHex(int length) {
    final random = Random();
    return List.generate(length, (_) => random.nextInt(16).toRadixString(16)).join();
  }
}

class _SimulateButton extends StatelessWidget {
  const _SimulateButton(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: onPressed, child: Text(label))),
      );
}
