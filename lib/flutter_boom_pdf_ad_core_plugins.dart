import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'flutter_boom_pdf_ad_core_plugins_platform_interface.dart';
import 'src/adapter/ad_network_adapter.dart';
import 'src/load/loaded_ad_cache_entry.dart';
import 'src/model/ad_info_bean.dart';
import 'src/model/ad_models.dart';
import 'src/model/ad_type.dart';
import 'src/support/core_state_managers.dart';

export 'src/adapter/ad_network_adapter.dart';
export 'src/load/loaded_ad_cache_entry.dart';
export 'src/model/ad_info_bean.dart';
export 'src/model/ad_models.dart';
export 'src/model/ad_type.dart';

typedef FengKongLogic = bool Function();

typedef FlutterPdfAdPlugins = FlutterBoomPdfAdCorePlugins;
typedef FlutterPdfAdListener = FlutterBoomPdfAdListener;

abstract class FlutterBoomPdfAdListener {
  const FlutterBoomPdfAdListener();

  void onAdmobInitialized() {}
  void onNetworkInitialized(String networkId) {}
  void onUserGroupResolved(int userGroup) {}
  void onUmpConsentFlowStart(String countryCode, bool requiresCmpByLocale) {}
  void onUmpFormRequest() {}
  void onUmpFormLoad() {}
  void onUmpConsentFormShow() {}
  void onUmpConsentFlowComplete(UmpConsentResult result) {}
  void onUmpConsentCanRequestAds(bool canRequestAds) {}
  void onAdRequestStart(Object placement, AdInfoBean info) {}
  void onAdRequestSuccess(
    Object placement,
    AdInfoBean info,
    String adNetwork,
    String adSourceName,
    double loadDurationSeconds,
  ) {}
  void onAdRequestFailure(
    Object placement,
    AdInfoBean info,
    String failReason,
    String adNetwork,
    String adSourceName,
    double loadDurationSeconds,
  ) {}
  void onAdShowStart(
    Object placement,
    AdInfoBean info,
    Object adPosId,
    String adNetwork,
    String adSourceName,
  ) {}
  void onAdShowSuccess(
    Object placement,
    AdInfoBean info,
    Object adPosId,
    String adNetwork,
    String adSourceName,
  ) {}
  void onAdShowFailure(
    Object placement,
    AdInfoBean info,
    Object adPosId,
    String adNetwork,
    String adSourceName,
    String errorMessage,
  ) {}
  void onAdClicked(
    Object placement,
    AdInfoBean info,
    Object adPosId,
    String adNetwork,
    String adSourceName,
  ) {}
  void onAdClosed(
    Object placement,
    AdInfoBean info,
    Object adPosId,
    String adNetwork,
    String adSourceName,
  ) {}
  void onAdPaidEvent(
    Object placement,
    Object adPosId,
    double revenue,
    String currencyCode,
    String adNetwork,
    String precisionType,
    AdInfoBean info,
  ) {}
  void onTachi25OneDayRevenueEvent(String eventName) {}
  void onTachi25TotalRevenueEvent(String eventName) {}
}

class FlutterBoomPdfAdCorePlugins {
  FlutterBoomPdfAdCorePlugins._();

  factory FlutterBoomPdfAdCorePlugins() => instance;

  static final FlutterBoomPdfAdCorePlugins instance =
      FlutterBoomPdfAdCorePlugins._();
  static const _admobNetworkId = 'admob';
  static const _defaultCmpCountryCodes = <String>{
    'AT',
    'BE',
    'BG',
    'HR',
    'CY',
    'CZ',
    'DK',
    'EE',
    'FI',
    'FR',
    'DE',
    'GR',
    'HU',
    'IE',
    'IT',
    'LV',
    'LT',
    'LU',
    'MT',
    'NL',
    'PL',
    'PT',
    'RO',
    'SK',
    'SI',
    'ES',
    'SE',
    'NO',
    'IS',
    'LI',
    'CH',
    'GB',
  };

  final Map<String, FlutterBoomPdfAdAdapter> _adapters = {};
  final Map<String, Map<String, Object?>> _networkOptions = {};
  final Map<Object, List<AdInfoBean>> _defaultConfigs = {};
  final Map<Object, List<AdInfoBean>> _facebookConfigs = {};
  final Map<Object, List<LoadedAdCacheEntry>> _cache = {};
  final Map<Object, Future<LoadedAdCacheEntry?>> _loadingTasks = {};
  final Set<Object> _interstitialLikeNativePlacements = {};
  final Set<Object> _smallTemplateNativePlacements = {};
  final Set<Object> _largeBannerPlacements = {};
  final Map<Object, String> _collapsibleBannerDirections = {};
  final Set<Object> _skipReloadAfterClosePlacements = {};
  final Set<Object> _singleFillPlacements = {};
  final Set<Object> _showingPlacements = {};
  final Set<Object> _programmaticClosingPlacements = {};
  final Map<Object, Route<void>> _nativeRoutes = {};
  final Map<Object, Set<VoidCallback>> _placementLoadedListeners = {};
  final Set<String> _cmpCountryCodes = {..._defaultCmpCountryCodes};
  final Random _debugRevenueRandom = Random();

  FlutterBoomPdfAdListener? _listener;
  Duration? _requestFallbackDelay;
  String? _smallNativeAdLayoutName;
  AdChoicesPlacement _nativeAdChoicesPlacement =
      AdChoicesPlacement.bottomLeftCorner;
  double _debugMinRevenue = 0.008;
  double _debugMaxRevenue = 0.02;

  Iterable<String> get registeredNetworkIds =>
      List<String>.unmodifiable(_adapters.keys);

  Future<String?> getPlatformVersion() =>
      FlutterBoomPdfAdCorePluginsPlatform.instance.getPlatformVersion();

  void registerAdapter(FlutterBoomPdfAdAdapter adapter) {
    final id = _normalizeNetworkId(adapter.networkId);
    final previous = _adapters[id];
    if (previous != null && !identical(previous, adapter)) {
      unawaited(previous.dispose());
    }
    _adapters[id] = adapter;
    unawaited(adapter.configure(_configurationFor(id)));
    _log('adapter-registered network=$id');
  }

  Future<void> unregisterAdapter(String networkId) async {
    final id = _normalizeNetworkId(networkId);
    final adapter = _adapters.remove(id);
    if (adapter == null) return;
    final placements = _cache.keys.toList(growable: false);
    for (final placement in placements) {
      final entries = _cache[placement];
      if (entries == null) continue;
      final removed = entries
          .where((entry) => entry.ad.networkId == id)
          .toList();
      for (final entry in removed) {
        entries.remove(entry);
        await entry.dispose();
      }
      if (entries.isEmpty) _cache.remove(placement);
    }
    await adapter.dispose();
  }

  Future<void> initPlugins({
    required String distinctId,
    String? smallNativeAdLayoutName,
    Object nativeAdChoicesPlacement = AdChoicesPlacement.bottomLeftCorner,
  }) async {
    _smallNativeAdLayoutName = _normalizeOptional(smallNativeAdLayoutName);
    _nativeAdChoicesPlacement = _parseAdChoicesPlacement(
      nativeAdChoicesPlacement,
    );
    AdUserGroupManager.instance.onUserGroupResolved =
        _listener?.onUserGroupResolved;
    await Future.wait(
      _adapters.entries.map(
        (entry) => entry.value.configure(_configurationFor(entry.key)),
      ),
    );
    unawaited(AdUserGroupManager.instance.getUserGroup());
    unawaited(AdAttributionManager.instance.restore());
  }

  Future<void> initializeNetworks() async {
    await Future.wait(_adapters.keys.map(initializeNetwork));
  }

  Future<void> initializeNetwork(String networkId) async {
    final id = _normalizeNetworkId(networkId);
    final adapter = _requireAdapter(id);
    await adapter.configure(_configurationFor(id));
    await adapter.initialize();
    _listener?.onNetworkInitialized(id);
    if (id == _admobNetworkId) _listener?.onAdmobInitialized();
  }

  Future<void> initializeAdmob() => initializeNetwork(_admobNetworkId);

  Future<void> updateAdjustAttribution({String? network}) async {
    if (await AdAttributionManager.instance.updateNetwork(network)) {
      await _clearAllCache();
    }
  }

  Future<void> updateInstallReferrer({String? referrer}) async {
    if (await AdAttributionManager.instance.updateReferrer(referrer)) {
      await _clearAllCache();
    }
  }

  Future<String?> getAndroidId() => AdUserGroupManager.instance.getAndroidId();
  Future<int?> getCurrentUserGroup() =>
      AdUserGroupManager.instance.getUserGroup();

  void updateDebugPaidRevenueRange({
    required double minRevenue,
    required double maxRevenue,
  }) {
    _debugMinRevenue = max(0, minRevenue);
    _debugMaxRevenue = max(_debugMinRevenue, maxRevenue);
  }

  void setMaxShowAndClickNum({int? maxShowNum, int? maxClickNum}) {
    AdDailyCountManager.instance.configure(
      maxShowCount: maxShowNum,
      maxClickCount: maxClickNum,
    );
  }

  Future<bool> canTrackAppOpenAdChance() =>
      AdDailyCountManager.instance.canLoadAd();

  void updateAdRequestTimeoutSeconds(int seconds) {
    _requestFallbackDelay = seconds <= 0 ? null : Duration(seconds: seconds);
  }

  void updateInterstitialLikeNativePlacements<K>(Iterable<K> placements) {
    _replacePlacementSet(_interstitialLikeNativePlacements, placements);
  }

  void updateSmallTemplateNativePlacements<K>(Iterable<K> placements) {
    _replacePlacementSet(_smallTemplateNativePlacements, placements);
  }

  void updateLargeBannerPlacements<K>(Iterable<K> placements) {
    _replacePlacementSet(_largeBannerPlacements, placements);
  }

  void updateCollapsibleBannerPlacements<K>(Map<K, String> placements) {
    _collapsibleBannerDirections
      ..clear()
      ..addAll(
        placements.map((key, value) => MapEntry(key as Object, value.trim())),
      );
  }

  void addPlacementLoadedListener<K>(K placement, VoidCallback listener) {
    _placementLoadedListeners
        .putIfAbsent(placement as Object, () => <VoidCallback>{})
        .add(listener);
  }

  void removePlacementLoadedListener<K>(K placement, VoidCallback listener) {
    final key = placement as Object;
    final listeners = _placementLoadedListeners[key];
    listeners?.remove(listener);
    if (listeners?.isEmpty ?? false) _placementLoadedListeners.remove(key);
  }

  void updateSkipReloadAfterClosePlacements<K>(Iterable<K> placements) {
    _replacePlacementSet(_skipReloadAfterClosePlacements, placements);
  }

  void updateSingleFillPlacements<K>(Iterable<K> placements) {
    _replacePlacementSet(_singleFillPlacements, placements);
  }

  void updateTachi25RevenueConfig(Map<String, dynamic>? json) {
    AdRevenueManager.instance.updateConfig(json);
  }

  void setListener(FlutterBoomPdfAdListener? listener) {
    _listener = listener;
    AdUserGroupManager.instance.onUserGroupResolved =
        listener?.onUserGroupResolved;
  }

  bool isShowingAd() => _showingPlacements.isNotEmpty;

  Future<bool> closeFullScreenAd() async {
    final closing = _showingPlacements.toList(growable: false);
    _programmaticClosingPlacements.addAll(closing);
    var closed = false;
    for (final placement in closing) {
      final route = _nativeRoutes[placement];
      final navigator = route?.navigator;
      if (route != null && route.isActive && navigator != null) {
        navigator.removeRoute(route);
        closed = true;
      }
    }
    for (final adapter in _adapters.values) {
      try {
        closed = await adapter.closeFullScreenAd() || closed;
      } catch (error) {
        _log(
          'close-fullscreen-failed network=${adapter.networkId} error=$error',
        );
      }
    }
    if (!closed) _programmaticClosingPlacements.removeAll(closing);
    return closed;
  }

  Future<bool> closeFullScreenAdAndWait({
    Duration timeout = const Duration(milliseconds: 1500),
    Duration pollInterval = const Duration(milliseconds: 50),
  }) async {
    if (!isShowingAd()) return true;
    await closeFullScreenAd();
    final interval = pollInterval > Duration.zero
        ? pollInterval
        : const Duration(milliseconds: 50);
    final stopwatch = Stopwatch()..start();
    while (isShowingAd() && stopwatch.elapsed < timeout) {
      await Future<void>.delayed(interval);
    }
    return !isShowingAd();
  }

  Future<void> updateCloseableFullScreenAdActivityNames(
    Iterable<String> activityNames,
  ) async {
    await Future.wait(
      _adapters.values.map(
        (adapter) =>
            adapter.updateCloseableFullScreenAdActivityNames(activityNames),
      ),
    );
  }

  void updateCmpCountryCodes(Iterable<String> countryCodes) {
    _cmpCountryCodes
      ..clear()
      ..addAll(
        countryCodes
            .map((value) => value.trim().toUpperCase())
            .where((value) => value.isNotEmpty),
      );
  }

  void resetCmpCountryCodes() {
    _cmpCountryCodes
      ..clear()
      ..addAll(_defaultCmpCountryCodes);
  }

  String getCurrentCountryCode() =>
      (ui.PlatformDispatcher.instance.locale.countryCode ?? '').toUpperCase();

  bool shouldUseCmpForCurrentLocale() =>
      _cmpCountryCodes.contains(getCurrentCountryCode());

  Future<UmpConsentResult> handleUmpConsent({
    Object? params,
    bool loadAndShowFormIfRequired = true,
    bool fetchStatusSnapshot = false,
  }) async {
    final countryCode = getCurrentCountryCode();
    final requiredByLocale = _cmpCountryCodes.contains(countryCode);
    _listener?.onUmpConsentFlowStart(countryCode, requiredByLocale);
    _listener?.onUmpFormRequest();
    if (requiredByLocale) _listener?.onUmpFormLoad();
    if (requiredByLocale && loadAndShowFormIfRequired) {
      _listener?.onUmpConsentFormShow();
    }
    final result = await _requireAdapter(_admobNetworkId).handleUmpConsent(
      countryCode: countryCode,
      requiresCmpByLocale: requiredByLocale,
      params: params,
      loadAndShowFormIfRequired: loadAndShowFormIfRequired,
      fetchStatusSnapshot: fetchStatusSnapshot,
    );
    _listener?.onUmpConsentCanRequestAds(result.canRequestAds);
    _listener?.onUmpConsentFlowComplete(result);
    return result;
  }

  Future<bool> canRequestAds() =>
      _requireAdapter(_admobNetworkId).canRequestAds();

  Future<PrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() =>
      _requireAdapter(_admobNetworkId).getPrivacyOptionsRequirementStatus();

  Future<FormError?> showPrivacyOptionsForm() =>
      _requireAdapter(_admobNetworkId).showPrivacyOptionsForm();

  Future<String?> openAdInspector() =>
      _requireAdapter(_admobNetworkId).openAdInspector();

  /// These legacy options stay opaque to Core and are interpreted by AdMob.
  void configureLoader<K>({
    Object? defaultAdRequest,
    Object? bannerSize,
    Object? nativeTemplateStyle,
    String Function(K placement)? placementLabelBuilder,
  }) {
    _networkOptions[_admobNetworkId] = <String, Object?>{
      ...?_networkOptions[_admobNetworkId],
      if (defaultAdRequest != null) 'defaultAdRequest': defaultAdRequest,
      if (bannerSize != null) 'bannerSize': bannerSize,
      if (nativeTemplateStyle != null)
        'nativeTemplateStyle': nativeTemplateStyle,
      if (placementLabelBuilder != null)
        'placementLabelBuilder': (Object value) =>
            placementLabelBuilder(value as K),
    };
    final adapter = _adapters[_admobNetworkId];
    if (adapter != null) {
      unawaited(adapter.configure(_configurationFor(_admobNetworkId)));
    }
  }

  void configureNetwork(
    String networkId, {
    Map<String, Object?> options = const <String, Object?>{},
  }) {
    final id = _normalizeNetworkId(networkId);
    _networkOptions[id] = Map.unmodifiable(options);
    final adapter = _adapters[id];
    if (adapter != null) unawaited(adapter.configure(_configurationFor(id)));
  }

  void updateConfigs<K>(
    Map<K, List<AdInfoBean>> configs, {
    String Function(K placement)? placementLabelBuilder,
  }) {
    _defaultConfigs
      ..clear()
      ..addAll(_boxConfigs(configs));
    if (placementLabelBuilder != null) {
      configureLoader<K>(placementLabelBuilder: placementLabelBuilder);
    }
  }

  void updatePlacementConfig<K>(
    K placement,
    List<AdInfoBean> configs, {
    String Function(K placement)? placementLabelBuilder,
  }) {
    _defaultConfigs[placement as Object] = List.unmodifiable(configs);
    if (placementLabelBuilder != null) {
      configureLoader<K>(placementLabelBuilder: placementLabelBuilder);
    }
  }

  void updateFacebookConfigs<K>(
    Map<K, List<AdInfoBean>> configs, {
    String Function(K placement)? placementLabelBuilder,
  }) {
    _facebookConfigs
      ..clear()
      ..addAll(_boxConfigs(configs));
    if (placementLabelBuilder != null) {
      configureLoader<K>(placementLabelBuilder: placementLabelBuilder);
    }
  }

  void updateFacebookPlacementConfig<K>(
    K placement,
    List<AdInfoBean> configs, {
    String Function(K placement)? placementLabelBuilder,
  }) {
    _facebookConfigs[placement as Object] = List.unmodifiable(configs);
    if (placementLabelBuilder != null) {
      configureLoader<K>(placementLabelBuilder: placementLabelBuilder);
    }
  }

  Future<LoadedAdCacheEntry?> loadPlacement<K>(
    K placement, {
    List<AdInfoBean>? configs,
    bool force = false,
    String Function(K placement)? placementLabelBuilder,
  }) async {
    final key = placement as Object;
    if (placementLabelBuilder != null) {
      configureLoader<K>(placementLabelBuilder: placementLabelBuilder);
    }
    final inFlight = _loadingTasks[key];
    if (inFlight != null) return inFlight;
    await _evictExpired(key);
    final cached = _firstEntry(key);
    if (!force && cached != null) return cached;
    final selected = configs ?? await _resolveConfigs(key);
    if (selected == null || selected.isEmpty) {
      return null;
    }
    final task = _loadPlacementInternal(key, selected);
    _loadingTasks[key] = task;
    try {
      return await task;
    } finally {
      if (identical(_loadingTasks[key], task)) _loadingTasks.remove(key);
    }
  }

  Future<void> preloadAll<K>({
    Iterable<K>? placements,
    bool force = false,
    String Function(K placement)? placementLabelBuilder,
  }) async {
    if (placementLabelBuilder != null) {
      configureLoader<K>(placementLabelBuilder: placementLabelBuilder);
    }
    final targets =
        placements?.map((value) => value as Object).toList() ??
        <Object>{..._defaultConfigs.keys, ..._facebookConfigs.keys}.toList();
    await Future.wait(
      targets.map(
        (placement) => loadPlacement<Object>(placement, force: force),
      ),
    );
  }

  Future<LoadedAdCacheEntry?> getCachedEntry<K>(K placement) async {
    final key = placement as Object;
    await _evictExpired(key);
    return _firstEntry(key);
  }

  Future<Object?> getCachedAd<K>(K placement) async {
    final entry = await getCachedEntry(placement);
    return entry?.rawAd;
  }

  Future<AdInfoBean?> getAvailableCachedAdInfo<K>(K placement) async {
    return (await getCachedEntry(placement))?.info;
  }

  Future<bool> canDisplayPlacement<K>(K placement) async {
    final key = placement as Object;
    if (await getCachedEntry(key) != null) return true;
    final configs = await _resolveConfigs(key);
    return configs?.any(_isLoadableConfig) ?? false;
  }

  Future<Widget?> buildCachedAdWidget<K>(
    K placement, {
    required Object adPosId,
  }) async {
    final key = placement as Object;
    final entry = await getCachedEntry(key);
    if (entry == null || !entry.ad.supportsWidget) {
      return null;
    }
    entry.bindAdPosId(adPosId);
    final child = entry.ad.buildWidget();
    if (child == null) return null;
    return _TrackedAdWidget(
      child: child,
      onShown: () => _notifyShowStart(key, entry),
    );
  }

  Future<Widget?> takeCachedAdWidget<K>(
    K placement, {
    required Object adPosId,
    bool loadIfNeeded = true,
    bool reloadAfterTake = false,
    Duration disposeDelay = const Duration(seconds: 2),
  }) async {
    final key = placement as Object;
    var entry = await getCachedEntry(key);
    if (entry == null && loadIfNeeded) {
      entry = await loadPlacement<Object>(key, force: true);
    }
    if (entry == null || !entry.ad.supportsWidget) {
      return null;
    }
    _removeEntry(key, entry);
    entry.bindAdPosId(adPosId);
    final child = entry.ad.buildWidget();
    if (child == null) {
      await entry.dispose();
      return null;
    }
    _notifyShowStart(key, entry);
    if (reloadAfterTake) unawaited(loadPlacement<Object>(key, force: true));
    return _ConsumableAdWidget(
      entry: entry,
      disposeDelay: disposeDelay,
      child: child,
    );
  }

  Future<void> disposeTakenAdWidget(Widget widget) async {
    if (widget is _ConsumableAdWidget) await widget.handle.disposeNow();
  }

  Future<bool?> showCachedAd<K>(
    K placement, {
    required Object adPosId,
    BuildContext? context,
    OnUserEarnedRewardCallback? onUserEarnedReward,
  }) async {
    final key = placement as Object;
    if (_showingPlacements.contains(key)) {
      return false;
    }
    final entry = await getCachedEntry(key);
    if (entry == null) {
      if (!_skipReloadAfterClosePlacements.contains(key)) {
        unawaited(loadPlacement<Object>(key));
      }
      return false;
    }
    entry.bindAdPosId(adPosId);
    if (entry.info.parsedAdType == AdType.appOpen &&
        !await AdDailyCountManager.instance.canLoadAd()) {
      return false;
    }
    if (entry.info.parsedAdType == AdType.native ||
        (entry.info.parsedAdType?.isFullScreen == true &&
            entry.ad.supportsWidget)) {
      if (context == null || !context.mounted) return false;
      return _showNative(context, key, entry);
    }
    if (entry.info.parsedAdType?.isFullScreen != true) return false;
    _showingPlacements.add(key);
    _notifyShowStart(key, entry);
    try {
      final result = await entry.ad.show(
        onUserEarnedReward: onUserEarnedReward,
      );
      final programmatic = _programmaticClosingPlacements.remove(key);
      if (result.shown == false) {
        _listener?.onAdShowFailure(
          key,
          entry.info,
          adPosId,
          entry.ad.adNetwork,
          entry.ad.adSourceName,
          result.failureReason ?? 'unknown',
        );
      }
      await _consumeEntry(key, entry);
      return programmatic ? null : result.shown;
    } catch (error) {
      _listener?.onAdShowFailure(
        key,
        entry.info,
        adPosId,
        entry.ad.adNetwork,
        entry.ad.adSourceName,
        'exception=$error',
      );
      await _consumeEntry(key, entry);
      return false;
    } finally {
      _showingPlacements.remove(key);
    }
  }

  Future<bool?> loadAndShow<K>(
    K placement, {
    required Object adPosId,
    BuildContext? context,
    List<AdInfoBean>? configs,
    bool forceReload = false,
    OnUserEarnedRewardCallback? onUserEarnedReward,
    String Function(K placement)? placementLabelBuilder,
  }) async {
    if (!forceReload) {
      final shown = await showCachedAd(
        placement,
        adPosId: adPosId,
        context: context,
        onUserEarnedReward: onUserEarnedReward,
      );
      if (shown == true || shown == null) return shown;
    }
    final entry = await loadPlacement(
      placement,
      configs: configs,
      force: forceReload,
      placementLabelBuilder: placementLabelBuilder,
    );
    if (entry == null || (context != null && !context.mounted)) return false;
    return showCachedAd(
      placement,
      adPosId: adPosId,
      context: context,
      onUserEarnedReward: onUserEarnedReward,
    );
  }

  Future<void> clearPlacementCache<K>(K placement) async {
    final entries = _cache.remove(placement as Object);
    if (entries == null) return;
    for (final entry in entries) {
      await entry.dispose();
    }
  }

  Future<void> disposeLoader() async {
    await _clearAllCache();
    _loadingTasks.clear();
    _showingPlacements.clear();
    _nativeRoutes.clear();
  }

  Future<void> dispose() async {
    await disposeLoader();
    for (final adapter in _adapters.values) {
      await adapter.dispose();
    }
    _adapters.clear();
  }

  Future<LoadedAdCacheEntry?> _loadPlacementInternal(
    Object placement,
    List<AdInfoBean> configs,
  ) async {
    var sorted = configs.where(_isLoadableConfig).toList(growable: false)
      ..sort((a, b) => (b.sort ?? 0).compareTo(a.sort ?? 0));
    if (sorted.isEmpty) return null;
    if (sorted.any((item) => item.parsedAdType == AdType.appOpen) &&
        !await AdDailyCountManager.instance.canLoadAd()) {
      sorted = sorted
          .where((item) => item.parsedAdType != AdType.appOpen)
          .toList(growable: false);
      if (sorted.isEmpty) return null;
    }
    final completer = Completer<LoadedAdCacheEntry?>();
    final started = <int>{};
    final completed = <int>{};
    final timers = <Timer>[];
    var hasSuccess = false;

    Future<void> start(int index) async {
      if (index >= sorted.length || !started.add(index)) return;
      final info = sorted[index];
      final adapter = _adapters[info.normalizedNetworkId];
      _listener?.onAdRequestStart(placement, info);
      final delay = _requestFallbackDelay;
      if (delay != null &&
          !_singleFillPlacements.contains(placement) &&
          index + 1 < sorted.length) {
        timers.add(Timer(delay, () => unawaited(start(index + 1))));
      }
      final stopwatch = Stopwatch()..start();
      AdLoadResult result;
      if (adapter == null) {
        result = AdLoadResult.failure(
          'adapter-not-registered:${info.normalizedNetworkId}',
          adNetwork: info.normalizedNetworkId,
        );
      } else if (!adapter.supports(info.parsedAdType!)) {
        result = AdLoadResult.failure(
          'unsupported-ad-type:${info.adType}',
          adNetwork: info.normalizedNetworkId,
        );
      } else {
        try {
          result = await adapter.load(
            AdLoadRequest(
              placement: placement,
              info: info,
              interstitialLikeNative: _interstitialLikeNativePlacements
                  .contains(placement),
              smallTemplateNative: _smallTemplateNativePlacements.contains(
                placement,
              ),
              largeBanner: _largeBannerPlacements.contains(placement),
              collapsibleBannerDirection:
                  _collapsibleBannerDirections[placement],
              networkOptions:
                  _networkOptions[info.normalizedNetworkId] ?? const {},
            ),
          );
        } catch (error) {
          result = AdLoadResult.failure(
            'exception=$error',
            adNetwork: info.normalizedNetworkId,
          );
        }
      }
      stopwatch.stop();
      completed.add(index);
      final seconds =
          stopwatch.elapsedMicroseconds / Duration.microsecondsPerSecond;
      final ad = result.ad;
      if (ad == null) {
        _listener?.onAdRequestFailure(
          placement,
          info,
          result.failureReason ?? 'unknown',
          result.adNetwork ?? info.normalizedNetworkId,
          result.adSourceName ?? result.adNetwork ?? info.normalizedNetworkId,
          seconds,
        );
        if (index + 1 < sorted.length) unawaited(start(index + 1));
        if (completed.length == sorted.length && !completer.isCompleted) {
          completer.complete(null);
        }
        return;
      }
      final entry = LoadedAdCacheEntry(
        info: info,
        ad: ad,
        cachedAt: DateTime.now(),
        requestOrder: index,
      );
      if (_singleFillPlacements.contains(placement) && hasSuccess) {
        await entry.dispose();
        return;
      }
      hasSuccess = true;
      _insertEntry(placement, entry);
      entry.eventSubscription = ad.events.listen(
        (event) => _handleNetworkEvent(placement, entry, event),
      );
      _listener?.onAdRequestSuccess(
        placement,
        info,
        ad.adNetwork,
        ad.adSourceName,
        seconds,
      );
      final listeners = _placementLoadedListeners[placement];
      if (listeners != null) {
        for (final listener in List<VoidCallback>.from(listeners)) {
          listener();
        }
      }
      if (!completer.isCompleted) completer.complete(entry);
    }

    unawaited(start(0));
    final result = await completer.future;
    for (final timer in timers) {
      timer.cancel();
    }
    return result;
  }

  Future<bool?> _showNative(
    BuildContext context,
    Object placement,
    LoadedAdCacheEntry entry,
  ) async {
    final child = entry.ad.buildWidget();
    if (child == null) return false;
    _showingPlacements.add(placement);
    _notifyShowStart(placement, entry);
    final fullScreen =
        entry.info.parsedAdType == AdType.appOpen ||
        _interstitialLikeNativePlacements.contains(placement);
    late final Route<void> route;
    route = fullScreen
        ? MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (routeContext) => Scaffold(
              body: SafeArea(
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(child: child),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        onPressed: () => Navigator.of(routeContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : DialogRoute<void>(
            context: context,
            barrierDismissible: false,
            builder: (routeContext) => Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(width: 320, height: 360, child: child),
                  TextButton(
                    onPressed: () => Navigator.of(routeContext).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
          );
    _nativeRoutes[placement] = route;
    _notifyShowSuccess(placement, entry);
    try {
      await Navigator.of(context).push(route);
      final programmatic = _programmaticClosingPlacements.remove(placement);
      _notifyClosed(placement, entry);
      await _consumeEntry(placement, entry);
      return programmatic ? null : true;
    } finally {
      _nativeRoutes.remove(placement);
      _showingPlacements.remove(placement);
    }
  }

  void _handleNetworkEvent(
    Object placement,
    LoadedAdCacheEntry entry,
    AdNetworkEvent event,
  ) {
    final posId = entry.adPosId ?? placement;
    switch (event.type) {
      case AdNetworkEventType.impression:
        _notifyShowSuccess(placement, entry);
        if (entry.info.parsedAdType == AdType.appOpen) {
          unawaited(AdDailyCountManager.instance.recordShow());
        }
        if (entry.info.parsedAdType?.isFullScreen == true &&
            !_skipReloadAfterClosePlacements.contains(placement)) {
          unawaited(loadPlacement<Object>(placement, force: true));
        }
      case AdNetworkEventType.clicked:
        _listener?.onAdClicked(
          placement,
          entry.info,
          posId,
          entry.ad.adNetwork,
          entry.ad.adSourceName,
        );
        if (entry.info.parsedAdType == AdType.appOpen) {
          unawaited(AdDailyCountManager.instance.recordClick());
        }
      case AdNetworkEventType.closed:
        _notifyClosed(placement, entry);
        final route = _nativeRoutes[placement];
        final navigator = route?.navigator;
        if (route != null && route.isActive && navigator != null) {
          navigator.removeRoute(route);
        }
      case AdNetworkEventType.paid:
        unawaited(_handlePaidEvent(placement, entry, event));
    }
  }

  Future<void> _handlePaidEvent(
    Object placement,
    LoadedAdCacheEntry entry,
    AdNetworkEvent event,
  ) async {
    var micros = event.valueMicros ?? 0;
    if (kDebugMode && micros <= 0) {
      final revenue =
          _debugMinRevenue +
          _debugRevenueRandom.nextDouble() *
              (_debugMaxRevenue - _debugMinRevenue);
      micros = revenue * 1000000;
    }
    final revenue = micros / 1000000;
    final record = await AdRevenueManager.instance.record(revenue);
    _listener?.onAdPaidEvent(
      placement,
      entry.adPosId ?? placement,
      revenue,
      event.currencyCode ?? 'USD',
      entry.ad.adNetwork,
      event.precisionType ?? 'unknown',
      entry.info,
    );
    for (final eventName in record.triggeredEvents) {
      if (eventName.startsWith('AdLTV_OneDay_')) {
        _listener?.onTachi25OneDayRevenueEvent(eventName);
      } else {
        _listener?.onTachi25TotalRevenueEvent(eventName);
      }
    }
  }

  void _notifyShowStart(Object placement, LoadedAdCacheEntry entry) {
    _listener?.onAdShowStart(
      placement,
      entry.info,
      entry.adPosId ?? placement,
      entry.ad.adNetwork,
      entry.ad.adSourceName,
    );
  }

  void _notifyShowSuccess(Object placement, LoadedAdCacheEntry entry) {
    if (entry.showSuccessNotified) return;
    entry.showSuccessNotified = true;
    _listener?.onAdShowSuccess(
      placement,
      entry.info,
      entry.adPosId ?? placement,
      entry.ad.adNetwork,
      entry.ad.adSourceName,
    );
  }

  void _notifyClosed(Object placement, LoadedAdCacheEntry entry) {
    if (entry.closedNotified) return;
    entry.closedNotified = true;
    _listener?.onAdClosed(
      placement,
      entry.info,
      entry.adPosId ?? placement,
      entry.ad.adNetwork,
      entry.ad.adSourceName,
    );
  }

  Future<void> _consumeEntry(Object placement, LoadedAdCacheEntry entry) async {
    _removeEntry(placement, entry);
    await entry.dispose();
    if (!_skipReloadAfterClosePlacements.contains(placement) &&
        _firstEntry(placement) == null) {
      unawaited(loadPlacement<Object>(placement, force: true));
    }
  }

  Future<void> _evictExpired(Object placement) async {
    final entries = _cache[placement];
    if (entries == null) return;
    final expired = entries.where((entry) => entry.isExpired).toList();
    for (final entry in expired) {
      entries.remove(entry);
      await entry.dispose();
    }
    if (entries.isEmpty) _cache.remove(placement);
  }

  void _insertEntry(Object placement, LoadedAdCacheEntry entry) {
    final entries = _cache.putIfAbsent(placement, () => <LoadedAdCacheEntry>[]);
    var index = entries.length;
    for (var i = 0; i < entries.length; i++) {
      if (entry.requestOrder <= entries[i].requestOrder) {
        index = i;
        break;
      }
    }
    entries.insert(index, entry);
  }

  LoadedAdCacheEntry? _firstEntry(Object placement) {
    final entries = _cache[placement];
    return entries == null || entries.isEmpty ? null : entries.first;
  }

  void _removeEntry(Object placement, LoadedAdCacheEntry entry) {
    final entries = _cache[placement];
    entries?.remove(entry);
    if (entries?.isEmpty ?? false) _cache.remove(placement);
  }

  Future<List<AdInfoBean>?> _resolveConfigs(Object placement) async {
    await AdAttributionManager.instance.restore();
    final group = await AdUserGroupManager.instance.getUserGroup();
    final configs =
        AdAttributionManager.instance.isFacebookUser &&
            (_facebookConfigs[placement]?.isNotEmpty ?? false)
        ? _facebookConfigs[placement]
        : _defaultConfigs[placement];
    if (configs == null) return null;
    return configs
        .where((info) {
          final groups = info.userGroup ?? const <int>[];
          return groups.contains(0) ||
              (group != null && groups.contains(group));
        })
        .toList(growable: false);
  }

  bool _isLoadableConfig(AdInfoBean info) =>
      info.adId?.isNotEmpty == true && info.parsedAdType != null;

  Map<Object, List<AdInfoBean>> _boxConfigs<K>(
    Map<K, List<AdInfoBean>> configs,
  ) => configs.map(
    (key, value) => MapEntry(key as Object, List.unmodifiable(value)),
  );

  void _replacePlacementSet<K>(Set<Object> target, Iterable<K> values) {
    target
      ..clear()
      ..addAll(values.map((value) => value as Object));
  }

  AdNetworkConfiguration _configurationFor(String networkId) {
    return AdNetworkConfiguration(
      smallNativeAdLayoutName: _smallNativeAdLayoutName,
      nativeAdChoicesPlacement: _nativeAdChoicesPlacement,
      options: _networkOptions[networkId] ?? const <String, Object?>{},
    );
  }

  FlutterBoomPdfAdAdapter _requireAdapter(String networkId) {
    final id = _normalizeNetworkId(networkId);
    final adapter = _adapters[id];
    if (adapter == null) {
      throw StateError('Ad adapter "$id" has not been registered.');
    }
    return adapter;
  }

  String _normalizeNetworkId(String value) => value.trim().toLowerCase();
  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  AdChoicesPlacement _parseAdChoicesPlacement(Object value) {
    final name = value is AdChoicesPlacement
        ? value.name
        : value.toString().split('.').last;
    return AdChoicesPlacement.values.firstWhere(
      (item) => item.name == name,
      orElse: () => AdChoicesPlacement.bottomLeftCorner,
    );
  }

  Future<void> _clearAllCache() async {
    final placements = _cache.keys.toList(growable: false);
    for (final placement in placements) {
      await clearPlacementCache<Object>(placement);
    }
  }

  void _log(String message) {
    if (!kReleaseMode) debugPrint('[FlutterBoomPdfAdCore] $message');
  }
}

class _TrackedAdWidget extends StatefulWidget {
  const _TrackedAdWidget({required this.child, required this.onShown});

  final Widget child;
  final VoidCallback onShown;

  @override
  State<_TrackedAdWidget> createState() => _TrackedAdWidgetState();
}

class _TrackedAdWidgetState extends State<_TrackedAdWidget> {
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _notified) return;
      _notified = true;
      widget.onShown();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ConsumableAdWidget extends StatefulWidget {
  _ConsumableAdWidget({
    required this.entry,
    required this.disposeDelay,
    required this.child,
  }) : handle = _ConsumableAdHandle(entry, disposeDelay);

  final LoadedAdCacheEntry entry;
  final Duration disposeDelay;
  final Widget child;
  final _ConsumableAdHandle handle;

  @override
  State<_ConsumableAdWidget> createState() => _ConsumableAdWidgetState();
}

class _ConsumableAdWidgetState extends State<_ConsumableAdWidget> {
  @override
  void initState() {
    super.initState();
    widget.handle.attach();
  }

  @override
  void dispose() {
    widget.handle.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ConsumableAdHandle {
  _ConsumableAdHandle(this.entry, this.delay);

  final LoadedAdCacheEntry entry;
  final Duration delay;
  int _attachments = 0;
  Timer? _timer;
  bool _disposed = false;

  void attach() {
    if (_disposed) return;
    _attachments++;
    _timer?.cancel();
  }

  void detach() {
    if (_disposed) return;
    _attachments = max(0, _attachments - 1);
    if (_attachments > 0) return;
    _timer?.cancel();
    if (delay <= Duration.zero) {
      unawaited(disposeNow());
    } else {
      _timer = Timer(delay, disposeNow);
    }
  }

  Future<void> disposeNow() async {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    await entry.dispose();
  }
}
