import 'package:funnelbase_flutter_ios/funnelbase_flutter_ios.dart';
import 'package:funnelbase_flutter_ios/src/messages.g.dart';
import 'package:funnelbase_flutter_platform_interface/funnelbase_flutter_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what reaches the channel instead of sending it.
class FakeHost extends AnalyticsHostApi {
  final calls = <String>[];
  IosConfigMessage? config;
  Object? topicsError;
  List<TopicChoiceMessage> topics = [];

  @override
  Future<void> initialize(IosConfigMessage config) async {
    calls.add('initialize');
    this.config = config;
  }

  @override
  Future<void> pushTapsReady() async => calls.add('pushTapsReady');

  @override
  Future<void> track(String eventName, Map<String, Object> properties) async => calls.add('track $eventName $properties');

  @override
  Future<List<TopicChoiceMessage>> fetchTopics() async {
    if (topicsError != null) throw topicsError!;
    return topics;
  }
}

PushTapMessage tapMessage(String deliveryId, {String? actionId}) => PushTapMessage(
      payload: PushPayloadMessage(
        deliveryId: deliveryId,
        runId: 'run-1',
        title: 'Title',
        body: 'Body',
        deepLink: 'trade://instrument/AAPL',
        buttons: [PushButtonMessage(id: 'buy', title: 'Buy', deepLink: 'trade://orders')],
        data: {'k': 'v'},
      ),
      actionId: actionId,
    );

void main() {
  late FakeHost host;
  late AnalyticsFlutterApi? receiver;
  late AnalyticsIOS platform;

  setUp(() {
    host = FakeHost();
    receiver = null;
    platform = AnalyticsIOS(hostApi: host, setUpFlutterApi: (api) => receiver = api);
  });

  test('the config travels flat, the iOS options with it', () async {
    await platform.initialize(const AnalyticsConfig(
      apiKey: 'ana_ios_key',
      endpoint: 'http://localhost:8080',
      flushIntervalSeconds: 10,
      flushBatchSize: 5,
      maxQueuedEvents: 50,
      sessionTimeoutMinutes: 12.5,
      trackApplicationLifecycle: false,
      debugLogging: true,
      ios: IosOptions(appGroup: 'group.example', registerApnsToken: true),
    ));

    final config = host.config!;
    expect(config.apiKey, 'ana_ios_key');
    expect(config.endpoint, 'http://localhost:8080');
    expect(config.flushIntervalSeconds, 10);
    expect(config.flushBatchSize, 5);
    expect(config.maxQueuedEvents, 50);
    expect(config.sessionTimeoutMinutes, 12.5);
    expect(config.trackApplicationLifecycle, isFalse);
    expect(config.debugLogging, isTrue);
    expect(config.appGroup, 'group.example');
    expect(config.registerApnsToken, isTrue);
  });

  test('initialize opens the channel for taps once, before starting the SDK', () async {
    const config = AnalyticsConfig(apiKey: 'k', endpoint: 'http://x');
    await platform.initialize(config);
    platform.pushTaps;
    await platform.initialize(config);

    expect(host.calls.where((c) => c == 'pushTapsReady'), hasLength(1));
    expect(host.calls.first, 'pushTapsReady');
    expect(receiver, isNotNull);
  });

  test('a tap before anyone listens is held for the first listener', () async {
    final stream = platform.pushTaps;
    receiver!.onPushTapped(tapMessage('d-1'));
    receiver!.onPushTapped(tapMessage('d-2', actionId: 'buy'));

    final taps = <PushTap>[];
    stream.listen(taps.add);
    await pumpEventQueue();

    expect(taps.map((t) => t.payload.deliveryId), ['d-1', 'd-2']);
    expect(taps.last.actionId, 'buy');
    expect(taps.last.link, 'trade://orders', reason: "a button's own link wins over the message's");
    expect(taps.first.link, 'trade://instrument/AAPL');

    receiver!.onPushTapped(tapMessage('d-3'));
    await pumpEventQueue();
    expect(taps.map((t) => t.payload.deliveryId), ['d-1', 'd-2', 'd-3']);
  });

  test("the payload comes through whole", () {
    final tap = pushTap(tapMessage('d-1', actionId: 'buy'));
    expect(
      tap,
      const PushTap(
        payload: PushPayload(
          deliveryId: 'd-1',
          runId: 'run-1',
          title: 'Title',
          body: 'Body',
          deepLink: 'trade://instrument/AAPL',
          buttons: [PushButton(id: 'buy', title: 'Buy', deepLink: 'trade://orders')],
          data: {'k': 'v'},
        ),
        actionId: 'buy',
      ),
    );
  });

  test('topics come back with their description', () async {
    host.topics = [
      TopicChoiceMessage(key: 'promotions', name: 'Promotions', topicDescription: 'Offers', subscribed: true, chosen: false),
    ];
    expect(await platform.fetchTopics(), [
      const TopicChoice(key: 'promotions', name: 'Promotions', description: 'Offers', subscribed: true, chosen: false),
    ]);
  });

  group('a topics failure is one of the four cases', () {
    Future<Object?> failWith(PlatformException error) async {
      host.topicsError = error;
      try {
        await platform.fetchTopics();
      } catch (e) {
        return e;
      }
      return null;
    }

    test('http keeps its status', () async {
      final error = await failWith(PlatformException(code: 'http', message: 'HTTP 503', details: 503));
      expect(error, isA<TopicsHttpException>().having((e) => e.status, 'status', 503));
    });

    test('network', () async {
      expect(await failWith(PlatformException(code: 'network', message: 'offline')), isA<TopicsNetworkException>());
    });

    test('malformed', () async {
      expect(await failWith(PlatformException(code: 'malformed')), isA<TopicsMalformedException>());
    });

    test('not initialized', () async {
      expect(await failWith(PlatformException(code: 'not_initialized')), isA<TopicsNotInitializedException>());
    });
  });

  test('registerWith makes this the platform', () {
    AnalyticsIOS.registerWith();
    expect(AnalyticsPlatform.instance, isA<AnalyticsIOS>());
  });
}
