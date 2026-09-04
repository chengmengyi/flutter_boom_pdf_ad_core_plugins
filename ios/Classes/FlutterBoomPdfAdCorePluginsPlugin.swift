import Flutter
import UIKit

public class FlutterBoomPdfAdCorePluginsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_boom_pdf_ad_core_plugins", binaryMessenger: registrar.messenger())
    let instance = FlutterBoomPdfAdCorePluginsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "getAndroidId":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
