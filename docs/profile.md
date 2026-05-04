# Perfil

El tab "Perfil" tiene dos modos según sesión:

- **Sin sesión** → tarjeta con avatar genérico y botón "Iniciar sesión con Google".
- **Con sesión** → `_ProfileTabsScaffold` con header del usuario + 4 pestañas tipo chip.

## Header

Avatar con la inicial del `displayName`/`email`, nombre, correo, y botón **Cerrar sesión**.

> Nota técnica: el botón usa un `style` local con `minimumSize: Size(0, 40)`. Esto es porque el theme global de `FilledButton` (`app_theme.dart`) tiene padding vertical fijo y, antes, `Size.fromHeight(52)` que forzaba ancho infinito y rompía el layout dentro de `Row`. Ver [`troubleshooting.md`](troubleshooting.md).

## Pestañas (chips)

Implementadas como `_ProfileTabChip` (no `SegmentedButton` por bugs de layout que tenía con anchos infinitos). Cuatro pestañas:

| Pestaña | Widget | Fuente Firestore |
|---|---|---|
| **Míos** | `_MyProductsTab` | `products where sellerId == uid` |
| **Favoritos** | `_SavedItemsTab` | `users/{uid}/favorites` |
| **Enviadas** | `_PurchaseIntentsTab(isSellerView=false)` | `purchase_intents where buyerId == uid` |
| **Recibidas** | `_PurchaseIntentsTab(isSellerView=true)` | `purchase_intents where sellerId == uid` |

## Pestaña "Míos" en detalle

Muestra **todos** los productos del usuario, incluso los `unpublished`. Cada item:

- Foto, título, precio, chip con el `status` actual.
- Menú "⋮" con: **Ver**, **Editar**, **Despublicar** (o **Republicar** si ya está despublicado).

### Editar

Abre un `AlertDialog` con campos para `title`, `description`, `price`. Al guardar:

```dart
products/{id}.update({
  title: ...,
  description: ...,
  price: ... // solo si parsea como número
})
```

### Despublicar / Republicar

Confirmación → `update({status: 'unpublished'})` o `update({status: 'published'})`.

El producto despublicado:
- **Sale** del catálogo público (filtra por `status == 'published'`).
- **Sigue** apareciendo en "Míos" del vendedor.
- **Conserva** el modelo 3D (no se borra el doc ni los archivos en Supabase).

## Pestaña "Favoritos"

Lista las cards guardadas. Cada item muestra foto, título, precio y abre el producto al tap.

Si el producto original fue borrado/despublicado, al tocar muestra "El producto ya no está disponible".

## Pestañas "Enviadas" y "Recibidas"

Misma UI con un boolean `isSellerView` que cambia las etiquetas:

- En **Enviadas**: muestra el `sellerName` (a quién le pediste).
- En **Recibidas**: muestra el `buyerName`/`buyerEmail` (quién te pidió).

Cada item muestra el chip de `status` (`new`, `accepted`, `rejected`, `completed`).

> Actualmente no hay UI para que el vendedor cambie el `status` de una solicitud recibida (aceptar/rechazar). Es la siguiente extensión natural: tap → bottom sheet con opciones que hagan `update({status: 'accepted'})` etc. La query y el modelo ya lo soportan.

## Perfil de otro vendedor

`SellerProfileScreen` (en `product_detail_screen.dart`) — accesible desde el detalle de cualquier producto vía "Ver perfil". Muestra avatar, nombre, conteo de productos publicados y un grid 2×N con sus productos `published`.
