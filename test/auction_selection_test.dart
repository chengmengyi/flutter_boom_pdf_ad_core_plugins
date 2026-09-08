import 'dart:async';
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
    core.setListener(null);
    core.updateAdRequestTimeoutSeconds(0);
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

  test('does not block on a deferred SDK completion callback', () async {
    final sdkCompleted = Completer<void>();
    final listener = _InitializationListener();
    core
      ..setListener(listener)
      ..registerAdapter(
        _FakeAdapter(
          networkId: 'admob',
          initializationCompleted: sdkCompleted.future,
        ),
      );

    await core.initializeNetwork('admob');

    expect(listener.networks, isEmpty);
    expect(listener.admobInitialized, 0);

    sdkCompleted.complete();
    await Future<void>.delayed(Duration.zero);

    expect(listener.networks, <String>['admob']);
    expect(listener.admobInitialized, 1);
  });

  test('waits for a normal adapter before reporting initialization', () async {
    final sdkCompleted = Completer<void>();
    final listener = _InitializationListener();
    core
      ..setListener(listener)
      ..registerAdapter(
        _FakeAdapter(
          networkId: 'tradplus',
          initializeFuture: sdkCompleted.future,
        ),
      );

    var returned = false;
    final initialization = core.initializeNetwork('tradplus').then((_) {
      returned = true;
    });
    await Future<void>.delayed(Duration.zero);

    expect(returned, isFalse);
    expect(listener.networks, isEmpty);

    sdkCompleted.complete();
    await initialization;

    expect(listener.networks, <String>['tradplus']);
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

  test(
    'compares all cached ads and resolves multiple TradPlus winners',
    () async {
      final listener = _BidListener();
      final admob = _MultiFakeAdapter(
        networkId: 'admob',
        revenues: <String, double>{'admob-1': 2000000, 'admob-2': 4000000},
      );
      final tradplus = _MultiFakeAdapter(
        networkId: 'tradplus',
        auctionResults: <String, bool>{'tp-1': true, 'tp-2': true},
        revenues: <String, double>{'tp-1': 5000000, 'tp-2': 7000000},
      );
      core
        ..setListener(listener)
        ..updateAdRequestTimeoutSeconds(1)
        ..registerAdapter(admob)
        ..registerAdapter(tradplus)
        ..updateConfigs<String>(<String, List<AdInfoBean>>{
          'home': <AdInfoBean>[
            _infoWithId('admob', 'admob-1'),
            _infoWithId('admob', 'admob-2'),
            _infoWithId('tradplus', 'tp-1'),
            _infoWithId('tradplus', 'tp-2'),
          ],
        });

      await core.loadPlacement('home', force: true);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final selected = await core.getCachedEntry('home');

      expect(selected?.info.adId, 'tp-2');
      expect(tradplus.competitorPrices, <double>[4000000, 4000000]);
      expect(tradplus.estimatedPriceRequests, <String>['tp-1', 'tp-2']);
      expect(listener.starts, <String>[
        'admob-2:4000000.0',
        'admob-2:4000000.0',
      ]);
      expect(listener.overs, <String>['admob-2:true', 'admob-2:true']);
      expect(selected?.info.price, 7000000);
    },
  );

  test(
    'resolves price for a single TradPlus winner without extra callbacks',
    () async {
      final listener = _BidListener();
      final admob = _MultiFakeAdapter(
        networkId: 'admob',
        revenues: <String, double>{'admob-only': 2000000},
      );
      final tradplus = _MultiFakeAdapter(
        networkId: 'tradplus',
        auctionResults: <String, bool>{'tp-only': true},
        revenues: <String, double>{'tp-only': 3500000},
      );
      core
        ..setListener(listener)
        ..registerAdapter(admob)
        ..registerAdapter(tradplus)
        ..updateConfigs<String>(<String, List<AdInfoBean>>{
          'home': <AdInfoBean>[
            _infoWithId('admob', 'admob-only'),
            _infoWithId('tradplus', 'tp-only'),
          ],
        });

      await core.loadPlacement('home', force: true);
      final selected = await core.getCachedEntry('home');

      expect(selected?.info.adId, 'tp-only');
      expect(selected?.info.price, 3500000);
      expect(tradplus.estimatedPriceRequests, <String>['tp-only']);
      expect(listener.starts, <String>['admob-only:2000000.0']);
      expect(listener.overs, <String>['admob-only:true']);
    },
  );

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

AdInfoBean _infoWithId(String networkId, String adId) => AdInfoBean(
  adId: adId,
  adPlat: networkId,
  adType: 'int',
  sort: adId.endsWith('-1') ? 2 : 1,
  userGroup: <int>[0],
);

class _FakeAdapter extends FlutterBoomPdfAdAdapter {
  _FakeAdapter({
    required this.networkId,
    this.estimatedRevenueMicros = 0,
    this.auctionWinner,
    this.initializeFuture,
    this.initializationCompleted,
  });

  @override
  final String networkId;
  final double estimatedRevenueMicros;
  final bool? auctionWinner;
  final Future<void>? initializeFuture;
  @override
  final Future<void>? initializationCompleted;
  double? lastCompetitorRevenueMicros;
  int loadCount = 0;

  @override
  Future<void> initialize() => initializeFuture ?? Future<void>.value();

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

class _InitializationListener extends FlutterBoomPdfAdListener {
  final List<String> networks = <String>[];
  int admobInitialized = 0;

  @override
  void onNetworkInitialized(String networkId) => networks.add(networkId);

  @override
  void onAdmobInitialized() => admobInitialized++;
}

class _BidListener extends FlutterBoomPdfAdListener {
  final List<String> starts = <String>[];
  final List<String> overs = <String>[];

  @override
  void bidStart(AdInfoBean info) {
    starts.add('${info.adId}:${info.price}');
  }

  @override
  void bidOver(AdInfoBean info, bool tpWins) {
    overs.add('${info.adId}:$tpWins');
  }
}

class _MultiFakeAdapter extends FlutterBoomPdfAdAdapter {
  _MultiFakeAdapter({
    required this.networkId,
    required this.revenues,
    this.auctionResults = const <String, bool>{},
  });

  @override
  final String networkId;
  final Map<String, double> revenues;
  final Map<String, bool> auctionResults;
  final List<double> competitorPrices = <double>[];
  final List<String> estimatedPriceRequests = <String>[];

  @override
  Future<void> initialize() async {}

  @override
  bool supports(AdType adType) => true;

  @override
  Future<AdLoadResult> load(AdLoadRequest request) async {
    final adId = request.info.adId!;
    await Future<void>.delayed(
      adId.endsWith('-1')
          ? const Duration(milliseconds: 1100)
          : const Duration(milliseconds: 200),
    );
    final ad = networkId == 'tradplus'
        ? _MultiFakeAuctionAd(
            networkId: networkId,
            adId: adId,
            wins: auctionResults[adId] ?? false,
            estimatedRevenueMicros: revenues[adId] ?? 0,
            competitorPrices: competitorPrices,
            estimatedPriceRequests: estimatedPriceRequests,
          )
        : _FakeAd(networkId);
    return AdLoadResult.success(
      ad,
      estimatedRevenueMicros: networkId == 'admob' ? revenues[adId] ?? 0 : 0,
    );
  }
}

class _MultiFakeAuctionAd extends _FakeAd
    implements AdAuctionCandidate, AdEstimatedRevenueCandidate {
  _MultiFakeAuctionAd({
    required String networkId,
    required this.adId,
    required this.wins,
    required this.estimatedRevenueMicros,
    required this.competitorPrices,
    required this.estimatedPriceRequests,
  }) : super(networkId);

  final String adId;
  final bool wins;
  final double estimatedRevenueMicros;
  final List<double> competitorPrices;
  final List<String> estimatedPriceRequests;

  @override
  Future<bool?> winsAgainst({
    required double competitorRevenueMicros,
    AdInfoBean? competitorInfo,
    void Function(AdInfoBean info)? onBidStart,
    void Function(AdInfoBean info, bool tpWins)? onBidOver,
  }) async {
    competitorPrices.add(competitorRevenueMicros);
    if (competitorInfo != null) {
      competitorInfo.price = competitorRevenueMicros;
      onBidStart?.call(competitorInfo);
      onBidOver?.call(competitorInfo, wins);
    }
    return wins;
  }

  @override
  Future<double?> getEstimatedRevenueMicros() async {
    estimatedPriceRequests.add(adId);
    return estimatedRevenueMicros;
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
  Future<bool?> winsAgainst({
    required double competitorRevenueMicros,
    AdInfoBean? competitorInfo,
    void Function(AdInfoBean info)? onBidStart,
    void Function(AdInfoBean info, bool tpWins)? onBidOver,
  }) async {
    onCompared(competitorRevenueMicros);
    if (competitorInfo != null) {
      competitorInfo.price = competitorRevenueMicros;
      onBidStart?.call(competitorInfo);
      if (result != null) onBidOver?.call(competitorInfo, result!);
    }
    return result;
  }
}
