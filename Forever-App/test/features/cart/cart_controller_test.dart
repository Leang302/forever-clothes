import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/features/auth/domain/entities/app_user.dart';
import 'package:forever_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:forever_app/features/cart/domain/entities/cart.dart';
import 'package:forever_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:forever_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockCartRepository extends Mock implements CartRepository {}

const _line = CartLine(
  id: 1,
  productId: 7,
  name: 'Tee',
  price: 100,
  size: 'M',
  quantity: 2,
);
const _cart = Cart(
  items: [_line],
  itemCount: 2,
  subtotal: 200,
  deliveryFee: 10,
  total: 210,
);

void main() {
  late MockCartRepository repo;

  ProviderContainer container({AppUser? user}) {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        cartRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWithValue(user),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => repo = MockCartRepository());

  test('is empty and never calls the API while logged out', () async {
    final c = container();
    expect(await c.read(cartControllerProvider.future), Cart.empty);
    verifyNever(() => repo.getCart());
  });

  test(
    'loads the cart for a logged-in user and exposes the item count',
    () async {
      when(() => repo.getCart()).thenAnswer((_) async => _cart);
      final c = container(
        user: const AppUser(id: 1, name: 'A', email: 'a@b.c'),
      );

      await c.read(cartControllerProvider.future);
      expect(c.read(cartCountProvider), 2);
    },
  );

  test(
    'changing a quantity replaces the state with the server response',
    () async {
      when(() => repo.getCart()).thenAnswer((_) async => _cart);
      const updated = Cart(
        items: [
          CartLine(
            id: 1,
            productId: 7,
            name: 'Tee',
            price: 100,
            size: 'M',
            quantity: 3,
          ),
        ],
        itemCount: 3,
        subtotal: 300,
        deliveryFee: 10,
        total: 310,
      );
      when(
        () => repo.setQuantity(productId: 7, size: 'M', quantity: 3),
      ).thenAnswer((_) async => updated);
      final c = container(
        user: const AppUser(id: 1, name: 'A', email: 'a@b.c'),
      );
      await c.read(cartControllerProvider.future);

      await c.read(cartControllerProvider.notifier).setQuantity(_line, 3);
      expect(c.read(cartControllerProvider).value, updated);
    },
  );
}
