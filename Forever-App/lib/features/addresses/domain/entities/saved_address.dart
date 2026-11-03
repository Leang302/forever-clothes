import 'package:freezed_annotation/freezed_annotation.dart';

part 'saved_address.freezed.dart';

@freezed
abstract class SavedAddress with _$SavedAddress {
  const factory SavedAddress({
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
  }) = _SavedAddress;
}
