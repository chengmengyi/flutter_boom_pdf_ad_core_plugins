import 'ad_type.dart';

class AdInfoBean {
  AdInfoBean({
    this.adId,
    this.adPlat,
    this.exportTime,
    this.adType,
    this.sort,
    this.userGroup,
    this.price = 0,
  });

  AdInfoBean.fromJson(dynamic json) : price = 0 {
    adId = json['adId'];
    adPlat = json['adPlat'];
    exportTime = _readInt(json['exportTime']);
    sort = _readInt(json['sort']);
    adType = json['adType'];
    userGroup = _readIntList(json['userGroup']);
  }

  factory AdInfoBean.fromPlacementJson(Map<String, dynamic> json) {
    return AdInfoBean(
      adId: json['jsk'] as String?,
      adPlat: json['iwk'] as String?,
      adType: json['iwn'] as String?,
      exportTime: _readInt(json['isk']),
      sort: _readInt(json['ipn']),
      userGroup: _readIntList(json['grp']),
    );
  }

  String? adId;
  String? adPlat;
  String? adType;
  int? exportTime;
  int? sort;
  List<int>? userGroup;

  /// Runtime normalized comparison price. Adapters populate this after an ad
  /// loads; it is intentionally excluded from placement JSON parsing/output.
  double price;

  AdType? get parsedAdType => AdTypeX.tryParse(adType);

  /// Empty legacy platform values are AdMob for backwards compatibility.
  String get normalizedNetworkId {
    final value = adPlat?.trim().toLowerCase();
    if (value == null || value.isEmpty || value == 'google') {
      return 'admob';
    }
    return value;
  }

  String get logSummary {
    return 'adId=$adId, adPlat=$adPlat, adType=$adType, sort=$sort, '
        'exportTime=$exportTime, userGroup=$userGroup';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'adId': adId,
    'adPlat': adPlat,
    'exportTime': exportTime,
    'sort': sort,
    'userGroup': userGroup,
    'adType': adType,
  };
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

List<int> _readIntList(dynamic value) {
  if (value is! List) return <int>[];
  return value.map(_readInt).whereType<int>().toList(growable: false);
}
