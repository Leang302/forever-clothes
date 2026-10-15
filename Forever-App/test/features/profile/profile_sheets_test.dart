import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/core/storage/storage_providers.dart';
import 'package:forever_app/core/storage/token_storage.dart';
import 'package:forever_app/features/auth/domain/entities/app_user.dart';
import 'package:forever_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:forever_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:forever_app/features/profile/presentation/profile_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _user = AppUser(id: 1, name: 'Web Tester', email: 'webqa@example.com');

void main() {
  late MockAuthRepository auth;

  setUp(() {
    auth = MockAuthRepository();
    when(() => auth.restoreSession()).thenAnswer((_) async => _user);
  });

  Future<void> pumpProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(
      900,
      2200,
    ); // tall enough for the whole profile list
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          sharedPreferencesProvider.overrideWithValue(prefs),
          tokenStorageProvider.overrideWithValue(TokenStorage()),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('edit profile sheet saves and closes without framework errors', (
    tester,
  ) async {
    when(
      () => auth.updateProfile(
        name: any(named: 'name'),
        phone: any(named: 'phone'),
      ),
    ).thenAnswer((_) async => _user.copyWith(phone: '0987654321'));
    await pumpProfile(tester);

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone'),
      '0987654321',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Save'), findsNothing); // sheet closed
    expect(
      find.text('0987654321'),
      findsOneWidget,
    ); // profile card shows the new phone
    verify(
      () => auth.updateProfile(name: 'Web Tester', phone: '0987654321'),
    ).called(1);
  });

  testWidgets('change password sheet submits and closes', (tester) async {
    when(
      () => auth.changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async {});
    await pumpProfile(tester);

    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      'old-pass',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password (min 8)'),
      'new-pass-123',
    );
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Update password'), findsNothing);
  });

  testWidgets(
    'server address dialog saves the new address without framework errors',
    (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.text('Server address'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'http://192.168.1.10:8989/',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('http://192.168.1.10:8989'),
        findsOneWidget,
      ); // trailing slash trimmed, shown in the tile
    },
  );
}
