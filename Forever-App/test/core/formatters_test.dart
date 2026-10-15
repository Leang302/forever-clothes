import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/core/utils/formatters.dart';

void main() {
  test('formatPrice drops decimals for whole amounts only', () {
    expect(formatPrice(100), r'$100');
    expect(formatPrice(19.99), r'$19.99');
  });

  test('formatMoney always shows two decimals', () {
    expect(formatMoney(610), r'$610.00');
  });

  test('formatDate', () {
    expect(formatDate(DateTime(2026, 10, 9)), '9 Oct 2026');
  });
}
