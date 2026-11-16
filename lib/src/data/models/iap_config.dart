import 'package:freezed_annotation/freezed_annotation.dart';

part 'iap_config.freezed.dart';
part 'iap_config.g.dart';

@freezed
abstract class IapConfigModel with _$IapConfigModel {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory IapConfigModel({
    // Bật/tắt IAP ở tất cả vị trí
    @Default(true) bool enable,
    // Bật/tắt IAP ở trước màn home
    @Default(true) bool enableBeforeHome,
    // Bật/tắt IAP ở màn home
    @Default(true) bool enableHome,
    // Bật/tắt IAP ở màn setting
    @Default(true) bool enableSetting,
  }) = _IapConfigModel;

  factory IapConfigModel.fromJson(Map<String, dynamic> json) =>
      _$IapConfigModelFromJson(json);
}
