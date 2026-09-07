import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_boom_pdf_ad_core_plugins/flutter_boom_pdf_ad_core_plugins.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  final core = FlutterBoomPdfAdCorePlugins.instance;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return Directory.systemTemp.path;
          }
          return null;
        });
  });

  tearDown(() async {
    await core.dispose();
    core.updateConfigs<Object>(const <Object, List<AdInfoBean>>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test('returns the only adapter cache without auction', () async {
    final admob = _FakeAdapter(
      networkId: 'admob',
      estimatedRevenueMicros: 2500000,
    );
    core.registerAdapter(admob);
    core.updateConfigs<String>(<String, List<AdInfoBean>>{
      'home': <AdInfoBean>[_info('admob')],
    });

    await core.loadPlacement('home', force: true);
    final selected = await core.getCachedEntry('home');

    expect(selected?.ad.networkId, 'admob');
  });

  test('lets TradPlus compare its cache against AdMob revenue', () async {
    final admob = _FakeAdapter(
      networkId: 'admob',
      estimatedRevenueMicros: 2500000,
    );
    final tradplus = _FakeAdapter(networkId: 'tradplus', auctionWinner: true);
    core
      ..registerAdapter(admob)
      ..registerAdapter(tradplus)
      ..updateConfigs<String>(<String, List<AdInfoBean>>{
        'home': <AdInfoBean>[_info('admob'), _info('tradplus')],
      });

    await core.loadPlacement('home', force: true);
    final selected = await core.getCachedEntry('home');

    expect(selected?.ad.networkId, 'tradplus');
    expect(tradplus.lastCompetitorRevenueMicros, 2500000);
  });

  test('reloads only the displayed winner after it is consumed', () async {
    final admob = _FakeAdapter(
      networkId: 'admob',
      estimatedRevenueMicros: 2500000,
    );
    final tradplus = _FakeAdapter(networkId: 'tradplus', auctionWinner: true);
    core
      ..registerAdapter(admob)
      ..registerAdapter(tradplus)
      ..updateConfigs<String>(<String, List<AdInfoBean>>{
        'home': <AdInfoBean>[_info('admob'), _info('tradplus')],
      });

    await core.loadPlacement('home', force: true);
    expect(await core.showCachedAd('home', adPosId: 'test'), isTrue);
    for (var attempt = 0; attempt < 20 && tradplus.loadCount < 2; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    expect(admob.loadCount, 1);
    expect(tradplus.loadCount, 2);
  });
}

AdInfoBean _info(String networkId) => AdInfoBean(
  adId: '$networkId-unit',
  adPlat: networkId,
  adType: 'int',
  userGroup: <int>[0],
);

class _FakeAdapter extends FlutterBoomPdfAdAdapter {
  _FakeAdapter({
    required this.networkId,
    this.estimatedRevenueMicros = 0,
    this.auctionWinner,
  });

  @override
  final String networkId;
  final double estimatedRevenueMicros;
  final bool? auctionWinner;
  double? lastCompetitorRevenueMicros;
  int loadCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  bool supports(AdType adType) => true;

  @override
  Future<AdLoadResult> load(AdLoadRequest request) async {
    loadCount++;
    final ad = networkId == 'tradplus'
        ? _FakeAuctionAd(
            networkId,
            auctionWinner,
            (value) => lastCompetitorRevenueMicros = value,
          )
        : _FakeAd(networkId);
    return AdLoadResult.success(
      ad,
      estimatedRevenueMicros: estimatedRevenueMicros,
    );
  }
}

class _FakeAd implements LoadedNetworkAd {
  _FakeAd(this.networkId);

  @override
  final String networkId;

  @override
  String get adNetwork => networkId;

  @override
  String get adSourceName => networkId;

  @override
  AdType get adType => AdType.interstitial;

  @override
  Stream<AdNetworkEvent> get events => const Stream<AdNetworkEvent>.empty();

  @override
  Object get rawAd => this;

  @override
  bool get supportsWidget => false;

  @override
  Widget? buildWidget() => null;

  @override
  Future<void> dispose() async {}

  @override
  Future<AdShowResult> show({
    OnUserEarnedRewardCallback? onUserEarnedReward,
  }) async => const AdShowResult.success();
}

class _FakeAuctionAd extends _FakeAd implements AdAuctionCandidate {
  _FakeAuctionAd(super.networkId, this.result, this.onCompared);

  final bool? result;
  final void Function(double value) onCompared;

  @override
  Future<bool?> winsAgainst({required double competitorRevenueMicros}) async {
    onCompared(competitorRevenueMicros);
    return result;
  }
}
