import 'package:dio/dio.dart';

import '../../../../core/network/api_guard.dart';
import '../models/order_dto.dart';

class OrderRemoteDataSource {
  OrderRemoteDataSource(this._dio);

  final Dio _dio;

  Future<OrderDto> place(AddressDto address, String paymentMethod) => guardApi(
    () async => OrderDto.fromJson(
      (await _dio.post<Json>(
        '/api/orders',
        data: {'address': address.toJson(), 'paymentMethod': paymentMethod},
      )).data!,
    ),
  );

  Future<List<OrderDto>> list() => guardApi(() async {
    final res = await _dio.get<Json>(
      '/api/orders',
      queryParameters: {'size': 50},
    );
    return (res.data!['content'] as List)
        .map((e) => OrderDto.fromJson(e as Json))
        .toList();
  });

  Future<OrderDto> cancel(int id) => guardApi(
    () async => OrderDto.fromJson(
      (await _dio.post<Json>('/api/orders/$id/cancel')).data!,
    ),
  );
}
