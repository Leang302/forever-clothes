import 'package:freezed_annotation/freezed_annotation.dart';

part 'paged_result.freezed.dart';

@freezed
abstract class PagedResult<T> with _$PagedResult<T> {
  const factory PagedResult({
    required List<T> items,
    required int page,
    required bool isLast,
    required int total,
  }) = _PagedResult<T>;
}
