package com.vtn.global.base.flutter

import android.content.Intent
import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.example.bindinghelper.BindingNotificationManager
import com.example.bindinghelper.NotificationCallHandler
import com.vtn.global.base.flutter.ad_factory.*
import com.vtn.global.base.flutter.enum.ButtonPosition
import com.vtn.global.base.flutter.util.method_handler.PermissionHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import com.adjust.helper.AdjustChannel

class MainActivity : FlutterActivity() {
    private var notificationCallHandler: NotificationCallHandler? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        BindingNotificationManager.init(
            this,
            MainActivity::class.java,
            R.drawable.ic_notification,
        )
        BindingNotificationManager.onRestart(this, intent, onNotificationClicked = {
            notificationCallHandler?.channel?.invokeMethod(
                "openNotify",
                mapOf(
                    "fromSplash" to true,
                ),
            )
        })

    }


    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        BindingNotificationManager.onRestart(this, intent, onNotificationClicked = {
            notificationCallHandler?.channel?.invokeMethod(
                "openNotify",
                mapOf(
                    "fromSplash" to false,
                ),
            )
        })
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notificationCallHandler = NotificationCallHandler(
            context = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger
        )
        AdjustChannel(this, flutterEngine.dartExecutor.binaryMessenger)

        PermissionHandler(
            context = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger
        )

        val topExtra = ExtraNativeAd(context, buttonPosition = ButtonPosition.Top)
        val bottomExtra = ExtraNativeAd(context, buttonPosition = ButtonPosition.Bottom)
        val topNormal = NormalNativeAd(context, buttonPosition = ButtonPosition.Top)
        val bottomNormal = NormalNativeAd(context, buttonPosition = ButtonPosition.Bottom)
        val homeNative = HomeNativeAd(context)
        val smallNative = SmallNativeAd(context)
        val fullNative = FullNativeAd(context)
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "topExtraNativeAd",
            topExtra
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "bottomExtraNativeAd",
            bottomExtra
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "topNormalNativeAd",
            topNormal
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "bottomNormalNativeAd",
            bottomNormal
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "homeNativeAd",
            homeNative
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "smallNativeAd",
            smallNative
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "fullNativeAd",
            fullNative
        )
        CachedAdNativeAdFactoryRegistry.register("topNormalNativeAd", topNormal)
        CachedAdNativeAdFactoryRegistry.register("bottomNormalNativeAd", bottomNormal)
        CachedAdNativeAdFactoryRegistry.register("topExtraNativeAd", topExtra)
        CachedAdNativeAdFactoryRegistry.register("bottomExtraNativeAd", bottomExtra)
        CachedAdNativeAdFactoryRegistry.register("homeNativeAd", homeNative)
        CachedAdNativeAdFactoryRegistry.register("smallNativeAd", smallNative)
        CachedAdNativeAdFactoryRegistry.register("fullNativeAd", fullNative)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "topExtraNativeAd")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "bottomExtraNativeAd")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "topNormalNativeAd")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "bottomNormalNativeAd")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "homeNativeAd")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "smallNativeAd")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "fullNativeAd")
        CachedAdNativeAdFactoryRegistry.unregister("topNormalNativeAd")
        CachedAdNativeAdFactoryRegistry.unregister("bottomNormalNativeAd")
        CachedAdNativeAdFactoryRegistry.unregister("topExtraNativeAd")
        CachedAdNativeAdFactoryRegistry.unregister("bottomExtraNativeAd")
        CachedAdNativeAdFactoryRegistry.unregister("homeNativeAd")
        CachedAdNativeAdFactoryRegistry.unregister("smallNativeAd")
        CachedAdNativeAdFactoryRegistry.unregister("fullNativeAd")
    }
}
