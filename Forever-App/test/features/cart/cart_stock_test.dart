import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/core/widgets/quantity_stepper.dart';
import 'package:forever_app/features/auth/domain/entities/app_user.dart';
import 'package:forever_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:forever_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:forever_app/features/cart/domain/entities/cart.dart';
import 'package:forever_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:forever_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:forever_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockCart extends Mock implements CartRepository {}

const _user = AppUser(id: 1, name: 'A', email: 'a@b.c');

Cart _cart(int quantity, int stock) => Cart(
  items: [
    CartLine(
      id: 3,
      productId: 7,
      name: 'Tee',
      price: 10,
      size: 'M',
      quantity: quantity,
      stock: stock,
    ),
  ],
  itemCount: quantity,
  subtotal: 10.0 * quantity,
  deliveryFee: 10,
  total: 10.0 * quantity + 10,
);

void main() {
  late _MockAuth auth;
  late _MockCart cart;

  setUp(() {
    auth = _MockAuth();
    cart = _MockCart();
    when(() => auth.restoreSession()).thenAnswer((_) async => _user);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          cartRepositoryProvider.overrideWithValue(cart),
        ],
        child: const MaterialApp(home: Scaffold(body: CartScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  QuantityStepper stepper(WidgetTester tester) =>
      tester.widget<QuantityStepper>(find.byType(QuantityStepper));

  testWidgets('stepper max is the line stock; at stock "+" is disabled', (
    tester,
  ) async {
    when(() => cart.getCart()).thenAnswer((_) async => _cart(3, 3));
    await pump(tester);
    expect(stepper(tester).max, 3);
    expect(find.byKey(const Key('stock-warning')), findsNothing);
    expect(find.text('Only 3 left'), findsOneWidget); // low-stock hint
    await tester.tap(find.byKey(const Key('line-3-inc')));
    await tester.pump();
    verifyNever(
      () => cart.setQuantity(
        productId: any(named: 'productId'),
        size: any(named: 'size'),
        quantity: any(named: 'quantity'),
      ),
    );
  });

  testWidgets('a line above its stock is flagged and explained at checkout', (
    tester,
  ) async {
    when(() => cart.getCart()).thenAnswer((_) async => _cart(5, 2));
    when(
      () => cart.setQuantity(productId: 7, size: 'M', quantity: 2),
    ).thenAnswer((_) async => _cart(2, 2));
    await pump(tester);

    expect(find.byKey(const Key('stock-warning')), findsOneWidget);
    expect(find.text('Only 2 left — reduce quantity'), findsOneWidget);

    await tester.tap(find.text('Checkout'));
    await tester.pumpAndSettle();
    expect(find.text('Some items are low on stock'), findsOneWidget);
    expect(
      find.textContaining('Only 2 left of Tee in size M (you have 5)'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('fix-stock')));
    await tester.pumpAndSettle();
    verify(
      () => cart.setQuantity(productId: 7, size: 'M', quantity: 2),
    ).called(1);
    expect(find.byKey(const Key('stock-warning')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
