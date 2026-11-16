import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ads/ads_flutter.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_iap/flutter_iap.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:upgrader/upgrader.dart';

import '../../../module/adjust/adjust_util.dart';
import '../../../module/admob/model/ad_config/ad_config.dart';
import '../../../module/admob/utils/reload_ad_util.dart';
import '../../../module/admob/utils/utils.dart';
import '../../../module/remote_config/remote_config.dart';
import '../../../module/tracking_screen/loggable_widget.dart';
import '../../config/di/di.dart';
import '../../config/navigation/app_router.dart';
import '../../config/theme/palette.dart';
import '../../gen/assets.gen.dart';
import '../../shared/constants/app_constants.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/global.dart';
import '../../shared/helpers/admob_consent_util.dart';
import '../../shared/helpers/logger_utils.dart';
import '../../shared/helpers/my_completer.dart';
import '../../shared/helpers/permission_util.dart';
import '../../shared/helpers/shortcut_utils.dart';
import '../../shared/widgets/custom_fade_in_image.dart';
import 'update_dialog.dart';

@RoutePage()
class SplashScreen extends StatefulLoggableWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController loadingController = AnimationController(
    vsync: this,
    value: 0,
    duration: const Duration(seconds: 1),
  );

  final ValueNotifier<int> _progressPercent = ValueNotifier(0);

  final Upgrader upgrader = Upgrader(
    // TODO(all): uncomment to check upgrader
    // debugDisplayAlways: true,
    debugLogging: true,
  );

  @override
  void initState() {
    super.initState();
    loadingController.addListener(_onProgressChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _onProgressChanged() {
    final newPercent = (loadingController.value * 100).toInt();
    if (_progressPercent.value != newPercent) {
      _progressPercent.value = newPercent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomFadeInImage(
                    image: Assets.images.logo.logo.provider(),
                    width: 145.r,
                    height: 145.r,
                    fit: BoxFit.contain,
                  ),
                  16.verticalSpace,
                  Text(
                    AppConstants.appName,
                    style: TextStyle(
                      color: context.colorScheme.primary,
                      fontSize: 22.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _progressPercent,
                      builder: (context, percent, _) => Text(
                        context.l10n.loading(percent.toString()),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF627689),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  RepaintBoundary(
                    child: SizedBox(
                      width: 200,
                      height: 6,
                      child: AnimatedBuilder(
                        animation: loadingController,
                        builder: (context, _) => LinearProgressIndicator(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(4),
                          ),
                          color: Palette.primary,
                          value: loadingController.value.clamp(0.0, 0.99),
                          backgroundColor: const Color(0xffd1d1d1),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              15.verticalSpace,
              Text(
                context.l10n.thisActionCanContainAds,
                style: const TextStyle(color: Palette.primary),
              ),
            ],
          ),
          40.verticalSpace,
        ],
      ),
    );
  }

  @override
  void dispose() {
    ShortcutUtils.instance.isSplash = false;
    loadingController.removeListener(_onProgressChanged);
    loadingController.dispose();
    _progressPercent.dispose();
    Global.instance.didLeaveSplash = true;
    initAdOpen();
    super.dispose();
  }

  Future<void> _init() async {
    if (!kDebugMode) {
      initCrashlytics();
    }
    loadingController.animateTo(0.16);
    await AdmobConsentUtil.initialize();
    loadingController.animateTo(.45);
    final result = await Future.wait([
      ShortcutUtils.instance.initialize(),
      configureAd(),
      PermissionUtil.instance.requestPermissionNotificationDefault(),
      upgrader.initialize(),
    ]);
    // vào app bằng shortcut
    if (result[0]) {
      loadingController.animateTo(0.99);
      await showInterSplashUninstall();
      ShortcutUtils.instance.handleShortcut();

      return;
    }
    loadingController.animateTo(.71);
    await initUpgrader();
    loadingController.animateTo(0.99);
    PermissionUtil.instance.checkAllPermissions();
    ReloadAdUtil.instance.loadAd();
    await showSplashAd();
    goToNextScreen();
  }

  void initCrashlytics() {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } on Exception catch (e) {
        logger.e(e);
      }
      return true;
    };
  }

  Future<bool> configureAd() async {
    final bool isShowAd = RemoteConfigManager.instance.enableAllAds;
    //init and show ad
    if (mounted && isShowAd) {
      await MyAds.instance.initialize(
        navigatorKey: getIt<AppRouter>().navigatorKey,
        enableShowRateLogger: true,
        interIntervalInSeconds:
            RemoteConfigManager.instance.adsRemoteConfig.interInterval,
        id2RequestTimeout:
            RemoteConfigManager.instance.adsRemoteConfig.id2RequestTimeout,
      );
      MyAds.instance.events.listen((event) {
        if (event.status.isPaid &&
            event.valueMicros != null &&
            event.currencyCode != null) {
          final value = event.valueMicros! / 1000000;
          AdjustUtil.instance.trackAdRevenue(
            value: value,
            currencyCode: event.currencyCode!,
          );
        }
      });
    }
    return true;
  }

  Future<void> initAdOpen() async {
    //set up ad open
    if (adUnitsConfig.openOnResume.isEnable) {
      MyAds.instance.initAppOpenAd(
        appOpenAdUnitId: adUnitsConfig.openOnResume.id,
        appOpenAdUnitId2: adUnitsConfig.openOnResume.id2,
        adId2RequestPercentage: adUnitsConfig.openOnResume.id2RequestPercentage,
        opacity: adUnitsConfig.openOnResume.opacity,
      );
    }
  }

  Future<void> goToNextScreen() async {
    if (purchasesManager.isPremium) {
      context.replaceRoute(const HomeRoute());
    }
    context.replaceRoute(LanguageRoute(isFirst: true));
  }

  Future<void> initUpgrader() async {
    final Completer completer = Completer();
    final bool forceUpdate =
        RemoteConfigManager.instance.appConfig.isForceUpdate;
    if (!upgrader.shouldDisplayUpgrade()) {
      completer.complete();
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: UpdateDialog(
            upgrader: upgrader,
            showLater: !forceUpdate,
            onLater: completer.complete,
          ),
        ),
      );
    }
    return completer.future;
  }

  void configureEasyLoading() {
    EasyLoading.instance
      ..loadingStyle = EasyLoadingStyle.custom
      ..indicatorWidget = const CircularProgressIndicator(
        color: Palette.primary,
        strokeCap: StrokeCap.round,
        strokeWidth: 6,
      )
      ..indicatorColor = Palette.primary
      ..maskType = EasyLoadingMaskType.black
      ..backgroundColor = Colors.transparent
      ..boxShadow = []
      ..textColor = Palette.primary
      ..dismissOnTap = false;
    Global.instance.initEasyLoading = true;
  }

  Future<void> showSplashAd() async {
    final useInterAd = RemoteConfigManager.instance.appConfig.useInterSplash;
    final adConfig =
        useInterAd ? adUnitsConfig.interSplash : adUnitsConfig.openSplash;
    if (!adConfig.isEnable) {
      return;
    }
    final completer = MyCompleter();
    if (useInterAd) {
      await preloadInterAd(adConfig);
    } else {
      await preloadAppOpenAd(adConfig);
    }
    MyAds.instance.showSplashAd(
      getIt<AppRouter>().navigatorKey.currentContext!,
      adId: adConfig.id,
      adId2: adConfig.id2,
      useInterAd: useInterAd,
      adId2RequestPercentage: adConfig.id2RequestPercentage,
      onShowed: () {
        completer.complete();
      },
      onFailed: () {
        completer.complete();
      },
      onNoInternet: () {
        completer.complete();
      },
    );
    return completer.future;
  }

  Future<void> showInterSplashUninstall() async {
    if (!adUnitsConfig.interSplashUninstall.isEnable) {
      return;
    }
    final completer = Completer();
    await preloadInterAd(adUnitsConfig.interSplashUninstall);
    MyAds.instance.showSplashAd(
      getIt<AppRouter>().navigatorKey.currentContext!,
      adId: adUnitsConfig.interSplashUninstall.id,
      adId2: adUnitsConfig.interSplashUninstall.id2,
      adId2RequestPercentage:
          adUnitsConfig.interSplashUninstall.id2RequestPercentage,
      onShowed: () {
        nativeFullSplashUtil.show();
        completer.complete();
      },
      onFailed: () {
        completer.complete();
      },
      onNoInternet: () {
        completer.complete();
      },
    );
    return completer.future;
  }
}
