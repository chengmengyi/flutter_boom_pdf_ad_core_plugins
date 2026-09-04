import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_boom_pdf_ad_core_plugins_method_channel.dart';

abstract class FlutterBoomPdfAdCorePluginsPlatform extends PlatformInterface {
  /// Constructs a FlutterBoomPdfAdCorePluginsPlatform.
  FlutterBoomPdfAdCorePluginsPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterBoomPdfAdCorePluginsPlatform _instance =
      MethodChannelFlutterBoomPdfAdCorePlugins();

  /// The default instance of [FlutterBoomPdfAdCorePluginsPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterBoomPdfAdCorePlugins].
  static FlutterBoomPdfAdCorePluginsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterBoomPdfAdCorePluginsPlatform] when
  /// they register themselves.
  static set instance(FlutterBoomPdfAdCorePluginsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> getAndroidId() {
    throw UnimplementedError('getAndroidId() has not been implemented.');
  }
}
