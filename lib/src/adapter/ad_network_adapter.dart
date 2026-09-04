import '../model/ad_models.dart';
import '../model/ad_type.dart';

abstract class FlutterBoomPdfAdAdapter {
  String get networkId;

  Future<void> configure(AdNetworkConfiguration configuration) async {}

  Future<void> initialize();

  bool supports(AdType adType);

  Future<AdLoadResult> load(AdLoadRequest request);

  Future<UmpConsentResult> handleUmpConsent({
    required String countryCode,
    required bool requiresCmpByLocale,
    Object? params,
    bool loadAndShowFormIfRequired = true,
    bool fetchStatusSnapshot = false,
  }) {
    throw UnsupportedError('$networkId does not provide a consent service');
  }

  Future<bool> canRequestAds() async => true;

  Future<PrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() async =>
      PrivacyOptionsRequirementStatus.unknown;

  Future<FormError?> showPrivacyOptionsForm() {
    throw UnsupportedError('$networkId does not provide a privacy form');
  }

  Future<String?> openAdInspector() {
    throw UnsupportedError('$networkId does not provide an ad inspector');
  }

  Future<bool> closeFullScreenAd() async => false;

  Future<void> updateCloseableFullScreenAdActivityNames(
    Iterable<String> activityNames,
  ) async {}

  Future<void> dispose() async {}
}
