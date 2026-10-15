import 'package:dio/dio.dart';

import '../../../../core/network/api_guard.dart';
import '../models/cart_dto.dart';

class CartRemoteDataSource {
  CartRemoteDataSource(this._dio);

  final Dio _dio;

  Future<CartDto> get() => guardApi(
    () async => CartDto.fromJson((await _dio.get<Json>('/api/cart')).data!),
  );

  Future<CartDto> add(int productId, String size) => guardApi(
    () async => CartDto.fromJson(
      (await _dio.post<Json>(
        '/api/cart/items',
        data: {'productId': productId, 'size': size, 'quantity': 1},
      )).data!,
    ),
  );

  Future<CartDto> setQuantity(int productId, String size, int quantity) =>
      guardApi(
        () async => CartDto.fromJson(
          (await _dio.put<Json>(
            '/api/cart/items',
            data: {'productId': productId, 'size': size, 'quantity': quantity},
          )).data!,
        ),
      );

  Future<CartDto> remove(int lineId) => guardApi(
    () async => CartDto.fromJson(
      (await _dio.delete<Json>('/api/cart/items/$lineId')).data!,
    ),
  );
}
