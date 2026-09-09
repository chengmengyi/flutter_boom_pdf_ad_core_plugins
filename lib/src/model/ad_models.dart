import 'package:flutter/widgets.dart';

import 'ad_info_bean.dart';
import 'ad_type.dart';

enum AdChoicesPlacement {
  topLeftCorner,
  topRightCorner,
  bottomLeftCorner,
  bottomRightCorner,
}

class AdRewardItem {
  const AdRewardItem({required this.amount, required this.type});

  final num amount;
  final String type;
}

typedef OnUserEarnedRewardCallback =
    void Function(Object ad, AdRewardItem reward);

class AdErrorInfo {
  const AdErrorInfo(this.message, {this.code, this.domain});

  final String message;
  final int? code;
  final String? domain;

  @override
  String toString() {
    return 'code=${code ?? 'unknown'} message=$message '
        'domain=${domain ?? 'unknown'}';
  }
}

enum ConsentStatus { unknown, required, notRequired, obtained }

enum PrivacyOptionsRequirementStatus { unknown, required, notRequired }

class FormError extends AdErrorInfo {
  const FormError(this.errorCode, String message)
    : super(message, code: errorCode, domain: 'UMP');

  final int errorCode;
}

class UmpConsentResult {
  const UmpConsentResult({
    required this.countryCode,
    required this.requiresCmpByLocale,
    required this.canRequestAds,
    required this.consentStatus,
    required this.privacyOptionsRequirementStatus,
    this.formError,
  });

  final String countryCode;
  final bool requiresCmpByLocale;
  final bool canRequestAds;
  final ConsentStatus consentStatus;
  final PrivacyOptionsRequirementStatus privacyOptionsRequirementStatus;
  final FormError? formError;
}

class AdNetworkConfiguration {
  const AdNetworkConfiguration({
    this.smallNativeAdLayoutName,
    this.nativeAdChoicesPlacement = AdChoicesPlacement.bottomLeftCorner,
    this.options = const <String, Object?>{},
  });

  final String? smallNativeAdLayoutName;
  final AdChoicesPlacement nativeAdChoicesPlacement;
  final Map<String, Object?> options;
}

class AdLoadRequest {
  const AdLoadRequest({
    required this.placement,
    required this.info,
    required this.interstitialLikeNative,
    required this.smallTemplateNative,
    required this.largeBanner,
    this.collapsibleBannerDirection,
    this.networkOptions = const <String, Object?>{},
  });

  final Object placement;
  final AdInfoBean info;
  final bool interstitialLikeNative;
  final bool smallTemplateNative;
  final bool largeBanner;
  final String? collapsibleBannerDirection;
  final Map<String, Object?> networkOptions;
}

class AdLoadResult {
  const AdLoadResult.success(this.ad, {this.estimatedRevenueMicros = 0})
    : failureReason = null,
      adNetwork = null,
      adSourceName = null;

  const AdLoadResult.failure(
    this.failureReason, {
    this.adNetwork,
    this.adSourceName,
  }) : ad = null,
       estimatedRevenueMicros = 0;

  final LoadedNetworkAd? ad;
  final double estimatedRevenueMicros;
  final String? failureReason;
  final String? adNetwork;
  final String? adSourceName;
}

class AdShowResult {
  const AdShowResult._({required this.shown, this.failureReason});

  const AdShowResult.success() : this._(shown: true);
  const AdShowResult.failure(String reason)
    : this._(shown: false, failureReason: reason);
  const AdShowResult.programmaticClose()
    : this._(shown: null, failureReason: 'programmatic-close');

  final bool? shown;
  final String? failureReason;
}

typedef ShowAdResult = AdShowResult;

enum AdNetworkEventType { impression, clicked, closed, paid }

class AdNetworkEvent {
  const AdNetworkEvent._(
    this.type, {
    this.valueMicros,
    this.currencyCode,
    this.precisionType,
  });

  const AdNetworkEvent.impression() : this._(AdNetworkEventType.impression);
  const AdNetworkEvent.clicked() : this._(AdNetworkEventType.clicked);
  const AdNetworkEvent.closed() : this._(AdNetworkEventType.closed);
  const AdNetworkEvent.paid({
    required double valueMicros,
    required String currencyCode,
    required String precisionType,
  }) : this._(
         AdNetworkEventType.paid,
         valueMicros: valueMicros,
         currencyCode: currencyCode,
         precisionType: precisionType,
       );

  final AdNetworkEventType type;
  final double? valueMicros;
  final String? currencyCode;
  final String? precisionType;
}

/// Optional capability implemented by an ad whose SDK owns the final auction
/// decision. The competitor value and both callback prices use the normalized
/// price unit returned by the adapters. The `Micros` suffix is retained for
/// source compatibility.
abstract interface class AdAuctionCandidate {
  Future<bool?> winsAgainst({
    required double competitorRevenueMicros,
    AdInfoBean? competitorInfo,
    AdInfoBean? candidateInfo,
    void Function(AdInfoBean admobInfo, AdInfoBean tradplusInfo)? onBidStart,
    void Function(AdInfoBean winnerInfo)? onBidOver,
  });
}

/// Optional capability for adapters that can resolve a loaded ad's estimated
/// revenue. Implementations return the normalized comparison price. The
/// `Micros` suffix is retained for source compatibility.
abstract interface class AdEstimatedRevenueCandidate {
  Future<double?> getEstimatedRevenueMicros();
}

abstract interface class LoadedNetworkAd {
  String get networkId;
  String get adNetwork;
  String get adSourceName;
  AdType get adType;
  Object get rawAd;
  bool get supportsWidget;
  Stream<AdNetworkEvent> get events;

  Widget? buildWidget();

  Future<AdShowResult> show({OnUserEarnedRewardCallback? onUserEarnedReward});

  Future<void> dispose();
}
