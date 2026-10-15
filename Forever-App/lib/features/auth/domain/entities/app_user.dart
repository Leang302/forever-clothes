import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required int id,
    required String name,
    required String email,
    String? phone,
    @Default(false) bool isAdmin,
  }) = _AppUser;
}
