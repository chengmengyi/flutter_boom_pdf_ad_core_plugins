import '../model/ad_models.dart';
import '../model/ad_type.dart';

/// Controls when Core should start replenishing a displayed full-screen ad.
enum AdRefillTrigger {
  /// Refill after the displayed ad has closed and its cache is consumed.
  afterClose,

  /// Start refilling as soon as the displayed ad reports a successful show.
  afterShowSuccess,
}

abstract class FlutterBoomPdfAdAdapter {
  String get networkId;

  /// The default preserves the close-then-refill behavior used by most SDKs.
  AdRefillTrigger get refillTrigger => AdRefillTrigger.afterClose;

  /// Whether this adapter must complete its consent flow before its SDK can be
  /// initialized and its ads can be requested.
  bool get requiresConsentBeforeInitialization => false;

  Future<void> configure(AdNetworkConfiguration configuration) async {}

  Future<void> initialize();

  /// Optional SDK-completion signal for adapters whose requests may start
  /// before the SDK's background initialization has finished.
  ///
  /// When this is non-null, Core does not await it from [initializeNetwork],
  /// but delays the initialized callbacks until it completes.
  Future<void>? get initializationCompleted => null;

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
