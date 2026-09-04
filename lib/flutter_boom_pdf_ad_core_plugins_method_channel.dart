import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_boom_pdf_ad_core_plugins_platform_interface.dart';

/// An implementation of [FlutterBoomPdfAdCorePluginsPlatform] that uses method channels.
class MethodChannelFlutterBoomPdfAdCorePlugins
    extends FlutterBoomPdfAdCorePluginsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_boom_pdf_ad_core_plugins');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<String?> getAndroidId() {
    return methodChannel.invokeMethod<String>('getAndroidId');
  }
}
