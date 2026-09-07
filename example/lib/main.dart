import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_boom_pdf_ad_admob_plugins/flutter_boom_pdf_ad_admob_plugins.dart';
import 'package:flutter_boom_pdf_ad_core_plugins/flutter_boom_pdf_ad_core_plugins.dart';
import 'package:flutter_boom_pdf_ad_tradplus_plugins/flutter_boom_pdf_ad_tradplus_plugins.dart';

const _placement = 'pr_new_launch';

// TODO: 替换成项目实际使用的 ID。
// AdMob Application ID 另外配置在 AndroidManifest.xml 和 Info.plist 中。
const _tradplusAppId = 'CF2B2EDDC7F18DC98BF044ACCCE4FF11';
const _androidAdmobInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
const _iosAdmobInterstitialId = 'YOUR_IOS_ADMOB_INTERSTITIAL_ID';
const _androidTradplusInterstitialId = 'C82CA60397FE71E933EEF0207999F212';
const _iosTradplusInterstitialId = 'YOUR_IOS_TRADPLUS_INTERSTITIAL_ID';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key, this.initializeAds = false});

  final bool initializeAds;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: AdDemoPage(initializeAds: initializeAds));
  }
}

class AdDemoPage extends StatefulWidget {
  const AdDemoPage({super.key, this.initializeAds = false});

  final bool initializeAds;

  @override
  State<AdDemoPage> createState() => _AdDemoPageState();
}

class _AdDemoPageState extends State<AdDemoPage> {
  final _core = FlutterBoomPdfAdCorePlugins.instance;
  String _status = '请先填写顶部的广告 ID，然后点击初始化';
  bool _busy = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.initializeAds) _initialize();
  }

  Future<void> _initialize() async {
    await _run('初始化', () async {
      _core.setListener(_DemoListener(_setStatus));

      FlutterBoomPdfAdAdmobPlugins.install(into: _core);
      FlutterBoomPdfAdTradplusPlugins.install(
        into: _core,
        appId: _tradplusAppId,
      );

      await _core.initPlugins(distinctId: 'core-dual-platform-example');
      await _core.initializeNetworks();

      // 两个平台同时请求；同平台存在多条配置时，3 秒未返回则启动下一条。
      _core.updateAdRequestTimeoutSeconds(3);
      final rawConfigs = _buildRawConfigs();
      final configs = _parsePlacementConfigs(rawConfigs);
      _core.updateConfigs<String>(configs);

      _initialized = true;
      _setStatus(
        '初始化完成：${_core.registeredNetworkIds.join(', ')}；'
        '$_placement 合并后有 ${configs[_placement]?.length ?? 0} 条配置',
      );
    });
  }

  Future<void> _load() async {
    await _run('请求', () async {
      if (!_initialized) {
        _setStatus('请先初始化广告平台');
        return;
      }
      final entry = await _core.loadPlacement(_placement, force: true);
      _setStatus(
        entry == null ? '两个平台均未加载到广告' : '广告已缓存：${entry.ad.adNetwork}，可以点击显示',
      );
    });
  }

  Future<void> _show() async {
    await _run('显示', () async {
      if (!_initialized) {
        _setStatus('请先初始化并请求广告');
        return;
      }
      final shown = await _core.showCachedAd(
        _placement,
        adPosId: 'demo-button',
        context: context,
      );
      _setStatus('广告显示流程结束：$shown；关闭后 Core 会自动请求下一条');
    });
  }

  Future<void> _run(String action, Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      _setStatus('$action失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setStatus(String value) {
    if (mounted) setState(() => _status = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Core + AdMob + TradPlus Demo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              '广告位：$_placement',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(_status),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy || _initialized ? null : _initialize,
              icon: const Icon(Icons.settings),
              label: const Text('1. 初始化 AdMob + TradPlus'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _load,
              child: const Text('2. 请求插屏广告'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _show,
              child: const Text('3. 显示缓存广告'),
            ),
            if (_busy) ...<Widget>[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

/// 模拟服务端原始 JSON：两个不同配置 Key 实际属于同一个业务广告位。
Map<String, dynamic> _buildRawConfigs() {
  return <String, dynamic>{
    'pr_new_launch': <Map<String, dynamic>>[
      <String, dynamic>{
        'jsk': Platform.isIOS
            ? _iosAdmobInterstitialId
            : _androidAdmobInterstitialId,
        'iwk': 'admob',
        'iwn': 'int',
        'isk': 3600,
        'ipn': 100,
        'grp': <int>[0],
      },
    ],
    'pr_new_launch2': <Map<String, dynamic>>[
      <String, dynamic>{
        'jsk': Platform.isIOS
            ? _iosTradplusInterstitialId
            : _androidTradplusInterstitialId,
        'iwk': 'tradplus',
        'iwn': 'int',
        'isk': 3600,
        'ipn': 90,
        'grp': <int>[0],
      },
    ],
  };
}

/// 将配置层的 pr_new_launch/pr_new_launch2 合并成逻辑广告位 pr_new_launch。
Map<String, List<AdInfoBean>> _parsePlacementConfigs(
  Map<String, dynamic> rawConfigs,
) {
  final result = <String, List<AdInfoBean>>{};
  for (final entry in rawConfigs.entries) {
    final placement = _logicalPlacementForConfigKey(entry.key);
    final value = entry.value;
    if (placement == null || value is! List) continue;

    final configs = result.putIfAbsent(placement, () => <AdInfoBean>[]);
    configs.addAll(
      value.whereType<Map>().map(
        (item) => AdInfoBean.fromPlacementJson(Map<String, dynamic>.from(item)),
      ),
    );
  }
  return result;
}

String? _logicalPlacementForConfigKey(String configKey) {
  switch (configKey) {
    case 'pr_new_launch':
    case 'pr_new_launch2':
      return _placement;
    case 'pr_launch':
    case 'pr_launch2':
      return 'pr_launch';
    default:
      return null;
  }
}

class _DemoListener extends FlutterBoomPdfAdListener {
  const _DemoListener(this.onStatus);

  final ValueChanged<String> onStatus;

  @override
  void onNetworkInitialized(String networkId) {
    onStatus('$networkId 初始化完成');
  }

  @override
  void onAdRequestStart(Object placement, AdInfoBean info) {
    onStatus('开始请求：$placement');
  }

  @override
  void onAdRequestSuccess(
    Object placement,
    AdInfoBean info,
    String adNetwork,
    String adSourceName,
    double loadDurationSeconds,
  ) {
    onStatus('加载成功：$adNetwork，${loadDurationSeconds.toStringAsFixed(2)} 秒');
  }

  @override
  void onAdRequestFailure(
    Object placement,
    AdInfoBean info,
    String failReason,
    String adNetwork,
    String adSourceName,
    double loadDurationSeconds,
  ) {
    onStatus('加载失败：$failReason');
  }

  @override
  void onAdShowSuccess(
    Object placement,
    AdInfoBean info,
    Object adPosId,
    String adNetwork,
    String adSourceName,
  ) {
    onStatus('展示成功：$adNetwork');
  }

  @override
  void onAdClosed(
    Object placement,
    AdInfoBean info,
    Object adPosId,
    String adNetwork,
    String adSourceName,
  ) {
    onStatus('广告已关闭：$adNetwork');
  }
}
