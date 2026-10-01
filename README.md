# Kronio Market

App móvil de **Kronio Market** construida con **Flutter**, que consume el backend
del e-commerce (NestJS + Prisma) a través de un proxy en Vercel.

## Funcionalidades

- **Inicio**: banner de bienvenida, categorías y productos destacados, con
  pull-to-refresh.
- **Catálogo**: scroll infinito con paginación real del backend, filtro por
  categoría y búsqueda.
- **Detalle de producto**: imagen, precio y descuento, estado de stock, selector
  de cantidad y agregar al carrito.
- **Carrito**: carrito local persistente (guest cart), control de cantidades
  topeado por stock, subtotal, vaciado con confirmación.
- **Búsqueda**: pantalla dedicada con reintento y estados vacíos.
- **Modo oscuro**: sigue la preferencia del sistema.

> **Pendiente**: el checkout no está implementado. El backend exige JWT y el
> flujo de pago no existe todavía; la app avisa al usuario en vez de simular una
> compra.

## Stack

- Flutter 3.47 / Dart 3.13
- `http` para consumo de API
- `shared_preferences` para persistencia del carrito local
- `intl` para formato de moneda con locale `es_CO`

## Configuración

La URL del backend se resuelve en tiempo de compilación con `--dart-define`, así
que el mismo código sirve para dev, staging y producción:

| Variable | Default | Para qué |
| --- | --- | --- |
| `KRONIO_API_URL` | `https://ecomerce-delta-three.vercel.app/api/proxy` | Base de la API |
| `KRONIO_TIMEOUT_SECONDS` | `15` | Timeout de cada petición |
| `KRONIO_PAGE_SIZE` | `20` | Productos por página |
| `KRONIO_ENV` | `production` | Etiqueta en la pantalla de perfil |

```bash
# Desarrollo contra el backend local (desde el emulador de Android)
flutter run --dart-define=KRONIO_API_URL=http://10.0.2.2:3000

# Release
flutter build apk --release --dart-define=KRONIO_API_URL=https://api.kronio.co
```

Sin `--dart-define` la app usa el proxy público, así que `flutter run` a secas
funciona.

## Cómo correr

```bash
flutter pub get
flutter run
flutter test
flutter analyze

flutter build apk --release        # APKs por ABI + universal
flutter build appbundle --release  # para Play Store
flutter build web
```

### Publicar en Android

El build de release **no** se puede publicar en Play Store hasta generar el
keystore: sin `android/key.properties` el APK se firma con la llave de debug y
Google lo rechaza.

```bash
.\scripts\generar_keystore.ps1
flutter build appbundle --release
```

El keystore y `key.properties` están en `.gitignore`. Guárdalos en un lugar
seguro: sin la llave no se pueden publicar actualizaciones, porque Android no
permite cambiarla.

## Estructura

```
lib/
├── main.dart                       # Entrypoint, rutas, CartScope global
├── config/
│   └── app_config.dart             # Configuración por --dart-define
├── theme/
│   ├── app_colors.dart             # Paleta de marca (fuente única)
│   └── app_theme.dart              # ThemeData claro y oscuro
├── models/
│   ├── product.dart                # Product + CategoryInfo
│   └── category.dart               # Category
├── services/
│   ├── api_service.dart            # Cliente HTTP + PaginatedResult
│   ├── api_exception.dart          # Errores tipados y mensajes en español
│   └── cart_service.dart           # Carrito local persistente
├── controllers/
│   └── catalog_controller.dart     # Estado del catálogo con paginación
├── screens/
│   ├── home_screen.dart            # AppBar + tabs
│   ├── home_tab.dart               # Pestaña Inicio
│   ├── search_screen.dart          # Pantalla de búsqueda
│   ├── product_detail_screen.dart
│   ├── cart_screen.dart
│   └── profile_screen.dart
├── widgets/
│   ├── cart_scope.dart             # InheritedNotifier del carrito
│   ├── cart_button.dart            # Botón con contador
│   ├── category_chips.dart         # Filtro por categoría
│   ├── product_card.dart           # Tarjeta
│   ├── product_grid.dart           # Grid con scroll infinito
│   ├── search_results_view.dart    # Resultados de búsqueda
│   └── brand_logo.dart
└── utils/
    ├── format.dart                 # Formato de moneda COP
    └── json_parsing.dart           # Lectura defensiva del JSON
```

## Notas sobre la API

`GET /products` responde una página, no un array plano:

```json
{
  "items": [ ... ],
  "total": 5,
  "page": 1,
  "limit": 20,
  "totalPages": 1
}
```

`PaginatedResult` también acepta un array plano y la forma `{value, Count}` por
si el contrato cambia, y deduce que hay más páginas cuando el backend no manda
`totalPages`.

Detalles a tener en cuenta al tocar la capa de red:

- **Los precios llegan como string** (`"269000"`), no como número. `parseMoney`
  los convierte tolerando ambos estilos de separador decimal.
- **`oldPrice` no siempre es un precio anterior mayor.** El catálogo tiene
  productos donde el precio actual es más alto. `hasDiscount` solo es `true` si
  `oldPrice > price`.
- **`gallery` siempre viene `[]`**, así que la app cae a la imagen principal.
- **`dropiProductId` y `customCode` no estaban modelados** y ya son parte de
  `Product`: `dropiProductId` es necesario para crear pedidos en Dropi.
- El carrito y el checkout del backend requieren JWT, por eso la app usa un
  carrito local de invitado, igual que la web.

### Errores

`ApiException` es una jerarquía sellada (`network`, `timeout`, `server`,
`client`, `notFound`, `format`) con el mensaje en español ya redactado. La UI
muestra `e.message`, no el `toString()` de la excepción. `canRetry` es `false`
para 404 y errores de formato, donde reintentar no ayuda.
