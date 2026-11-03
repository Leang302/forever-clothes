import 'package:dio/dio.dart';

import '../../../../core/network/api_guard.dart';
import '../models/address_dto.dart';

class AddressRemoteDataSource {
  AddressRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<AddressDto>> list() => guardApi(() async {
    final res = await _dio.get<List<dynamic>>('/api/users/me/addresses');
    return res.data!.map((e) => AddressDto.fromJson(e as Json)).toList();
  });

  Future<AddressDto> add({
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
  }) => guardApi(() async {
    final res = await _dio.post<Json>(
      '/api/users/me/addresses',
      data: {
        'label': label,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'street': street,
        'city': city,
        'state': state,
        'zipcode': zipcode,
        'country': country,
        'phone': phone,
      },
    );
    return AddressDto.fromJson(res.data!);
  });

  Future<void> remove(int addressId) =>
      guardApi(() => _dio.delete<void>('/api/users/me/addresses/$addressId'));
}
