import 'package:dio/dio.dart';

import '../../../../core/network/api_guard.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/khqr_payment.dart';
import '../models/checkout_options_dto.dart';
import '../models/order_dto.dart';

class OrderRemoteDataSource {
  OrderRemoteDataSource(this._dio);

  final Dio _dio;

  Json _placeOrderBody(
    AddressDto address,
    String paymentMethod, {
    String? couponCode,
    String? shippingMethod,
    List<int>? cartItemIds,
  }) => {
    'address': address.toJson(),
    'paymentMethod': paymentMethod,
    if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
    if (shippingMethod != null) 'shippingMethod': shippingMethod,
    if (cartItemIds != null && cartItemIds.isNotEmpty)
      'cartItemIds': cartItemIds,
  };

  Future<OrderDto> place(
    AddressDto address,
    String paymentMethod, {
    String? couponCode,
    String? shippingMethod,
    List<int>? cartItemIds,
  }) => guardApi(
    () async => OrderDto.fromJson(
      (await _dio.post<Json>(
        '/api/orders',
        data: _placeOrderBody(
          address,
          paymentMethod,
          couponCode: couponCode,
          shippingMethod: shippingMethod,
          cartItemIds: cartItemIds,
        ),
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

  Future<OrderDto> get(int id) => guardApi(
    () async =>
        OrderDto.fromJson((await _dio.get<Json>('/api/orders/$id')).data!),
  );

  Future<OrderDto> cancel(int id) => guardApi(
    () async => OrderDto.fromJson(
      (await _dio.post<Json>('/api/orders/$id/cancel')).data!,
    ),
  );

  Future<KhqrPayment> khqrCheckout(
    AddressDto address, {
    String? couponCode,
    String? shippingMethod,
    List<int>? cartItemIds,
  }) => guardApi(() async {
    final json = (await _dio.post<Json>(
      '/api/khqr/checkout',
      data: _placeOrderBody(
        address,
        'KHQR',
        couponCode: couponCode,
        shippingMethod: shippingMethod,
        cartItemIds: cartItemIds,
      ),
    )).data!;
    return KhqrPayment(
      orderId: json['orderId'] as int,
      qrImage: json['qrImage'] as String,
      amount: doubleFromJson(json['amount']),
      currency: json['currency'] as String,
      merchantName: json['merchantName'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  });

  /// Whether Bakong has the payment for the order.
  Future<bool> verifyKhqr(int orderId) => guardApi(
    () async =>
        (await _dio.post<Json>('/api/khqr/$orderId/verify')).data!['paid']
            as bool,
  );

  /// Cancels the order unless it was already paid; returns whether it was paid.
  Future<bool> cancelKhqr(int orderId) => guardApi(
    () async =>
        (await _dio.post<Json>('/api/khqr/$orderId/cancel')).data!['paid']
            as bool,
  );

  Future<CheckoutOptionsDto> checkoutOptions() => guardApi(
    () async => CheckoutOptionsDto.fromJson(
      (await _dio.get<Json>('/api/checkout/options')).data!,
    ),
  );

  /// Previews a coupon's discount for [subtotal]; throws if the code is invalid or doesn't apply.
  Future<CouponPreviewDto> checkCoupon(String code, double subtotal) =>
      guardApi(
        () async => CouponPreviewDto.fromJson(
          (await _dio.post<Json>(
            '/api/checkout/coupon',
            data: {'code': code, 'subtotal': subtotal},
          )).data!,
        ),
      );
}
