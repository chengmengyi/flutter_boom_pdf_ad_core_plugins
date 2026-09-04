import 'dart:async';

import '../model/ad_info_bean.dart';
import '../model/ad_models.dart';

class LoadedAdCacheEntry {
  LoadedAdCacheEntry({
    required this.info,
    required this.ad,
    required this.cachedAt,
    required this.requestOrder,
  });

  final AdInfoBean info;
  final LoadedNetworkAd ad;
  Object? adPosId;
  final DateTime cachedAt;
  final int requestOrder;
  StreamSubscription<AdNetworkEvent>? eventSubscription;
  bool showSuccessNotified = false;
  bool closedNotified = false;

  Object get rawAd => ad.rawAd;

  void bindAdPosId(Object value) {
    adPosId = value;
  }

  DateTime? get expireAt {
    final exportTime = info.exportTime;
    if (exportTime == null || exportTime <= 0) return null;
    return cachedAt.add(Duration(seconds: exportTime));
  }

  bool get isExpired {
    final value = expireAt;
    return value != null && DateTime.now().isAfter(value);
  }

  Future<void> dispose() async {
    await eventSubscription?.cancel();
    eventSubscription = null;
    await ad.dispose();
  }
}
