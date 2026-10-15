import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/app_user.dart';

part 'user_dto.freezed.dart';
part 'user_dto.g.dart';

@freezed
abstract class UserDto with _$UserDto {
  const factory UserDto({
    required int id,
    required String name,
    required String email,
    String? phone,
    required String role,
  }) = _UserDto;

  factory UserDto.fromJson(Map<String, dynamic> json) =>
      _$UserDtoFromJson(json);
}

extension UserDtoMapper on UserDto {
  AppUser toEntity() => AppUser(
    id: id,
    name: name,
    email: email,
    phone: phone,
    isAdmin: role == 'ADMIN',
  );
}
