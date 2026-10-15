import 'package:dio/dio.dart';

import '../../../../core/network/api_guard.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../models/filters_dto.dart';
import '../models/product_dto.dart';
import '../models/product_page_dto.dart';

class CatalogRemoteDataSource {
  CatalogRemoteDataSource(this._dio);

  final Dio _dio;

  static final _public = Options(extra: {AuthInterceptor.skipAuth: true});

  Future<ProductPageDto> search({
    required String search,
    required List<String> categories,
    required List<String> subCategories,
    required String sort,
    required int page,
    required int size,
  }) => guardApi(() async {
    final res = await _dio.get<Json>(
      '/api/products',
      options: _public,
      queryParameters: {
        if (search.trim().isNotEmpty) 'q': search.trim(),
        if (categories.isNotEmpty) 'category': categories,
        if (subCategories.isNotEmpty) 'subCategory': subCategories,
        'sort': sort,
        'page': page,
        'size': size,
      },
    );
    return ProductPageDto.fromJson(res.data!);
  });

  Future<FiltersDto> filters() => guardApi(
    () async => FiltersDto.fromJson(
      (await _dio.get<Json>('/api/products/filters', options: _public)).data!,
    ),
  );

  Future<List<ProductDto>> latest(int limit) =>
      _list('/api/products/latest', limit);

  Future<List<ProductDto>> bestsellers(int limit) =>
      _list('/api/products/bestsellers', limit);

  Future<List<ProductDto>> related(int id, int limit) =>
      _list('/api/products/$id/related', limit);

  Future<ProductDto> product(int id) => guardApi(
    () async => ProductDto.fromJson(
      (await _dio.get<Json>('/api/products/$id', options: _public)).data!,
    ),
  );

  Future<List<ProductDto>> _list(String path, int limit) => guardApi(() async {
    final res = await _dio.get<List<dynamic>>(
      path,
      options: _public,
      queryParameters: {'limit': limit},
    );
    return res.data!.map((e) => ProductDto.fromJson(e as Json)).toList();
  });
}
