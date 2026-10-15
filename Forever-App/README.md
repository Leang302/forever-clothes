# Forever – Flutter app

Native-feeling mobile client for the Forever store (floating pill navigation, rounded cards, bottom sheets, skeleton
loading, haptics). Talks to `../Forever-API`.

## Run

```bash
cd forever_app
flutter pub get
dart run build_runner build          # generates *.g.dart / *.freezed.dart (git-ignored)
flutter run                          # iOS simulator -> http://localhost:8989
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8989   # real phone: your computer's LAN address
```

* Android emulator uses `http://10.0.2.2:8989` automatically; the address can also be changed in **Profile → Server address**.
* Start the API first (`../Forever-API/README.md`). Sign-up / reset codes arrive in Mailpit at http://localhost:8025.
* While editing models or `@riverpod` providers keep `dart run build_runner watch` running.

```bash
flutter analyze && flutter test
```

## Architecture

Feature-first **clean architecture**. Dependencies only point inwards: `presentation → domain ← data`.

```
lib/
├── main.dart                 bootstrap: create TokenStorage + SharedPreferences, ProviderScope overrides
├── app/                      app shell: MaterialApp.router, go_router config, floating nav bar, theme
├── core/                     shared kernel (no feature imports)
│   ├── config/  error/  network/ (Dio + auth/refresh interceptor)  storage/  utils/  widgets/ (design system)
└── features/
    ├── auth/  catalog/  cart/  orders/  profile/  home/  info/
    │   ├── domain/           entities (Freezed) + repository interfaces — pure Dart, no Flutter/Dio
    │   ├── data/             DTOs (Freezed + json_serializable) · remote data sources (Dio) · repository implementations
    │   └── presentation/     Riverpod providers · screens · widgets
```

* **Domain** holds the business model (`Product`, `Cart`, `Order`, `AppUser`…) and `abstract interface class XRepository`.
* **Data** maps API JSON → DTO → entity (`toEntity()`); `AppException` (code, message, field errors) is the only error type
  that leaves this layer.
* **Presentation** talks to repositories only through Riverpod providers, so every layer is replaceable in tests.
* I deliberately did **not** add one use-case class per action: they would just forward to the repository. Add them when a
  flow needs real orchestration (e.g. checkout across cart + payment).

### State management (Riverpod 3 + code generation)

| Provider | Kind | Purpose |
|---|---|---|
| `authController` | `AsyncNotifier<AppUser?>` (keepAlive) | session: restore, login, register, OTP, reset, logout |
| `cartController` | `AsyncNotifier<Cart>` | server cart; reloads when the user changes |
| `ordersController` | `AsyncNotifier<List<Order>>` | history, place, cancel |
| `productQueryController` + `productList` | `Notifier` + paginated `AsyncNotifier` | search / filters / sort and infinite scroll |
| `latestProducts`, `productDetail(id)`, `relatedProducts(id)` | `FutureProvider` (family) | read-only catalogue data |
| `dio`, `baseUrl`, `tokenStorage` | infrastructure | HTTP client rebuilds when the server address changes |

Notifier methods throw `AppException`; screens catch it and show a snackbar, so a failed action never corrupts state.
Automatic retries are off (`ProviderScope(retry: …)`): errors show a manual "Try again".

### Networking & auth

`AuthInterceptor` adds the bearer token and, on a 401, performs a single-flight refresh (tokens rotate) and retries once;
if refresh is rejected it bumps `sessionExpiredProvider` and `authController` drops to logged-out. Tokens live in the
keychain/keystore (`flutter_secure_storage`).

### Routing

`go_router` with a `StatefulShellRoute.indexedStack` (Home · Shop · Cart · Profile keep their own state/scroll) and a
floating navigation bar. Guest-only / protected routes are enforced in `redirect`. **Note:** go_router does not redirect
*pushed* screens, so Login and Verify navigate explicitly after success (covered by `test/app/router_redirect_test.dart`).

## Tooling

| Need | Package |
|---|---|
| State management / DI | `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator` |
| Immutable models, `copyWith`, equality | `freezed` (+ `freezed_annotation`) |
| JSON | `json_serializable` |
| HTTP | `dio` |
| Routing | `go_router` |
| Secure / simple storage | `flutter_secure_storage`, `shared_preferences` |
| Images, loading UI, fonts | `cached_network_image`, `skeletonizer`, `google_fonts` |
| Formatting | `intl` |
| Tests | `flutter_test`, `mocktail` |

`freezed` is pinned to `4.0.0-dev.3`: 4.0 stable needs Dart 3.13 and the 3.x line conflicts with `riverpod_generator`'s
`analyzer`. Move to the stable release once the SDK is on Dart 3.13+. `pinput` was dropped because it does not support
Flutter 3.44's split Material library; `OtpInput` is a small in-house widget.

## Tests

`flutter test` runs 28 tests: formatters, error mapping, DTO → entity mapping, `AuthController` / `CartController` /
pagination with mocked repositories, router redirects driven through the real Login and Verify screens, the OTP widget, profile sheets
and the floating navigation bar.

## Not done

* Stripe / Razorpay (shown as "Coming soon"); only cash on delivery works end to end.
* Android build not verified here: the SDK licences were not accepted (`flutter doctor --android-licenses`).
