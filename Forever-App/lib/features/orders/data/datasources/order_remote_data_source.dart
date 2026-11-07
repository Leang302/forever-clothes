import 'package:dio/dio.dart';

import '../../../../core/network/api_guard.dart';
import '../../../../core/network/auth_interceptor.dart';
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
    String? idempotencyKey,
  }) => {
    'address': address.toJson(),
    'paymentMethod': paymentMethod,
    if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
    'shippingMethod': ?shippingMethod,
    if (cartItemIds != null && cartItemIds.isNotEmpty)
      'cartItemIds': cartItemIds,
    'idempotencyKey': ?idempotencyKey,
  };

  Future<OrderDto> place(
    AddressDto address,
    String paymentMethod, {
    String? couponCode,
    String? shippingMethod,
    List<int>? cartItemIds,
    String? idempotencyKey,
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
          idempotencyKey: idempotencyKey,
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
    String? idempotencyKey,
  }) => guardApi(() async {
    final json = (await _dio.post<Json>(
      '/api/khqr/checkout',
      data: _placeOrderBody(
        address,
        'KHQR',
        couponCode: couponCode,
        shippingMethod: shippingMethod,
        cartItemIds: cartItemIds,
        idempotencyKey: idempotencyKey,
      ),
    )).data!;
    return KhqrPayment(
      orderId: json['orderId'] as int,
      qrImage: json['qrImage'] as String,
      amount: doubleFromJson(json['amount']),
      currency: json['currency'] as String,
      merchantName: json['merchantName'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      qrString: json['qrString'] as String?,
      guestAccessToken: json['guestAccessToken'] as String?,
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

  // ---- A guest's own order: authorised ONLY by its X-Order-Access token
  // (no login, no guest-session header, no refresh on failure).

  static const orderAccessHeader = 'X-Order-Access';

  static Options _orderAccess(String accessToken) => Options(
    extra: {AuthInterceptor.skipAuth: true},
    headers: {orderAccessHeader: accessToken},
  );

  Future<OrderDto> getGuestOrder(int id, String accessToken) => guardApi(
    () async => OrderDto.fromJson(
      (await _dio.get<Json>(
        '/api/guest-orders/$id',
        options: _orderAccess(accessToken),
      )).data!,
    ),
  );

  Future<OrderDto> cancelGuestOrder(int id, String accessToken) => guardApi(
    () async => OrderDto.fromJson(
      (await _dio.post<Json>(
        '/api/guest-orders/$id/cancel',
        options: _orderAccess(accessToken),
      )).data!,
    ),
  );

  Future<bool> verifyGuestKhqr(int orderId, String accessToken) => guardApi(
    () async =>
        (await _dio.post<Json>(
              '/api/guest-orders/$orderId/khqr/verify',
              options: _orderAccess(accessToken),
            )).data!['paid']
            as bool,
  );

  Future<bool> cancelGuestKhqr(int orderId, String accessToken) => guardApi(
    () async =>
        (await _dio.post<Json>(
              '/api/guest-orders/$orderId/khqr/cancel',
              options: _orderAccess(accessToken),
            )).data!['paid']
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
