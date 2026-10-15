import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_focus_provider.g.dart';

/// Set by the Home search bar; the Collection screen consumes it and focuses its search field.
@Riverpod(keepAlive: true)
class SearchFocusRequest extends _$SearchFocusRequest {
  @override
  bool build() => false;

  void request() => state = true;

  void consume() => state = false;
}
