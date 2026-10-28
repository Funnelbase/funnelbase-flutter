import 'package:funnelbase_flutter_android/funnelbase_flutter_android.dart';
import 'package:funnelbase_flutter_android/src/messages.g.dart';
import 'package:funnelbase_flutter_platform_interface/funnelbase_flutter_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHost implements AnalyticsHostApi {
  final calls = <String>[];
  Object? fetchError;
  List<TopicChoiceMessage> topics = [];

  @override
  Future<void> pushTapsReady() async => calls.add('pushTapsReady');

  @override
  Future<List<TopicChoiceMessage>> fetchTopics() async {
    final error = fetchError;
    if (error != null) throw error;
    return topics;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PushTapMessage _tap(String delivery, {String? actionId}) => PushTapMessage(
      payload: PushPayloadMessage(
        deliveryId: delivery,
        runId: 'run-1',
        title: 'AAPL is up',
        body: '3% today',
        imageUrl: null,
        deepLink: 'trade://instrument/AAPL',
        collapseKey: null,
        buttons: [PushButtonMessage(id: 'buy', title: 'Buy', deepLink: 'trade://orders')],
        data: {'campaign': 'spring'},
      ),
      actionId: actionId,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the config crosses the channel with its Android options flattened in', () {
    final message = AnalyticsAndroid.configMessage(const AnalyticsConfig(
      apiKey: 'ana_and_x',
      endpoint: 'http://10.0.2.2:8080',
      flushBatchSize: 5,
      sessionTimeoutMinutes: 45,
      debugLogging: true,
      android: AndroidOptions(pushChannelId: 'alerts', pushSmallIcon: 'ic_stat_notify'),
    ));

    expect(message.apiKey, 'ana_and_x');
    expect(message.endpoint, 'http://10.0.2.2:8080');
    expect(message.flushIntervalSeconds, 30);
    expect(message.flushBatchSize, 5);
    expect(message.maxQueuedEvents, 1000);
    expect(message.sessionTimeoutMinutes, 45);
    expect(message.trackApplicationLifecycle, isTrue);
    expect(message.debugLogging, isTrue);
    expect(message.pushChannelId, 'alerts');
    expect(message.pushChannelName, 'Notifications');
    expect(message.pushSmallIcon, 'ic_stat_notify');
    expect(message.pushMaxImageBytes, 1000000);
  });

  group('topics', () {
    test('come back as the interface type', () async {
      final host = _FakeHost()
        ..topics = [
          TopicChoiceMessage(key: 'promotions', name: 'Promotions', description: null, subscribed: true, chosen: false),
        ];

      expect(await AnalyticsAndroid(hostApi: host).fetchTopics(), [
        const TopicChoice(key: 'promotions', name: 'Promotions', subscribed: true, chosen: false),
      ]);
    });

    test('a failure is the native reason, as a TopicsException', () async {
      Future<TopicsException> failure(PlatformException error) async {
        final host = _FakeHost()..fetchError = error;
        try {
          await AnalyticsAndroid(hostApi: host).fetchTopics();
        } on TopicsException catch (e) {
          return e;
        }
        fail('expected a TopicsException');
      }

      final http = await failure(PlatformException(code: 'http', message: 'HTTP 503', details: 503));
      expect(http, isA<TopicsHttpException>().having((e) => e.status, 'status', 503));
      expect(await failure(PlatformException(code: 'network', message: 'offline')), isA<TopicsNetworkException>());
      expect(await failure(PlatformException(code: 'malformed', message: 'bad')), isA<TopicsMalformedException>());
      expect(await failure(PlatformException(code: 'not_initialized')), isA<TopicsNotInitializedException>());
    });
  });

  group('taps', () {
    test('Kotlin is told to deliver once, at first use', () {
      final host = _FakeHost();
      final android = AnalyticsAndroid(hostApi: host);

      android.pushTaps;
      android.pushTaps;

      expect(host.calls, ['pushTapsReady']);
    });

    test('a tap before anything listens is held for the first listener', () async {
      final android = AnalyticsAndroid(hostApi: _FakeHost());
      final taps = android.pushTaps;

      android.tapReceiver.onPushTapped(_tap('d-1', actionId: 'buy'));
      android.tapReceiver.onPushTapped(_tap('d-2'));

      final received = <PushTap>[];
      final subscription = taps.listen(received.add);
      await pumpEventQueue();

      expect(received.map((t) => t.payload.deliveryId), ['d-1', 'd-2']);
      expect(received.first.actionId, 'buy');
      expect(received.first.link, 'trade://orders', reason: "the button's own link wins");
      expect(received.last.link, 'trade://instrument/AAPL');
      expect(received.first.payload.data, {'campaign': 'spring'});

      android.tapReceiver.onPushTapped(_tap('d-3'));
      await pumpEventQueue();
      expect(received.map((t) => t.payload.deliveryId), ['d-1', 'd-2', 'd-3']);
      await subscription.cancel();
    });
  });
}
