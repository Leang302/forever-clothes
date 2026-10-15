import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/features/catalog/domain/entities/paged_result.dart';
import 'package:forever_app/features/catalog/domain/entities/product.dart';
import 'package:forever_app/features/catalog/domain/entities/product_query.dart';
import 'package:forever_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:forever_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockCatalogRepository extends Mock implements CatalogRepository {}

Product _p(int id) => Product.placeholder.copyWith(id: id, name: 'P$id');

void main() {
  late MockCatalogRepository repo;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(const ProductQuery()));

  setUp(() {
    repo = MockCatalogRepository();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [catalogRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  test('loadMore appends the next page and stops on the last one', () async {
    when(() => repo.search(any(), page: 0)).thenAnswer(
      (_) async =>
          PagedResult(items: [_p(1), _p(2)], page: 0, isLast: false, total: 3),
    );
    when(() => repo.search(any(), page: 1)).thenAnswer(
      (_) async => PagedResult(items: [_p(3)], page: 1, isLast: true, total: 3),
    );

    await container.read(productListProvider.future);
    await container.read(productListProvider.notifier).loadMore();
    await container
        .read(productListProvider.notifier)
        .loadMore(); // already last: no third request

    final page = container.read(productListProvider).value!;
    expect(page.items.map((p) => p.id), [1, 2, 3]);
    expect(page.isLast, isTrue);
    verify(() => repo.search(any(), page: 1)).called(1);
    verifyNever(() => repo.search(any(), page: 2));
  });

  test('changing the query reloads from page 0', () async {
    when(() => repo.search(any(), page: any(named: 'page'))).thenAnswer(
      (_) async => PagedResult(items: [_p(1)], page: 0, isLast: true, total: 1),
    );

    await container.read(productListProvider.future);
    container
        .read(productQueryControllerProvider.notifier)
        .selectCategory('Men');
    await container.read(productListProvider.future);

    final captured = verify(
      () => repo.search(captureAny(), page: 0),
    ).captured.cast<ProductQuery>();
    expect(captured.first.categories, isEmpty);
    expect(captured.last.categories, ['Men']);
  });
}
