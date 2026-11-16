import 'package:flutter_ads/ads_flutter.dart';
import 'package:flutter_iap/flutter_iap.dart';

import '../../../src/shared/global.dart';
import '../../remote_config/remote_config.dart';
import '../model/ad_config/ad_config.dart';
import 'enum/ad_factory.dart';
import 'native_full_util.dart';

class NativeAdSize {
  const NativeAdSize._();

  static const double large = 280;
  static const double medium = 170;
  static const double smallAd = 61;
}

String get largeNativeAdFactory {
  if (Global.instance.isSuper &&
      RemoteConfigManager.instance.adsRemoteConfig.showTopButton) {
    return AdFactory.topExtraNativeAd.name;
  } else {
    return AdFactory.bottomNormalNativeAd.name;
  }
}

AdUnitsConfig get adUnitsConfig =>
    RemoteConfigManager.instance.adsRemoteConfig.adUnitsConfig;

final nativeFullSplashUtil = NativeFullUtil(
  adConfig: adUnitsConfig.nativeFullSplash,
  factoryId: AdFactory.fullNativeAd.name,
  adKey: 'native_full_splash',
  cached: true,
);

void setEnableAppOpenAd(bool isEnable) {
  if (purchasesManager.isPremium) {
    isEnable = false;
  }
  MyAds.instance.appLifecycleReactor?.setShouldShow(isEnable);
}

Future<void> preloadInterAd(AdUnitConfig config) async {
  if (!purchasesManager.isPremium && config.isEnable) {
    await MyAds.instance.preloadInterstitialAd(
      adId: config.id,
      adId2: config.id2,
      adId2RequestPercentage: config.id2RequestPercentage,
      opacity: config.opacity,
    );
  }
}

Future<void> preloadAppOpenAd(AdUnitConfig config) async {
  if (!purchasesManager.isPremium && config.isEnable) {
    await MyAds.instance.preloadAppOpenAd(
      adId: config.id,
      adId2: config.id2,
      adId2RequestPercentage: config.id2RequestPercentage,
      opacity: config.opacity,
    );
  }
}
