import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/app/shell/floating_nav_bar.dart';
import 'package:forever_app/features/cart/presentation/providers/cart_providers.dart';

void main() {
  testWidgets('shows the selected label, a cart badge, and reports taps', (
    tester,
  ) async {
    var tapped = -1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cartCountProvider.overrideWithValue(3)],
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: FloatingNavBar(
              currentIndex: 0,
              onSelected: (i) => tapped = i,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Home'),
      findsOneWidget,
    ); // only the selected destination shows its label
    expect(find.text('Shop'), findsNothing);
    expect(find.text('3'), findsOneWidget); // cart badge

    await tester.tap(find.bySemanticsLabel('Profile'));
    expect(tapped, 3);
  });
}
