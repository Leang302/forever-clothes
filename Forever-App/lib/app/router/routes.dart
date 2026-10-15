abstract final class Routes {
  static const home = '/';
  static const collection = '/collection';
  static const cart = '/cart';
  static const profile = '/profile';

  static const product = '/product/:id';
  static String productPath(int id) => '/product/$id';

  static const checkout = '/checkout';
  static const orders = '/orders';

  static const login = '/login';
  static const register = '/register';
  static const verifyEmail = '/verify-email';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';

  static const about = '/about';
  static const contact = '/contact';

  /// Screens only reachable while logged out; a logged-in user is bounced away from them.
  static const authFlow = {
    login,
    register,
    verifyEmail,
    forgotPassword,
    resetPassword,
  };

  /// Screens that need an account.
  static const protected = {checkout, orders};

  static String loginWithRedirect(String redirect) =>
      '$login?redirect=${Uri.encodeComponent(redirect)}';
}
