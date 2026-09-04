# flutter_boom_pdf_ad_core_plugins

Provider-neutral ad orchestration for Boom PDF apps. The package owns ad
configuration, loading order, cache, display state, limits and callbacks. It
does not depend on an ad network SDK.

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_boom_pdf_ad_admob_plugins/flutter_boom_pdf_ad_admob_plugins.dart';
import 'package:flutter_boom_pdf_ad_core_plugins/flutter_boom_pdf_ad_core_plugins.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterBoomPdfAdAdmobPlugins.install();

  final ads = FlutterBoomPdfAdCorePlugins.instance;
  await ads.initPlugins(
    distinctId: 'user-id',
    fengKongLogic: () => false,
  );
  await ads.initializeAdmob();
}
```

Legacy configurations with an empty `adPlat` are routed to the `admob`
adapter. New adapters register a unique lowercase `networkId` and implement
`FlutterBoomPdfAdAdapter`.
