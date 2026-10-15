import 'package:dio/dio.dart';

/// Every failure that reaches the UI is an [AppException] with a user-presentable message.
class AppException implements Exception {
  const AppException(
    this.message, {
    this.code = 'ERROR',
    this.statusCode,
    this.fieldErrors,
  });

  final String message;
  final String code;
  final int? statusCode;
  final Map<String, String>? fieldErrors;

  bool get isNetwork => code == 'NETWORK';
  bool get isUnverifiedEmail => code == 'EMAIL_NOT_VERIFIED';
  bool get isUnauthorized => statusCode == 401;

  /// Maps the API's `{code,message,fieldErrors}` error body (or a transport failure).
  factory AppException.fromDio(DioException e) {
    final body = e.response?.data;
    if (body is Map<String, dynamic>) {
      final fields = (body['fieldErrors'] as Map?)?.map(
        (k, v) => MapEntry('$k', '$v'),
      );
      final message =
          (fields != null && fields.isNotEmpty
                  ? fields.values.first
                  : body['message'])
              as String?;
      return AppException(
        message ?? 'Something went wrong',
        code: (body['code'] as String?) ?? 'ERROR',
        statusCode: e.response?.statusCode,
        fieldErrors: fields,
      );
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const AppException(
          'Cannot reach the server. Check your connection.',
          code: 'NETWORK',
        );
      default:
        return AppException(
          'Unexpected error (${e.response?.statusCode ?? 'no response'})',
          statusCode: e.response?.statusCode,
        );
    }
  }

  @override
  String toString() => message;
}

/// Text to show for any thrown object.
String errorText(Object error) =>
    error is AppException ? error.message : 'Something went wrong';
