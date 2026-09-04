import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_boom_pdf_ad_core_plugins/flutter_boom_pdf_ad_core_plugins.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'registered adapter completes initialize, load, cache and show flow',
    () async {
      final core = FlutterBoomPdfAdCorePlugins.instance;
      await core.dispose();
      final adapter = _FakeAdapter();
      final listener = _RecordingListener();
      core.registerAdapter(adapter);
      core.setListener(listener);
      await core.initializeAdmob();
      final configs = <AdInfoBean>[
        AdInfoBean(
          adId: 'unit-id',
          adPlat: null,
          adType: 'int',
          sort: 1,
          userGroup: <int>[0],
        ),
      ];

      final loaded = await core.loadPlacement('home', configs: configs);
      expect(loaded, isNotNull);
      expect(await core.getCachedEntry('home'), same(loaded));
      expect(listener.initialized, 1);
      expect(listener.loadStarted, 1);
      expect(listener.loadSucceeded, 1);

      core.updateSkipReloadAfterClosePlacements(<String>['home']);
      final shown = await core.showCachedAd('home', adPosId: 'home-pos');
      expect(shown, isTrue);
      expect(listener.showStarted, 1);
      expect(listener.showSucceeded, 1);
      expect(listener.closed, 1);
      expect(await core.getCachedEntry('home'), isNull);
      await core.dispose();
    },
  );
}

class _FakeAdapter extends FlutterBoomPdfAdAdapter {
  @override
  String get networkId => 'admob';

  @override
  Future<void> initialize() async {}

  @override
  bool supports(AdType adType) => true;

  @override
  Future<AdLoadResult> load(AdLoadRequest request) async {
    return AdLoadResult.success(_FakeAd(request.info.parsedAdType!));
  }
}

class _FakeAd implements LoadedNetworkAd {
  _FakeAd(this.adType);

  final StreamController<AdNetworkEvent> _events =
      StreamController<AdNetworkEvent>.broadcast(sync: true);

  @override
  final AdType adType;
  @override
  String get networkId => 'admob';
  @override
  String get adNetwork => 'Fake AdMob';
  @override
  String get adSourceName => 'Fake source';
  @override
  Object get rawAd => this;
  @override
  bool get supportsWidget => false;
  @override
  Stream<AdNetworkEvent> get events => _events.stream;
  @override
  Widget? buildWidget() => null;

  @override
  Future<AdShowResult> show({
    OnUserEarnedRewardCallback? onUserEarnedReward,
  }) async {
    _events.add(const AdNetworkEvent.impression());
    _events.add(const AdNetworkEvent.closed());
    return const AdShowResult.success();
  }

  @override
  Future<void> dispose() => _events.close();
}

class _RecordingListener extends FlutterPdfAdListener {
  int initialized = 0;
  int loadStarted = 0;
  int loadSucceeded = 0;
  int showStarted = 0;
  int showSucceeded = 0;
  int closed = 0;

  @override
  void onAdmobInitialized() => initialized++;
  @override
  void onAdRequestStart(Object placement, AdInfoBean info) => loadStarted++;
  @override
  void onAdRequestSuccess(
    Object placement,
    AdInfoBean info,
    String adNetwork,
    String adSourceName,
    double loadDurationSeconds,
  ) => loadSucceeded++;
  @override
  void onAdShowStart(
    Object placement,
    AdInfoBean info,
    Object adPosId,
    String adNetwork,
    String adSourceName,
  ) => showStarted++;
  @override
  void onAdShowSuccess(
    Object placement,
    AdInfoBean info,
    Object adPosId,
    String adNetwork,
    String adSourceName,
  ) => showSucceeded++;
  @override
  void onAdClosed(
    Object placement,
    AdInfoBean info,
    Object adPosId,
    String adNetwork,
    String adSourceName,
  ) => closed++;
}
