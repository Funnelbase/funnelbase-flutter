import 'package:funnelbase_flutter_platform_interface/funnelbase_flutter_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('with no platform package registered, every call fails loudly', () async {
    final platform = AnalyticsPlatform.instance;
    await expectLater(platform.initialize(const AnalyticsConfig(apiKey: 'k', endpoint: 'http://x')),
        throwsA(isA<MissingPluginException>()));
    await expectLater(platform.track('e', const {}), throwsA(isA<MissingPluginException>()));
    await expectLater(platform.fetchTopics(), throwsA(isA<MissingPluginException>()));
    await expectLater(platform.pushTaps.first, throwsA(isA<MissingPluginException>()));
  });

  test('an implementation that does not extend the interface is refused', () {
    expect(() => AnalyticsPlatform.instance = _Impostor(), throwsA(isA<AssertionError>()));
  });

  test('configs are equal by value, so an unchanged config is recognised at the next launch', () {
    const a = AnalyticsConfig(apiKey: 'k', endpoint: 'http://x', ios: IosOptions(appGroup: 'g'));
    const b = AnalyticsConfig(apiKey: 'k', endpoint: 'http://x', ios: IosOptions(appGroup: 'g'));
    const c = AnalyticsConfig(apiKey: 'k2', endpoint: 'http://x', ios: IosOptions(appGroup: 'g'));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });
}

class _Impostor implements AnalyticsPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
