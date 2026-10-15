import 'package:dio/dio.dart';

import '../error/app_exception.dart';

/// Runs a Dio call and converts transport / API errors into [AppException].
Future<T> guardApi<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw AppException.fromDio(e);
  }
}

typedef Json = Map<String, dynamic>;
