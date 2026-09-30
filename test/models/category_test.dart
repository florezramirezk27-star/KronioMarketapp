import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/models/category.dart';

void main() {
  group('Category.fromJson', () {
    test('parsea el formato real del backend con _count', () {
      const json = {
        'id': 'cmum4hebc0000aa30eutwp79f',
        'name': 'Hogar',
        'slug': 'hogar',
        'createdAt': '2026-09-29T03:34:26.232Z',
        '_count': {'products': 5},
      };

      final category = Category.fromJson(json);

      expect(category.id, 'cmum4hebc0000aa30eutwp79f');
      expect(category.name, 'Hogar');
      expect(category.slug, 'hogar');
      expect(category.productCount, 5);
    });

    test('productCount es 0 si no viene _count', () {
      final category = Category.fromJson({'id': 'a', 'name': 'X', 'slug': 'x'});

      expect(category.productCount, 0);
    });

    test('productCount es 0 si _count viene vacio', () {
      final category = Category.fromJson({'_count': <String, dynamic>{}});

      expect(category.productCount, 0);
    });

    test('productCount acepta el conteo como string', () {
      final category = Category.fromJson({
        '_count': {'products': '7'},
      });

      expect(category.productCount, 7);
    });

    test('tolera campos ausentes', () {
      final category = Category.fromJson({});

      expect(category.id, '');
      expect(category.name, '');
      expect(category.slug, '');
      expect(category.productCount, 0);
    });
  });
}
