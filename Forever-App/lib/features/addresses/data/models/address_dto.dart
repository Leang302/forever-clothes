import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/saved_address.dart';

part 'address_dto.freezed.dart';
part 'address_dto.g.dart';

@freezed
abstract class AddressDto with _$AddressDto {
  const factory AddressDto({
    required int id,
    required String label,
    required String firstName,
    required String lastName,
    required String email,
    required String street,
    required String city,
    required String state,
    required String zipcode,
    required String country,
    required String phone,
  }) = _AddressDto;

  factory AddressDto.fromJson(Map<String, dynamic> json) =>
      _$AddressDtoFromJson(json);
}

extension AddressDtoMapper on AddressDto {
  SavedAddress toEntity() => SavedAddress(
    id: id,
    label: label,
    firstName: firstName,
    lastName: lastName,
    email: email,
    street: street,
    city: city,
    state: state,
    zipcode: zipcode,
    country: country,
    phone: phone,
  );
}
