import 'dart:io';

typedef FullAdCallback =
    void Function(
      bool isFullAd,
      String? network,
      bool fromCache,
      bool fromLib,
      bool fromApi,
    );

abstract class PlatformAdOption {
  PlatformAdOption({
    this.impressionToken,
    this.event80Token,
    this.fullAdCallback,
  });

  final String? impressionToken;
  final String? event80Token;
  final FullAdCallback? fullAdCallback;
}

class AndroidAdOptions extends PlatformAdOption {
  AndroidAdOptions({
    super.impressionToken,
    super.fullAdCallback,
    super.event80Token,
  });
}

class IOSAdOptions extends PlatformAdOption {
  IOSAdOptions({
    super.impressionToken,
    super.fullAdCallback,
    super.event80Token,
  });
}

class AdOptions {
  AdOptions({this.androidAdOptions, this.iosAdOptions});

  final AndroidAdOptions? androidAdOptions;
  final IOSAdOptions? iosAdOptions;

  String? get impressionToken =>
      (Platform.isAndroid ? androidAdOptions : iosAdOptions)?.impressionToken;

  String? get event80Token =>
      (Platform.isAndroid ? androidAdOptions : iosAdOptions)?.event80Token;

  FullAdCallback? get fullAdCallback =>
      (Platform.isAndroid ? androidAdOptions : iosAdOptions)?.fullAdCallback;
}
