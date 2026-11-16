import '../../../flavors.dart';

class AppConstants {
  AppConstants._();

  // TODO(all): Sửa lại các giá trị này
  static const String appIOSId = '123456';

  static const String packageName = 'com.example.app';
  static const urlPolicy = 'https://tksoftedge.github.io/privacy-policy.html';
  static const urlTerms = 'https://tksoftedge.github.io/terms.html/';
  static String appName =
      F.appFlavor == Flavor.dev ? 'app name Dev' : 'app name Product';

  // 2 cái này không thay đổi
  static const String appIOSUrl = 'https://apps.apple.com/us/app/id$appIOSId';
  static const String appAndroidUrl =
      'https://play.google.com/store/apps/details?id=$packageName';
}
