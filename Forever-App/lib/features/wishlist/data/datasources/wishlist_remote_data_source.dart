import 'package:dio/dio.dart';

import '../../../../core/network/api_guard.dart';
import '../../../catalog/data/models/product_dto.dart';

class WishlistRemoteDataSource {
  WishlistRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<ProductDto>> list() => guardApi(() async {
    final res = await _dio.get<List<dynamic>>('/api/wishlist');
    return res.data!.map((e) => ProductDto.fromJson(e as Json)).toList();
  });

  Future<ProductDto> add(int productId) => guardApi(
    () async => ProductDto.fromJson(
      (await _dio.post<Json>('/api/wishlist/$productId')).data!,
    ),
  );

  Future<void> remove(int productId) =>
      guardApi(() => _dio.delete<void>('/api/wishlist/$productId'));
}
