# flutter_boom_pdf_ad_core_plugins

Boom PDF 广告 Core。Core 不依赖具体广告 SDK，统一负责：

- 平台 Adapter 注册和初始化
- 广告位配置及平台路由
- 请求顺序、失败兜底和缓存
- 插屏、激励、开屏、原生及 Banner 的展示
- 展示、点击、关闭和收益回调
- 全屏广告关闭后的自动补充请求

具体广告 SDK 由独立 Adapter 提供。目前可接入：

- `flutter_boom_pdf_ad_admob_plugins`：AdMob
- `flutter_boom_pdf_ad_tradplus_plugins`：TradPlus

业务代码只调用 Core。需要哪个平台，就在 App 中依赖并安装哪个 Adapter。

> Android 同时安装 AdMob 和 TradPlus 时，`showCachedAd` 会在展示前自动比价；只安装一个平台或只有一个平台加载成功时，直接使用现有缓存。

## 1. 添加依赖

同时接入 AdMob 和 TradPlus：

```yaml
dependencies:
  flutter_boom_pdf_ad_core_plugins:
    path: ../plugins/flutter_boom_pdf_ad_core_plugins
  flutter_boom_pdf_ad_admob_plugins:
    path: ../plugins/flutter_boom_pdf_ad_admob_plugins
  flutter_boom_pdf_ad_tradplus_plugins:
    path: ../plugins/flutter_boom_pdf_ad_tradplus_plugins
```

App 必须继续完成 AdMob 和 TradPlus 各自要求的 Android/iOS 原生配置，例如 App ID、权限以及需要启用的广告网络依赖。

如果项目只需要一个平台，只依赖并安装对应 Adapter 即可，业务侧的 Core API 不变。

## 2. 推荐初始化顺序

推荐顺序如下：

1. 初始化 Flutter Binding。
2. 安装需要使用的 Adapter。
3. 设置各平台初始化参数和隐私参数。
4. 设置 Core 监听器及通用配置。
5. 调用 `initPlugins`，把 Core 配置下发给 Adapter。
6. 如需 AdMob UMP，先完成 UMP 流程。
7. 初始化所有已注册的平台。
8. 写入广告位配置，然后开始预加载。

完整示例：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_boom_pdf_ad_admob_plugins/flutter_boom_pdf_ad_admob_plugins.dart';
import 'package:flutter_boom_pdf_ad_core_plugins/flutter_boom_pdf_ad_core_plugins.dart';
import 'package:flutter_boom_pdf_ad_tradplus_plugins/flutter_boom_pdf_ad_tradplus_plugins.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final ads = FlutterBoomPdfAdCorePlugins.instance;

  // 1. 注册平台。install 必须在 initializeNetworks 之前调用。
  await FlutterBoomPdfAdAdmobPlugins.install(
    into: ads,
    queryAdRevenueConfig: const QueryAdRevenueConfig(
      enableRevenue: true,
      openKeyList: <String>['YOUR_OPEN_REVENUE_KEY'],
      intKeyList: <String>['YOUR_INTERSTITIAL_REVENUE_KEY'],
      nativeKeyList: <String>['YOUR_NATIVE_REVENUE_KEY'],
      libName: 'YOUR_SO_LIBRARY_NAME_WITHOUT_LIB_PREFIX',
    ),
  );
  FlutterBoomPdfAdTradplusPlugins.install(
    into: ads,
    appId: 'YOUR_TRADPLUS_APP_ID',
  );

  // 2. 平台参数必须在初始化 SDK 之前设置。
  ads.configureNetwork(
    'tradplus',
    options: <String, Object?>{
      TradplusAdOptions.privacyUserAgree: true,
      TradplusAdOptions.openPersonalizedAd: true,
      TradplusAdOptions.loadTimeout: const Duration(seconds: 20),
    },
  );

  // 3. Core 回调和通用参数。
  ads.setListener(const AppAdListener());
  ads.updateAdRequestTimeoutSeconds(3);

  // 4. 初始化 Core，把配置下发给两个 Adapter。
  await ads.initPlugins(
    distinctId: 'CURRENT_USER_ID',
    smallNativeAdLayoutName: 'smallNativeAd',
    nativeAdChoicesPlacement: AdChoicesPlacement.bottomLeftCorner,
  );

  // 5. 如项目需要 AdMob UMP，在广告 SDK 初始化前执行。
  // 不要在 canRequestAds=false 时 return；Core 会只停用 AdMob，其他平台照常运行。
  final consent = await ads.handleUmpConsent();

  // 6. 并行初始化全部已安装平台。
  await ads.initializeNetworks();

  // 7. 设置广告位。实际项目一般由服务端配置转换而来。
  configureAdPlacements(ads);

  // 8. 可以在启动时统一预加载，也可以进入页面后按广告位请求。
  await ads.preloadAll();

  runApp(const App());
}
```

`initializeNetworks()` 会并行启动所有已经注册的 Adapter。TradPlus 必须等待 SDK 初始化成功，所以这个 Future 会等待 TradPlus；AdMob 调用 `MobileAds.instance.initialize()` 后立即返回，不会阻塞广告请求。AdMob SDK 真正初始化完成后，Core 才会回调 `onNetworkInitialized('admob')` 和 `onAdmobInitialized()`。

Core 会按平台复用同一个初始化任务，并在每个平台自己的加载队列前等待该任务。需要在启动阶段立即请求广告时，不要先单独 `await initializeNetworks()`，而是让初始化和预加载同时启动：

```dart
final initializeFuture = ads.initializeNetworks();
final preloadFuture = ads.preloadAll();

await Future.wait<void>([initializeFuture, preloadFuture]);
```

此时 AdMob 的初始化任务立即允许加载，所以会马上开始请求；TradPlus 的加载队列会等待 `tp_initFinish` 成功后才请求。两个平台仍属于同一次 placement 加载，不会重复请求 AdMob。同一平台被多个 placement 同时使用时，也只会初始化一次。

调用 `handleUmpConsent()` 后，Core 会保存 AdMob 的 `canRequestAds` 状态。若为 `false`，Core 会清除已有 AdMob 缓存，并在 `initializeNetworks()`、`loadPlacement()` 和 `preloadAll()` 中跳过 AdMob；同一广告位里的 TradPlus 等其他平台不会受影响。未调用 UMP 的项目保持原行为。隐私状态可能变化时，调用 `canRequestAds()` 可刷新这个门控状态；状态恢复允许后，再调用 `initializeNetwork('admob')` 并重新请求广告。

如果需要逐个平台控制，可以改为：

```dart
await ads.initializeNetwork('admob');
await ads.initializeNetwork('tradplus');
```

旧业务代码也可以继续使用：

```dart
await ads.initializeAdmob();
```

`initializeAdmob()` 只初始化 AdMob，不会初始化 TradPlus。

## 3. 配置两个平台的广告位

同一个 `placement` 可以配置两个平台：

```dart
void configureAdPlacements(FlutterBoomPdfAdCorePlugins ads) {
  ads.updateConfigs<String>(
    <String, List<AdInfoBean>>{
      'home_interstitial': <AdInfoBean>[
        AdInfoBean(
          adId: 'ADMOB_INTERSTITIAL_UNIT_ID',
          adPlat: 'admob',
          adType: 'int',
          sort: 100,
          userGroup: <int>[0],
        ),
        AdInfoBean(
          adId: 'TRADPLUS_INTERSTITIAL_UNIT_ID',
          adPlat: 'tradplus',
          adType: 'int',
          sort: 90,
          userGroup: <int>[0],
        ),
      ],
      'reward_video': <AdInfoBean>[
        AdInfoBean(
          adId: 'ADMOB_REWARDED_UNIT_ID',
          adPlat: 'admob',
          adType: 'rv',
          sort: 100,
          userGroup: <int>[0],
        ),
        AdInfoBean(
          adId: 'TRADPLUS_REWARDED_UNIT_ID',
          adPlat: 'tradplus',
          adType: 'rv',
          sort: 90,
          userGroup: <int>[0],
        ),
      ],
    },
  );
}
```

`AdInfoBean` 主要字段：

| 字段 | 说明 |
| --- | --- |
| `adId` | 对应平台的广告位 ID |
| `adPlat` | 平台 ID：`admob` 或 `tradplus` |
| `adType` | 广告类型 |
| `sort` | 当前版本的请求优先级，数字越大越先请求 |
| `userGroup` | 用户分组；包含 `0` 表示所有用户可用 |
| `exportTime` | 广告缓存有效期，单位为秒 |
| `price` | 加载/比价后填充的运行时预估收益（micros），不属于配置 JSON |

兼容旧配置：`adPlat` 为 `null`、空字符串或者 `google` 时，Core 会路由到 AdMob。

广告类型：

| `adType` | 类型 |
| --- | --- |
| `open` | App Open / 开屏广告 |
| `int` | 插屏广告 |
| `rv`、`raw`、`rwd` | 激励视频 |
| `ban` | Banner |
| `nat` | 原生广告 |

广告配置通过 `updateConfigs` 一次性设置：

```dart
ads.updateConfigs<String>(
  <String, List<AdInfoBean>>{
    'home_interstitial': homeInterstitialConfigs,
    'reward_video': rewardedConfigs,
  },
);
```

## 4. 多平台请求规则

请求单个广告位：

```dart
final entry = await ads.loadPlacement('home_interstitial');
if (entry == null) {
  // 此广告位的所有可用配置都请求失败。
}
```

当前 Core 的请求规则：

1. 先按照 `adPlat` 将同一广告位的配置分成 AdMob、TradPlus 等平台组。
2. 不同平台组同时开始请求，因此 AdMob 和 TradPlus 的第一条配置会并行请求。
3. 每个平台组内部按 `sort` 从高到低排序，沿用原 `flutter_pdf_ad_plugins` 的瀑布逻辑。
4. 某个平台当前配置失败时，只会继续请求该平台组内的下一条配置，不会影响其他平台。
5. 调用 `updateAdRequestTimeoutSeconds(3)` 后，某个平台当前配置 3 秒仍未完成，会提前启动同平台的下一条配置。
6. `loadPlacement` 会等待每个平台获得一个成功结果或者该平台全部失败，再从成功结果中返回 `sort` 优先级最高的广告。
7. 各平台成功加载的广告都会进入 Core 缓存，为后续竞价保留候选广告。
8. 同一广告位已经有缓存时，普通请求直接返回缓存；传入 `force: true` 才会强制发起新一轮多平台请求。
9. 同一广告位已有请求正在进行时，后续请求会复用同一个 Future，避免重复加载。

如果配置了超时兜底，可能出现两个平台请求都已启动的情况。某个广告位只希望保留第一个成功结果时，可以配置：

```dart
ads.updateSingleFillPlacements(<String>{
  'home_interstitial',
});
```

展示前的选择规则：

1. 缓存里只有一个候选广告时直接返回，不发起比价。
2. 多条 AdMob 缓存先按预估收益取最高值；每条 TradPlus 缓存都会分别与这条 AdMob 比较，因此超时后晚到的成功缓存也会参与。
3. Core 把 AdMob 微单位收益除以 `1000000` 后传给 TradPlus，Android 端调用 `TPOutcome().isTPW(admobPrice, tpAdInfo)`。
4. 一条或多条 TradPlus 胜出后，Core 会逐条探测其美元 eCPM；只有一条时用于补齐运行时价格，多条时选择价格最高的一条。
5. `AdInfoBean.price` 是运行时价格，统一使用 micros，不会从配置 JSON 读取，也不会写回 JSON。

AdMob 的预估收益由 `query_ad_revenue` 提供，当前支持 App Open、插屏和原生广告；激励视频和 Banner 在 Release 中按 `0` 参与比较。Debug 模式下，如果查询值为 `0`（包括不支持的类型或查询异常），AdMob Adapter 会从 `123000`、`1240000`、`12500000`、`126000000` micros 中随机取一个并写入缓存；后续所有比价复用该值。查询收益所需的 `.so` 仍放在业务 App，由 `QueryAdRevenueConfig.libName` 指定，不需要放进 AdMob Adapter。

直接传入临时配置：

```dart
await ads.loadPlacement(
  'temporary_interstitial',
  configs: <AdInfoBean>[
    AdInfoBean(
      adId: 'ADMOB_UNIT_ID',
      adPlat: 'admob',
      adType: 'int',
      sort: 100,
      userGroup: <int>[0],
    ),
  ],
  force: true,
);
```

预加载全部已配置广告位：

```dart
await ads.preloadAll();
```

只预加载部分广告位：

```dart
await ads.preloadAll<String>(
  placements: <String>['home_interstitial', 'reward_video'],
);
```

## 5. 显示全屏广告

插屏、激励视频和 App Open 使用 `showCachedAd`：

```dart
final result = await ads.showCachedAd(
  'home_interstitial',
  adPosId: 'home_page_enter',
  context: context,
);

if (result == true) {
  // 广告正常展示并关闭。
} else if (result == false) {
  // 没有缓存，或者广告展示失败。
} else {
  // 广告由 closeFullScreenAd 主动关闭。
}
```

大部分 AdMob/TradPlus 全屏广告不需要 `context`。以下情况必须传入已经 mounted 的 `BuildContext`：

- Android TradPlus 开屏广告
- 通过 `showCachedAd` 展示的原生广告

激励视频：

```dart
final shown = await ads.showCachedAd(
  'reward_video',
  adPosId: 'unlock_pdf_feature',
  context: context,
  onUserEarnedReward: (ad, reward) {
    grantReward(
      amount: reward.amount,
      type: reward.type,
    );
  },
);
```

没有缓存时自动请求并展示：

```dart
final shown = await ads.loadAndShow(
  'home_interstitial',
  adPosId: 'home_page_enter',
  context: context,
);
```

`loadAndShow` 会优先使用缓存；没有缓存时先请求，成功后再展示。

## 6. 关闭后的缓存和下一条请求

全屏广告生命周期如下：

```text
请求成功 -> 写入缓存 -> 开始展示 -> 展示成功 -> 用户关闭
                                              |
                                              v
                                  删除已展示广告的缓存
                                              |
                                              v
                            只为刚展示的平台请求下一条广告
```

注意：

- 展示成功回调不会请求下一条广告。
- 用户关闭广告后，`showCachedAd` 才会完成，并清理刚刚展示的缓存。
- Core 会在关闭后为刚刚展示的平台请求下一条广告。
- 其他平台未展示的候选缓存会保留；等刚展示的平台补充成功后，下次展示仍会进行比价。
- 展示失败时也会清理失效广告并补充请求，避免广告位一直不可用。

某些广告位不希望关闭后自动补充，可以配置：

```dart
ads.updateSkipReloadAfterClosePlacements(<String>{
  'one_time_interstitial',
});
```

主动关闭正在展示的全屏广告：

```dart
await ads.closeFullScreenAd();

// 或者等待关闭流程结束。
final closed = await ads.closeFullScreenAdAndWait();
```

## 7. 显示 Banner 和原生广告

先请求，然后取得平台返回的 Widget：

```dart
await ads.loadPlacement('home_banner');

final adWidget = await ads.buildCachedAdWidget(
  'home_banner',
  adPosId: 'home_bottom_banner',
);
```

在页面中展示。建议在 `initState` 中保存 Future，避免页面每次 `build` 都重新创建：

```dart
late final Future<Widget?> _bannerFuture;

@override
void initState() {
  super.initState();
  _bannerFuture = ads.buildCachedAdWidget(
    'home_banner',
    adPosId: 'home_bottom_banner',
  );
}

@override
Widget build(BuildContext context) {
  return FutureBuilder<Widget?>(
    future: _bannerFuture,
    builder: (context, snapshot) {
      return snapshot.data ?? const SizedBox.shrink();
    },
  );
}
```

如果 Widget 从缓存中取出后只使用一次，可使用 `takeCachedAdWidget`：

```dart
final adWidget = await ads.takeCachedAdWidget(
  'home_native',
  adPosId: 'home_native_card',
  loadIfNeeded: true,
  reloadAfterTake: true,
);
```

`reloadAfterTake: true` 表示取出当前 Widget 后立即补充缓存。这是行内广告的显式行为，与全屏广告“关闭后自动补充”是两套生命周期。

## 8. 广告事件监听

实现 `FlutterBoomPdfAdListener`，只覆写业务需要的回调：

```dart
class AppAdListener extends FlutterBoomPdfAdListener {
  const AppAdListener();

  @override
  void bidStart(
    Object placement,
    Object adPosId,
    String adNetwork,
    AdInfoBean admobInfo,
    AdInfoBean tradplusInfo,
  ) {
    debugPrint(
      '开始比价：$placement/$adPosId/$adNetwork，'
      'AdMob=${admobInfo.adId}/${admobInfo.price} micros，'
      'TradPlus=${tradplusInfo.adId}/${tradplusInfo.price} micros',
    );
  }

  @override
  void bidOver(
    Object placement,
    Object adPosId,
    String adNetwork,
    AdInfoBean winnerInfo,
  ) {
    debugPrint(
      '比价结束：$placement/$adPosId/$adNetwork，'
      '${winnerInfo.adPlat} 胜出，'
      '${winnerInfo.adId}/${winnerInfo.price} micros',
    );
  }

  @override
  void onNetworkInitialized(String networkId) {
    debugPrint('广告平台初始化完成：$networkId');
  }

  @override
  void onAdRequestSuccess(
    Object placement,
    AdInfoBean info,
    String adNetwork,
    String adSourceName,
    double loadDurationSeconds,
  ) {
    debugPrint('$placement 请求成功：$adNetwork / $adSourceName');
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
    debugPrint('$placement 请求失败：$adNetwork / $failReason');
  }

  @override
  void onAdShowSuccess(
    Object placement,
    AdInfoBean info,
    Object adPosId,
    String adNetwork,
    String adSourceName,
  ) {
    debugPrint('$placement 展示成功：$adNetwork');
  }

  @override
  void onAdClosed(
    Object placement,
    AdInfoBean info,
    Object adPosId,
    String adNetwork,
    String adSourceName,
  ) {
    debugPrint('$placement 已关闭：$adNetwork');
  }

  @override
  void onAdPaidEvent(
    Object placement,
    Object adPosId,
    double revenue,
    String currencyCode,
    String adNetwork,
    String precisionType,
    AdInfoBean info,
  ) {
    debugPrint('$placement 收益：$revenue $currencyCode / $adNetwork');
  }
}
```

`bidStart` 的 `adNetwork` 是当前参与比较的 TradPlus 广告实际网络；`bidOver` 的 `adNetwork` 是本次胜出广告的实际网络。Core 只在调用方提供真实 `adPosId` 的展示或 Widget 获取流程中触发这两个回调；直接调用不带 `adPosId` 的 `getCachedEntry`、`getCachedAd` 等查询接口仍会完成缓存比价，但不会发送比价事件。

主要生命周期回调：

- `onAdRequestStart`、`onAdRequestSuccess`、`onAdRequestFailure`
- `onAdShowStart`、`onAdShowSuccess`、`onAdShowFailure`
- `onAdClicked`、`onAdClosed`
- `onAdPaidEvent`
- `onNetworkInitialized`
- `bidStart`、`bidOver`（TradPlus 与 AdMob 开始/结束比价）

## 9. 只接入一个平台

只使用 AdMob：

```dart
await FlutterBoomPdfAdAdmobPlugins.install(
  queryAdRevenueConfig: const QueryAdRevenueConfig(
    enableRevenue: true,
    openKeyList: <String>['YOUR_OPEN_REVENUE_KEY'],
    intKeyList: <String>['YOUR_INTERSTITIAL_REVENUE_KEY'],
    nativeKeyList: <String>['YOUR_NATIVE_REVENUE_KEY'],
    libName: 'YOUR_SO_LIBRARY_NAME_WITHOUT_LIB_PREFIX',
  ),
);
await ads.initPlugins(distinctId: userId);
await ads.initializeAdmob();
```

只使用 TradPlus：

```dart
FlutterBoomPdfAdTradplusPlugins.install(
  appId: 'YOUR_TRADPLUS_APP_ID',
);
await ads.initPlugins(distinctId: userId);
await ads.initializeNetwork('tradplus');
```

广告位配置中只放对应平台的 `AdInfoBean`。Core 根据已经安装的 Adapter 和广告配置工作，不需要业务代码手动声明当前有几个平台。

可以查看当前已注册的平台：

```dart
debugPrint(ads.registeredNetworkIds.toString());
// (admob, tradplus)
```

## 10. 常用缓存 API

```dart
final entry = await ads.getCachedEntry('home_interstitial');
final rawAd = await ads.getCachedAd('home_interstitial');
final info = await ads.getAvailableCachedAdInfo('home_interstitial');
final canDisplay = await ads.canDisplayPlacement('home_interstitial');

await ads.clearPlacementCache('home_interstitial');
await ads.disposeLoader();
```

`disposeLoader()` 会释放广告缓存和加载状态，但不会注销 Adapter。应用彻底不再使用广告时可以调用 `dispose()`；它还会释放并注销所有 Adapter。

## 11. 新增第三个平台

新增平台时，实现 `FlutterBoomPdfAdAdapter` 并注册到 Core：

```dart
class NewNetworkAdapter extends FlutterBoomPdfAdAdapter {
  @override
  String get networkId => 'new_network';

  // 实现 initialize、supports 和 load 等接口。
}

ads.registerAdapter(NewNetworkAdapter());
await ads.initializeNetwork('new_network');
```

服务端广告配置使用 `adPlat: 'new_network'` 即可路由到新 Adapter。请求、缓存、显示和事件回调继续由 Core 统一处理。

## 兼容名称

为了兼容原 `flutter_pdf_ad_plugins` 的业务代码，Core 保留以下别名：

```dart
typedef FlutterPdfAdPlugins = FlutterBoomPdfAdCorePlugins;
typedef FlutterPdfAdListener = FlutterBoomPdfAdListener;
```
