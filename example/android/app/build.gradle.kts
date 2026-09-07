plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.boom.pdf.ad.core.flutter_boom_pdf_ad_core_plugins_example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.b03pdf"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // TradPlus 15.4.0.1：海外版 Exchange + 聚合平台 Adapter。
    // Adapter 自身不传递三方广告 SDK，下面复用 AdMob mediation 依赖带入的
    // Google Ads / Pangle / AppLovin / Meta / Mintegral SDK，并保持版本一致。
    implementation("com.tradplusad:tp_exchange:40.15.4.0.1")
    implementation("com.tradplusad:tradplus-googlex:2.15.4.0.1")
    implementation("com.tradplusad:tradplus-pangle:19.15.4.0.1")
    implementation("com.tradplusad:tradplus-applovin:9.15.4.0.1")
    implementation("com.tradplusad:tradplus-facebook:1.15.4.0.1")
    implementation("com.tradplusad:tradplus-mintegralx_overseas:18.15.4.0.1")

    // AdMob mediation；这些依赖同时带入上面 TradPlus Adapter 所需的三方 SDK。
    implementation("com.google.ads.mediation:applovin:13.5.1.0")
    implementation("com.google.ads.mediation:facebook:6.21.0.1")
    implementation("com.google.ads.mediation:mintegral:17.0.51.0")
    implementation("com.google.ads.mediation:pangle:7.8.5.2.0")
    implementation("com.google.ads.mediation:vungle:7.6.2.0")
    implementation("com.unity3d.ads:unity-ads:4.16.5")
    implementation("com.google.ads.mediation:unity:4.16.5.0")
    implementation("com.google.ads.mediation:ironsource:9.3.0.1")

}
