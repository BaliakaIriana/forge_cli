import 'package:forge_cli/src/core/name.dart';
import 'package:test/test.dart';

void main() {
  group('Name', () {
    test('normalises every input casing', () {
      for (final raw in [
        'order detail',
        'OrderDetail',
        'order_detail',
        'order-detail'
      ]) {
        final name = Name(raw);
        expect(name.pascal, 'OrderDetail');
        expect(name.camel, 'orderDetail');
        expect(name.snake, 'order_detail');
        expect(name.kebab, 'order-detail');
      }
    });

    test('splits acronyms', () {
      expect(Name('HTTPClient').snake, 'http_client');
    });

    test('drops a class suffix', () {
      expect(Name('OrdersScreen').withoutSuffix('Screen').pascal, 'Orders');
      expect(Name('GetOrdersUseCase').withoutSuffix('UseCase').snake,
          'get_orders');
      expect(Name('Screen').withoutSuffix('Screen').pascal, 'Screen');
    });

    test('singularises the last word', () {
      expect(Name('orders').singular.pascal, 'Order');
      expect(Name('categories').singular.pascal, 'Category');
      expect(Name('order_addresses').singular.snake, 'order_address');
      expect(Name('status').singular.snake, 'status');
      expect(Name('news_box').singular.snake, 'news_box');
    });

    test('rejects empty and digit-first names', () {
      expect(() => Name('  '), throwsFormatException);
      expect(() => Name('1order'), throwsFormatException);
    });
  });
}
