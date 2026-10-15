import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/core/error/app_exception.dart';

DioException _error({
  Object? body,
  int? status,
  DioExceptionType type = DioExceptionType.badResponse,
}) {
  final request = RequestOptions(path: '/x');
  return DioException(
    requestOptions: request,
    type: type,
    response: status == null
        ? null
        : Response(requestOptions: request, statusCode: status, data: body),
  );
}

void main() {
  test('maps the API error body', () {
    final e = AppException.fromDio(
      _error(
        status: 403,
        body: {'code': 'EMAIL_NOT_VERIFIED', 'message': 'Verify first'},
      ),
    );
    expect(e.code, 'EMAIL_NOT_VERIFIED');
    expect(e.message, 'Verify first');
    expect(e.isUnverifiedEmail, isTrue);
  });

  test('prefers the first field error for validation failures', () {
    final e = AppException.fromDio(
      _error(
        status: 400,
        body: {
          'code': 'VALIDATION_FAILED',
          'message': 'Validation failed',
          'fieldErrors': {'password': 'Password must be 8-72 characters'},
        },
      ),
    );
    expect(e.message, 'Password must be 8-72 characters');
  });

  test('transport failures become a network error', () {
    final e = AppException.fromDio(
      _error(type: DioExceptionType.connectionError),
    );
    expect(e.isNetwork, isTrue);
  });

  test('errorText hides unknown exceptions', () {
    expect(errorText(StateError('boom')), 'Something went wrong');
    expect(errorText(const AppException('Nope')), 'Nope');
  });
}
