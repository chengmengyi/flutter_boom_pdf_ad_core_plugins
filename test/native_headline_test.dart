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
    await core.dispose();
    core.updateConfigs<Object>(const <Object, List<AdInfoBean>>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test('forwards one native headline with platform context', () async {
    final adapter = _HeadlineAdapter();
    final listener = _HeadlineListener();
    final legacyEvents = <String>[];
    core
      ..setListener(listener)
      ..registerAdapter(adapter)
      ..updateConfigs<String>(<String, List<AdInfoBean>>{
        'home': <AdInfoBean>[
          AdInfoBean(
            adId: 'native-unit',
            adPlat: 'tradplus',
            adType: 'nat',
            userGroup: <int>[0],
          ),
        ],
      });
    await core.initPlugins(
      distinctId: 'test-user',
      nativeAdHeadlineCallback: ({required headline, required isNextGenAdmob}) {
        legacyEvents.add('$headline:$isNextGenAdmob');
      },
    );

    await core.loadPlacement('home', force: true);
    adapter.loadedAd.emitHeadline('Test Ad: Sample');
    adapter.loadedAd.emitHeadline('duplicate');
    await Future<void>.delayed(Duration.zero);

    expect(legacyEvents, <String>['Test Ad: Sample:false']);
    expect(listener.events, <String>[
      'home:native-unit:tradplus:Pangle:Test Ad: Sample:false',
    ]);
  });
}

class _HeadlineListener extends FlutterBoomPdfAdListener {
  final List<String> events = <String>[];

  @override
  void onNativeAdHeadline(
    Object placement,
    AdInfoBean info,
    String platform,
    String adNetwork,
    String? headline,
    bool isNextGenAdmob,
  ) {
    events.add(
      '$placement:${info.adId}:$platform:$adNetwork:$headline:'
      '$isNextGenAdmob',
    );
  }
}

class _HeadlineAdapter extends FlutterBoomPdfAdAdapter {
  final _HeadlineAd loadedAd = _HeadlineAd();

  @override
  String get networkId => 'tradplus';

  @override
  Future<void> initialize() async {}

  @override
  bool supports(AdType adType) => adType == AdType.native;

  @override
  Future<AdLoadResult> load(AdLoadRequest request) async {
    return AdLoadResult.success(loadedAd);
  }
}

class _HeadlineAd implements LoadedNetworkAd {
  final StreamController<AdNetworkEvent> _events =
      StreamController<AdNetworkEvent>.broadcast(sync: true);

  void emitHeadline(String? value) {
    _events.add(AdNetworkEvent.nativeHeadline(headline: value));
  }

  @override
  String get networkId => 'tradplus';

  @override
  String get adNetwork => 'Pangle';

  @override
  String get adSourceName => 'Pangle';

  @override
  AdType get adType => AdType.native;

  @override
  Stream<AdNetworkEvent> get events => _events.stream;

  @override
  Object get rawAd => this;

  @override
  bool get supportsWidget => true;

  @override
  Widget? buildWidget() => const SizedBox.shrink();

  @override
  Future<AdShowResult> show({
    OnUserEarnedRewardCallback? onUserEarnedReward,
  }) async => const AdShowResult.failure('widget-only');

  @override
  Future<void> dispose() => _events.close();
}
