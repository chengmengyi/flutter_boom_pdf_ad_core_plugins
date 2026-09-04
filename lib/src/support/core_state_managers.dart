import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

import '../../flutter_boom_pdf_ad_core_plugins_platform_interface.dart';

class AdUserGroupManager {
  AdUserGroupManager._();

  static final AdUserGroupManager instance = AdUserGroupManager._();
  static const _container = 'flutter_pdf_ad_plugins_user_group';
  static const _groupKey = 'ad_user_group';
  static const _versionKey = 'ad_user_group_version';
  static const _version = 2;

  String? _androidId;
  int? _group;
  Future<int?>? _task;
  Future<void>? _ready;
  GetStorage? _storage;
  void Function(int userGroup)? onUserGroupResolved;

  Future<String?> getAndroidId() async {
    if (!Platform.isAndroid) return null;
    if (_androidId?.isNotEmpty ?? false) return _androidId;
    try {
      _androidId =
          (await FlutterBoomPdfAdCorePluginsPlatform.instance.getAndroidId())
              ?.trim();
    } catch (error) {
      _log('android-id-failed error=$error');
    }
    return _androidId;
  }

  Future<int?> getUserGroup() async {
    if (_group != null) return _group;
    if (!Platform.isAndroid) return null;
    await _ensureReady();
    final localVersion = _asInt(_storage?.read<dynamic>(_versionKey));
    final localGroup = _asInt(_storage?.read<dynamic>(_groupKey));
    if (localVersion == _version &&
        localGroup != null &&
        localGroup >= 1 &&
        localGroup <= 8) {
      _group = localGroup;
      return localGroup;
    }
    final inFlight = _task;
    if (inFlight != null) return inFlight;
    final future = _calculate();
    _task = future;
    try {
      return await future;
    } finally {
      if (identical(_task, future)) _task = null;
    }
  }

  Future<int?> _calculate() async {
    final id = await getAndroidId();
    if (id == null || id.isEmpty) return null;
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = ((hash * 31) + unit) & 0xffffffff;
      if (hash >= 0x80000000) hash -= 0x100000000;
    }
    final value = hash.remainder(8).abs() + 1;
    _group = value;
    await _storage?.write(_groupKey, value);
    await _storage?.write(_versionKey, _version);
    onUserGroupResolved?.call(value);
    return value;
  }

  Future<void> _ensureReady() {
    return _ready ??= () async {
      await GetStorage.init(_container);
      _storage = GetStorage(_container);
    }();
  }
}

class AdDailyCountManager {
  AdDailyCountManager._();

  static final AdDailyCountManager instance = AdDailyCountManager._();
  static const _container = 'flutter_pdf_ad_plugins_daily_count';
  static const _dateKey = 'date';
  static const _showKey = 'show_count';
  static const _clickKey = 'click_count';

  int? _maxShow;
  int? _maxClick;
  GetStorage? _storage;
  Future<void>? _ready;
  Future<void> _queue = Future<void>.value();

  void configure({int? maxShowCount, int? maxClickCount}) {
    _maxShow = _normalize(maxShowCount);
    _maxClick = _normalize(maxClickCount);
  }

  Future<bool> canLoadAd() => _enqueue(() async {
    if (_maxShow == null && _maxClick == null) return true;
    await _ensureReady();
    await _resetDay();
    return !((_maxShow != null && _read(_showKey) >= _maxShow!) ||
        (_maxClick != null && _read(_clickKey) >= _maxClick!));
  });

  Future<void> recordShow() => _record(_showKey);
  Future<void> recordClick() => _record(_clickKey);

  Future<void> _record(String key) => _enqueue(() async {
    if (_maxShow == null && _maxClick == null) return;
    await _ensureReady();
    await _resetDay();
    await _storage?.write(key, _read(key) + 1);
  });

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  Future<void> _ensureReady() => _ready ??= () async {
    await GetStorage.init(_container);
    _storage = GetStorage(_container);
  }();

  Future<void> _resetDay() async {
    final now = DateTime.now();
    final date = '${now.year}-${now.month}-${now.day}';
    if (_storage?.read<String>(_dateKey) == date) return;
    await _storage?.write(_dateKey, date);
    await _storage?.write(_showKey, 0);
    await _storage?.write(_clickKey, 0);
  }

  int _read(String key) => _asInt(_storage?.read<dynamic>(key)) ?? 0;
  int? _normalize(int? value) => value?.clamp(0, 1 << 31);
}

class AdAttributionManager {
  AdAttributionManager._();

  static final AdAttributionManager instance = AdAttributionManager._();
  static const _adjustContainer = 'flutter_pdf_ad_plugins_adjust';
  static const _referrerContainer = 'flutter_pdf_ad_plugins_referrer';
  static const _networkKey = 'attribution_network';
  static const _referrerKey = 'install_referrer';

  GetStorage? _adjustStorage;
  GetStorage? _referrerStorage;
  Future<void>? _ready;
  bool _restored = false;
  String? network;
  String? referrer;

  Future<void> restore() async {
    if (_restored) return;
    await _ensureReady();
    network = _normalize(_adjustStorage?.read<String>(_networkKey));
    referrer = _normalize(_referrerStorage?.read<String>(_referrerKey));
    _restored = true;
  }

  Future<bool> updateNetwork(String? value) async {
    await restore();
    final next = _normalize(value);
    if (network == next) return false;
    network = next;
    await _write(_adjustStorage, _networkKey, next);
    return true;
  }

  Future<bool> updateReferrer(String? value) async {
    await restore();
    final next = _normalize(value);
    if (referrer == next) return false;
    referrer = next;
    await _write(_referrerStorage, _referrerKey, next);
    return true;
  }

  bool get isFacebookUser =>
      (network ?? '').toLowerCase().contains('facebook') ||
      (referrer ?? '').toLowerCase().contains('facebook');

  Future<void> _ensureReady() => _ready ??= () async {
    await Future.wait(<Future<bool>>[
      GetStorage.init(_adjustContainer),
      GetStorage.init(_referrerContainer),
    ]);
    _adjustStorage = GetStorage(_adjustContainer);
    _referrerStorage = GetStorage(_referrerContainer);
  }();

  Future<void> _write(GetStorage? storage, String key, String? value) async {
    if (value == null) {
      await storage?.remove(key);
    } else {
      await storage?.write(key, value);
    }
  }

  String? _normalize(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class AdRevenueManager {
  AdRevenueManager._();

  static final AdRevenueManager instance = AdRevenueManager._();
  static const _container = 'flutter_pdf_ad_plugins_revenue';
  static const _dateKey = 'daily_revenue_date';
  static const _dailyKey = 'daily_revenue_amount';
  static const _totalKey = 'total_revenue_amount';
  static const _dailyTriggeredKey = 'daily_revenue_triggered_events';
  static const _totalTriggeredKey = 'total_revenue_triggered_events';
  static const _configNames = <String, String>{
    'reader_oneday_top10': 'AdLTV_OneDay_Top10Percent',
    'reader_oneday_top20': 'AdLTV_OneDay_Top20Percent',
    'reader_oneday_top30': 'AdLTV_OneDay_Top30Percent',
    'reader_oneday_top40': 'AdLTV_OneDay_Top40Percent',
    'reader_oneday_top50': 'AdLTV_OneDay_Top50Percent',
  };
  static const _totalThresholds = <String, double>{
    'Adecpm_OneDay_100': 100,
    'Adecpm_OneDay_150': 150,
    'Adecpm_OneDay_200': 200,
  };

  GetStorage? _storage;
  Future<void>? _ready;
  Map<String, double> _dailyThresholds = <String, double>{};

  void updateConfig(Map<String, dynamic>? json) {
    _dailyThresholds = <String, double>{
      for (final entry in _configNames.entries)
        if (_asDouble(json?[entry.key]) case final value? when value > 0)
          entry.value: value,
    };
  }

  Future<AdRevenueRecordResult> record(double value) async {
    if (value <= 0) {
      return const AdRevenueRecordResult(0, 0, 0, <String>[]);
    }
    await _ensureReady();
    await _rollDay();
    final daily = (_asDouble(_storage?.read<dynamic>(_dailyKey)) ?? 0) + value;
    final total = (_asDouble(_storage?.read<dynamic>(_totalKey)) ?? 0) + value;
    await _storage?.write(_dailyKey, daily);
    await _storage?.write(_totalKey, total);
    final events = <String>[];
    events.addAll(
      await _consume(_dailyKey, daily, _dailyThresholds, _dailyTriggeredKey),
    );
    events.addAll(
      await _consume(_totalKey, total, _totalThresholds, _totalTriggeredKey),
    );
    return AdRevenueRecordResult(value, daily, total, events);
  }

  Future<List<String>> _consume(
    String key,
    double value,
    Map<String, double> thresholds,
    String triggeredKey,
  ) async {
    final triggered = (_storage?.read<List<dynamic>>(triggeredKey) ?? const [])
        .map((item) => item.toString())
        .toSet();
    final added = <String>[];
    final entries = thresholds.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final entry in entries) {
      if (value >= entry.value && triggered.add(entry.key)) {
        added.add(entry.key);
      }
    }
    if (added.isNotEmpty) {
      await _storage?.write(triggeredKey, triggered.toList());
    }
    return added;
  }

  Future<void> _ensureReady() => _ready ??= () async {
    await GetStorage.init(_container);
    _storage = GetStorage(_container);
  }();

  Future<void> _rollDay() async {
    final now = DateTime.now();
    final date = '${now.year}-${now.month}-${now.day}';
    if (_storage?.read<String>(_dateKey) == date) return;
    await _storage?.write(_dateKey, date);
    await _storage?.write(_dailyKey, 0.0);
    await _storage?.write(_dailyTriggeredKey, <String>[]);
  }
}

class AdRevenueRecordResult {
  const AdRevenueRecordResult(
    this.revenue,
    this.dailyRevenue,
    this.totalRevenue,
    this.triggeredEvents,
  );

  final double revenue;
  final double dailyRevenue;
  final double totalRevenue;
  final List<String> triggeredEvents;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

void _log(String message) {
  if (!kReleaseMode) debugPrint('[FlutterBoomPdfAdCore] $message');
}
