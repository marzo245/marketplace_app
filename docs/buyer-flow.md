# Flujo del comprador

## Pantallas involucradas

- `CatalogScreen` — catálogo paginado.
- `ProductDetailScreen` — detalle del producto, visor 3D, acciones.
- `SellerProfileScreen` (en `product_detail_screen.dart`) — perfil de un vendedor.
- `_ArProcessingChip` — indicador de progreso del modelo 3D mientras se genera.

## Catálogo (`CatalogScreen`)

Carga productos directamente desde Firestore con paginación manual (no `StreamBuilder` para esta pantalla):

```dart
products
  .where('status', '==', 'published')
  .where('category', '==', filtro)            // si hay filtro de categoría
  .where('model3d.status', '==', 'ready')     // si filtro = "Con vista 3D"
  .orderBy('createdAt', descending: true)
  .limit(30)
```

- **Filtros**: chip de categoría (Muebles, Decoración, etc.) + chip "Con vista 3D".
- **Búsqueda**: campo de texto que filtra client-side los `_products` ya cargados.
- **Paginación**: scroll → `_loadMore()` con `startAfterDocument(_lastDoc)`.
- **Pull to refresh**: `RefreshIndicator` recarga desde la primera página.

> Estos filtros combinados pueden requerir **índices compuestos** en Firestore. Firebase loguea el link para crearlos cuando la query falla.

### Tarjeta del producto

`_ProductCard` muestra foto, título, precio. Si `product.hasAr` (es decir `model3d.status == 'ready'` y `glbUrl != null`) aparece un badge morado "3D · AR" arriba a la derecha.

## Detalle (`ProductDetailScreen`)

Escucha el doc del producto en tiempo real (`StreamBuilder` sobre `products/{id}`) — así reacciona automáticamente cuando el modelo 3D pasa de `processing` a `ready`.

### Carrusel multimedia (`MediaCarousel`)

- Si hay `glbUrl`: el primer slide es el visor 3D inline (`Product3DViewer` → `model_viewer_plus` → WebView con `<model-viewer>`).
- Resto de slides: las fotos originales.
- Indicadores de página debajo.

### Chip de estado 3D

- `model3d.status == 'ready'` → chip verde **"Disponible en realidad aumentada"**.
- Cualquier otro caso → `_ArProcessingChip(productId)`:
  - Hace polling cada 5s a `GET /products/{id}/status`.
  - Muestra "Generando vista 3D · X%" + barra de progreso lineal.
  - Cuando el endpoint reporta `ready` se reemplaza por el chip verde sin recargar.
  - Si falla, "No se pudo generar la vista 3D".

### Acciones del comprador

| Acción | Lo que hace |
|---|---|
| **Favorito** (icono corazón) | Crea/borra `users/{uid}/favorites/{productId}` con `{productId, title, price, photo, sellerId, createdAt}`. |
| **Compartir** (icono share) | `share_plus` con título, precio, descripción, IDs y URLs (foto + glbUrl + usdzUrl). |
| **Contactar** (botón inferior izquierdo) | Crea doc en `product_inquiries` con tipo `contact_request`. El vendedor lo verá en su pestaña "Recibidas" si la lógica de inbox lo lista (actualmente lista solo `purchase_intents`). |
| **Solicitar compra** (botón inferior derecho) | Crea doc en `purchase_intents` con tipo `purchase_intent` y status `new`. Bloquea duplicados (busca por `productId + buyerId`). Bloquea autocompra (sellerId == uid). |
| **Ver perfil del vendedor** | Abre `SellerProfileScreen`. |
| **Lanzar AR** (botón sobre el visor 3D) | `ArService.launchAR()` → Scene Viewer (Android) / Quick Look (iOS). Detalle en [`ar.md`](ar.md). |

## Perfil del vendedor (`SellerProfileScreen`)

Lista los productos publicados del vendedor:

```dart
products
  .where('status', '==', 'published')
  .where('sellerId', '==', sellerId)
  // sin orderBy para no exigir índice compuesto
```

Ordenamiento por `createdAt desc` se hace client-side. Grid de 2 columnas con tarjetas táctiles que abren cada producto.

## Flujos secundarios desde el perfil propio (no estrictamente "comprador")

Las pestañas **Favoritos** / **Enviadas** / **Recibidas** del perfil son consumo del comprador:

- **Favoritos** — `_SavedItemsTab` lee `users/{uid}/favorites`.
- **Enviadas** — `_PurchaseIntentsTab` lee `purchase_intents where buyerId == uid`.
- **Recibidas** — `_PurchaseIntentsTab` lee `purchase_intents where sellerId == uid` (esto es vista de vendedor, pero vive en el mismo perfil).

Cada item es tappable y abre el producto correspondiente (`_openProduct` en `_ProfilePlaceholder`).
