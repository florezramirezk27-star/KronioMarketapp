# Kronio Market App

Aplicación móvil de **Kronio Market** construida con **Flutter**, que consume el backend público del e-commerce (NestJS en Vercel).

## Funcionalidades

- **Inicio**: banner de bienvenida, categorías y productos destacados.
- **Catálogo**: búsqueda por nombre y filtro por categoría.
- **Detalle de producto**: galería de imágenes, descuentos, stock y agregar al carrito.
- **Carrito**: carrito local persistente (guest cart), cantidades, subtotal y eliminar ítems.
- **Búsqueda**: búsqueda en vivo por nombre de producto.

## Stack

- Flutter 3.47 / Dart 3.13
- `http` para consumo de API
- `shared_preferences` para persistencia del carrito local
- Proxy público Vercel: `https://ecomerce-delta-three.vercel.app/api/proxy`

## Cómo correr

```bash
flutter pub get
flutter run          # Elige un dispositivo (Android emulator, etc.)
flutter test         # Corre los tests
flutter build apk --debug   # Genera APK para Android
```

## Estructura

```
lib/
├── main.dart                  # Entrypoint, carga carrito, tema
├── models/
│   ├── product.dart           # Producto + CategoryInfo
│   └── category.dart          # Categoría
├── services/
│   ├── api_service.dart       # Cliente HTTP del backend
│   └── cart_service.dart      # Carrito local persistente
├── widgets/
│   ├── cart_scope.dart        # InheritedNotifier para el carrito
│   └── product_card.dart      # Tarjeta de producto reutilizable
├── screens/
│   ├── home_screen.dart       # Inicio + Catálogo (tabs) + Búsqueda
│   ├── product_detail_screen.dart
│   ├── cart_screen.dart
│   └── profile_screen.dart
└── utils/format.dart          # Formato de precios en COP
```

## Nota sobre la API

El endpoint `GET /products` responde `{"value": [...], "Count": N}`, por lo que el cliente lo desenvuelve correctamente. El carrito y checkout del backend requieren JWT, así que la app usa un carrito local de invitado (persistente), siguiendo el mismo patrón del `guest-cart` de la web.