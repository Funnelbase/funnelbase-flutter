import 'package:funnelbase_flutter/funnelbase_flutter.dart';
import 'package:flutter/material.dart';

import '../../push/push_simulation.dart';
import '../common/components.dart';
import '../theme.dart';

/// Which kinds of message this person wants, one switch per notification topic.
///
/// The list is the dashboard's, read through `Analytics.topics.fetch` — the app hard-codes none of
/// it, so a topic added under Engagement appears here without a release. A switch sends the choice
/// at once through `Analytics.topics.set`; the SDK queues it and keeps showing it until the server
/// holds it, so the switch never flips back on the next read.
///
/// A topic switched on is still silent while notifications are off, so that is said above the
/// list, with the way to the system's settings — the only place they can be turned back on.
class TopicsScreen extends StatefulWidget {
  const TopicsScreen({super.key});

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  List<TopicChoice>? _topics;
  var _failed = false;
  var _allowed = true;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _load();
    _readAllowed();
    // Back from the system's settings is where the switch may have changed; the SDK re-registers the
    // token on the same return, this only redraws the line.
    _lifecycle = AppLifecycleListener(onResume: _readAllowed);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _readAllowed() async {
    final allowed = await Analytics.push.notificationsEnabled();
    if (mounted) setState(() => _allowed = allowed);
  }

  Future<void> _load() async {
    setState(() {
      _topics = null;
      _failed = false;
    });
    try {
      final topics = await Analytics.topics.fetch();
      if (mounted) setState(() => _topics = topics);
    } on TopicsException {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _set(TopicChoice topic, bool subscribed) {
    Analytics.topics.set(topic.key, subscribed: subscribed);
    setState(() {
      _topics = [
        for (final t in _topics!)
          t.key == topic.key
              ? TopicChoice(key: t.key, name: t.name, description: t.description, subscribed: subscribed, chosen: true)
              : t,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification topics')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (!_allowed) ...[
            SectionCard(children: [
              Text(
                'Notifications from this app are turned off, so none of these will reach you until they '
                'are turned back on.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: TradeColors.down),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: PushSimulation.openNotificationSettings,
                  child: const Text('Open notification settings'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
          ],
          if (_failed)
            SectionCard(children: [
              Text("Couldn't load your notification topics", style: Theme.of(context).textTheme.titleMedium),
              const Hint('Check your connection and try again.'),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _load, child: const Text('Retry'))),
            ])
          else if (_topics == null)
            const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CircularProgressIndicator()))
          else
            SectionCard(children: [
              const SectionHeader('What you hear about'),
              if (_topics!.isEmpty) const Hint('This app has no notification topics yet.', top: 8),
              for (final (index, topic) in _topics!.indexed) ...[
                if (index > 0) const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(topic.name),
                  subtitle: topic.description == null || topic.description!.trim().isEmpty
                      ? null
                      : Text(topic.description!, style: const TextStyle(color: TradeColors.textSecondary)),
                  value: topic.subscribed,
                  onChanged: (value) => _set(topic, value),
                ),
              ],
            ]),
        ],
      ),
    );
  }
}
