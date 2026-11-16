import 'package:freezed_annotation/freezed_annotation.dart';

part 'inter_all_config.freezed.dart';
part 'inter_all_config.g.dart';

@freezed
abstract class InterAllConfig with _$InterAllConfig {
  const factory InterAllConfig({
    @Default(true) bool interSelectRemote,
    @Default(true) bool interCast,
    @Default(true) bool interBack,
    @Default(true) bool interRandom,
    @Default(true) bool interTabHome,
  }) = _InterAllConfig;

  factory InterAllConfig.fromJson(Map<String, dynamic> json) =>
      _$InterAllConfigFromJson(json);
}
