import 'dart:async';
import 'dart:math';

// --- Моделі даних ---

class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  @override
  String toString() => 'User(id: $id, name: "$name", email: "$email")';
}

class Product {
  final int id;
  final String title;
  final double price;

  Product({required this.id, required this.title, required this.price});

  @override
  String toString() => '$title — ${price.toStringAsFixed(2)} грн';
}

class Order {
  final String orderId;
  final DateTime date;
  final List<String> items;
  final double totalAmount;

  Order({
    required this.orderId,
    required this.date,
    required this.items,
    required this.totalAmount,
  });

  @override
  String toString() {
    final formattedDate =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    return 'Замовлення #$orderId від $formattedDate | Товари: ${items.join(", ")} | Сума: ${totalAmount.toStringAsFixed(2)} грн';
  }
}

// --- Сервіс імітації API інтернет-магазину ---

class StoreApiService {
  final Random _random = Random();

  /// Отримання інформації про користувача (імітація затримки 1.5 сек)
  Future<User> getUser({bool simulateError = false}) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    if (simulateError) {
      throw Exception('Помилка авторизації: не вдалося завантажити профіль.');
    }

    return User(
      id: 101,
      name: 'Олександр Ковальчук',
      email: 'o.kovalchuk@example.com',
    );
  }

  /// Отримання списку доступних товарів (імітація затримки 2 сек)
  Future<List<Product>> getProducts({bool simulateError = false}) async {
    await Future.delayed(const Duration(seconds: 2));

    if (simulateError || _random.nextInt(10) == 0) {
      // 10% випадковий шанс збою мережі для демонстрації стійкості
      throw TimeoutException('Час очікування відповіді від каталогу вичерпано.');
    }

    return [
      Product(id: 1, title: 'Механічна клавіатура Keychron K2', price: 4200.00),
      Product(id: 2, title: 'Бездротова миша Logitech MX Master 3S', price: 4850.00),
      Product(id: 3, title: 'Монітор 27" IPS 144Hz', price: 11500.00),
      Product(id: 4, title: 'USB-C Хаб 7-в-1', price: 1450.00),
    ];
  }

  /// Отримання історії замовлень користувача (імітація затримки 2.5 сек)
  Future<List<Order>> getOrders({bool simulateError = false}) async {
    await Future.delayed(const Duration(milliseconds: 2500));

    if (simulateError) {
      throw StateError('Сервіс історії замовлень тимчасово недоступний (503).');
    }

    return [
      Order(
        orderId: 'ORD-8841',
        date: DateTime(2026, 10, 12),
        items: ['Механічна клавіатура Keychron K2'],
        totalAmount: 4200.00,
      ),
      Order(
        orderId: 'ORD-9104',
        date: DateTime(2026, 11, 03),
        items: ['USB-C Хаб 7-в-1', 'Бездротова миша Logitech MX Master 3S'],
        totalAmount: 6300.00,
      ),
    ];
  }
}

// --- Точка входу ---

Future<void> main() async {
  final storeApi = StoreApiService();

  print('=== 1. ПОСЛІДОВНЕ ВИКОНАННЯ ЗАПИТІВ ===');
  await runSequential(storeApi);

  print('\n========================================\n');

  print('=== 2. КОНКУРЕНТНЕ ВИКОНАННЯ (Future.wait) ===');
  await runConcurrent(storeApi);

  print('\n========================================\n');

  print('=== 3. ДЕМОНСТРАЦІЯ ОБРОБКИ ПОМИЛОК ===');
  await runWithErrorHandling(storeApi);
}

/// Запити виконуються один за одним (сумарний час ~ 1.5 + 2.0 + 2.5 = 6.0 сек)
Future<void> runSequential(StoreApiService api) async {
  final stopwatch = Stopwatch()..start();

  try {
    print('Завантаження профілю...');
    final user = await api.getUser();
    print('-> Отримано: $user');

    print('Завантаження товарів...');
    final products = await api.getProducts();
    print('-> Отримано товарів: ${products.length} шт.');

    print('Завантаження замовлень...');
    final orders = await api.getOrders();
    print('-> Отримано замовлень: ${orders.length} шт.');
  } catch (e) {
    print('Помилка під час послідовного завантаження: $e');
  } finally {
    stopwatch.stop();
    print('Загальний час (послідовно): ${stopwatch.elapsedMilliseconds} мс');
  }
}

/// Усі три запити стартують одночасно (сумарний час ~ max(1.5, 2.0, 2.5) = 2.5 сек)
Future<void> runConcurrent(StoreApiService api) async {
  final stopwatch = Stopwatch()..start();
  print('Одночасний запуск запитів getUser(), getProducts(), getOrders()...');

  try {
    // Запускаємо Future одночасно і чекаємо завершення всіх через Future.wait
    final results = await Future.wait([
      api.getUser(),
      api.getProducts(),
      api.getOrders(),
    ]);

    final user = results[0] as User;
    final products = results[1] as List<Product>;
    final orders = results[2] as List<Order>;

    print('\n--- Дані успішно завантажено ---');
    print('Користувач: ${user.name} (${user.email})');

    print('\nДоступні товари:');
    for (final product in products) {
      print('  • $product');
    }

    print('\nІсторія замовлень:');
    for (final order in orders) {
      print('  • $order');
    }
  } on TimeoutException catch (e) {
    print('Мережевий таймаут: $e');
  } catch (e) {
    print('Непередбачена помилка: $e');
  } finally {
    stopwatch.stop();
    print('\nЗагальний час (конкурентно): ${stopwatch.elapsedMilliseconds} мс');
  }
}

/// Демонстрація часткової обробки помилок, щоб збій одного методу не ламав весь екран
Future<void> runWithErrorHandling(StoreApiService api) async {
  print('Спроба завантажити дані, коли сервіс замовлень повертає помилку...');

  // Кожен запит можна обгорнути в індивідуальний catchError або try-catch
  final userFuture = api.getUser().catchError((e) {
    print('[Лог помилки]: $e');
    return User(id: 0, name: 'Гість', email: 'guest@example.com');
  });

  final productsFuture = api.getProducts();

  final ordersFuture = api.getOrders(simulateError: true).catchError((e) {
    print('[Лог помилки]: $e');
    return <Order>[]; // Повертаємо порожній список як fallback
  });

  final results = await Future.wait([userFuture, productsFuture, ordersFuture]);
  final user = results[0] as User;
  final products = results[1] as List<Product>;
  final orders = results[2] as List<Order>;

  print('Результат після відновлення:');
  print('  Користувач: ${user.name}');
  print('  Товарів у каталозі: ${products.length}');
  print('  Замовлень завантажено: ${orders.length} (використано резервне значення)');
}