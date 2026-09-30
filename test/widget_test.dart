import 'package:flutter_test/flutter_test.dart';

import 'package:kronio_app/services/cart_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CartService carga vacío', () async {
    final cart = await CartService.load();
    expect(cart.isEmpty, isTrue);
    expect(cart.totalItems, 0);
  });
}