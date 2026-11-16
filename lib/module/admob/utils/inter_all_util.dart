import 'package:flutter_ads/ads_flutter.dart';
import 'package:flutter_iap/flutter_iap.dart';

import '../../../src/config/di/di.dart';
import '../../../src/config/navigation/app_router.dart';
import '../../../src/shared/global.dart';
import '../../../src/shared/helpers/my_completer.dart';
import '../model/ad_config/ad_config.dart';
import '../model/inter_all_config.dart';
import 'utils.dart';

class InterAllUtil {
  InterAllUtil._();

  InterAllConfig config = const InterAllConfig();

  static InterAllUtil instance = InterAllUtil._();

  bool _preloaded = false;

  Future<void> preload() async {
    if (_preloaded) {
      return;
    }
    _preloaded = true;
    if (!purchasesManager.isPremium) {
      await MyAds.instance.preloadInterstitialAd(
        adId: adUnitsConfig.interAll.id,
        adId2: adUnitsConfig.interAll.id2,
        adId2RequestPercentage: adUnitsConfig.interAll.id2RequestPercentage,
        opacity: adUnitsConfig.interAll.opacity,
      );
    }
  }

  Future<void> show({
    bool useInterAll = true,
    bool forceShow = false,
    bool onlySuperVer = false,
    bool showLoading = true,
    required AdUnitConfig adConfig,
  }) async {
    if (onlySuperVer && !Global.instance.isSuper) {
      return;
    }
    if (!adConfig.isEnable) {
      return;
    }
    final usedConfig = useInterAll && adUnitsConfig.interAll.opacity > 0
        ? adUnitsConfig.interAll
        : adConfig = adConfig;
    if (!usedConfig.isEnable) {
      return;
    }
    final completer = MyCompleter();
    MyAds.instance.showInterstitialAd(
      getIt<AppRouter>().navigatorKey.currentContext!,
      adId: usedConfig.id,
      adId2: usedConfig.id2,
      adId2RequestPercentage: usedConfig.id2RequestPercentage,
      forceShow: forceShow,
      showLoading: showLoading,
      adKey: 'interAll',
      adDismissed: () {
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
