import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_boom_pdf_ad_admob_plugins/flutter_boom_pdf_ad_admob_plugins.dart';
import 'package:flutter_boom_pdf_ad_core_plugins/flutter_boom_pdf_ad_core_plugins.dart';

const _placement = 'demo_interstitial';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterBoomPdfAdAdmobPlugins.install();
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key, this.initializeAds = true});

  final bool initializeAds;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: AdDemoPage(initializeAds: initializeAds));
  }
}

class AdDemoPage extends StatefulWidget {
  const AdDemoPage({super.key, this.initializeAds = true});

  final bool initializeAds;

  @override
  State<AdDemoPage> createState() => _AdDemoPageState();
}

class _AdDemoPageState extends State<AdDemoPage> {
  final _core = FlutterBoomPdfAdCorePlugins.instance;
  String _status = '等待初始化';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initializeAds) _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _busy = true);
    try {
      _core.setListener(_DemoListener(_setStatus));
      await _core.initPlugins(distinctId: 'core-admob-example');
      await _core.initializeAdmob();
      _core.updatePlacementConfig<String>(_placement, <AdInfoBean>[
        AdInfoBean(
          adId: Platform.isIOS
              ? 'ca-app-pub-3940256099942544/4411468910'
              : 'ca-app-pub-3940256099942544/1033173712',
          adPlat: 'admob',
          adType: 'int',
          sort: 1,
          exportTime: 3600,
          userGroup: <int>[0],
        ),
      ]);
      _setStatus('Core 和 AdMob 初始化完成');
    } catch (error) {
      _setStatus('初始化失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final entry = await _core.loadPlacement(_placement, force: true);
      _setStatus(entry == null ? '广告加载失败' : '广告已缓存，可以展示');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _show() async {
    final shown = await _core.showCachedAd(_placement, adPosId: 'demo-button');
    _setStatus('展示结果：$shown');
  }

  void _setStatus(String value) {
    if (mounted) setState(() => _status = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Core + AdMob Demo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(_status),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _load,
              child: const Text('请求插屏广告'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _show,
              child: const Text('显示缓存广告'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoListener extends FlutterBoomPdfAdListener {
  const _DemoListener(this.onStatus);

  final ValueChanged<String> onStatus;

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
}
