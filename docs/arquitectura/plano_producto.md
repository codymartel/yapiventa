# Plano del producto — diseño acordado y próximos pasos

Documento vivo. Resume lo que se decidió con el usuario sobre el **producto** (panel del vendedor) para retomarlo en una conversación nueva. Leer antes de trabajar en productos. Última actualización: 2026-10-29.

> El producto es el punto donde todo choca (presentación, medida, modelos, extras, combos, stock). Primero se cierra esto; lo demás (cambio de rubro, web pública, pedidos) son agregados que leen lo que ya existe.

---

## 1. Estado actual (hecho y desplegado en https://yapiventa.web.app)

| Commit | Qué |
|---|---|
| `d96797e` | Medidas: switch en la tarjeta, las 4 medidas en todos los rubros (Bodega con peso y volumen activas), guardar `catalogoVenta` al dar Siguiente (sin crear el documento si no existe), "Por medida" apagado con aviso, una medida por familia en datos legacy. `seccion_medidas.dart` dividido en `widgets/medidas/` |
| `3442d0a` | Formulario de producto dividido por capas (widget, controller, services) |
| `512daac`, `9d104f2`, `a0fbb34` | **Variables** (modelos + «Se vende en»): estructura en el documento del producto, pantalla con foto por modelo, filas con stock y total con candado, tarjeta «desde», prueba de los 6 rubros. **Sin desplegar** (2026-10-28) |
| `e674e17` | **Bloque A**: tarjeta con precio y stock reales, menú «Por» (sin «Unidad de venta»), los 4 casos de medida, «Falta: …» y punto decimal. Desplegado 2026-10-28 |
| `4af06d6` | Pasos 2 y 3: presentación sugerida, "por botella (625 ml)", medida única elegida sola, precio "por kg" u "otra cantidad", mínimo e incremento propios (`Producto.minimoBase` / `incrementoBase`), vista previa con cantidades rápidas y ejemplo por monto |

Archivos clave del formulario (`mobile/lib/features/productos/`):
- `presentation/widgets/formulario_producto.dart` (diálogo) · `presentation/providers/formulario_producto_controller.dart` y `formulario_medida_controller.dart` (estado)
- `application/services/constructor_producto.dart`, `lectura_unidades_producto.dart`, `vista_previa_medida.dart`, `entrada_numerica.dart` (lógica pura)
- `domain/models/producto.dart`, `domain/models/estructura_producto.dart` (modelos y filas), `data/mappers/producto_firestore_mapper.dart`, `estructura_producto_mapper.dart`, `vista_legacy_producto.dart`
- Variables: `presentation/providers/formulario_modelos_controller.dart` · `presentation/widgets/formulario/` (`pregunta_modelos_producto`, `lista_modelos_producto`, `fila_modelo_producto`, `foto_modelo`) · `application/services/totales_producto.dart`, `validador_modelos.dart`, `sugerencias_modelos.dart`

---

## 2. Bloque A — medida y tarjeta (HECHO 2026-10-28, commit `e674e17`)

Hecho y desplegado: tarjeta con `precioCentavos` / `stock` / `stockBase` (opción C: precio como lo escribió el vendedor + «/ kg» solo si la cuenta es exacta); menú «Por» (1 kg · ½ kg · ¼ kg · 100 g · Otra cantidad) sin «Unidad de venta» (la unidad es la habitual del negocio); 4 casos (medida desactivada fija con aviso, unidad habitual «g», gramo por «Otra cantidad» con equivalencia como alarma, varias medidas activas); «Falta: …» / «Revisa: …»; precios y cantidades con punto.

Servicios nuevos: `cantidades_tipicas.dart` (menú y etiquetas ½ ¼ ¾) y `textos_tarjeta_producto.dart`. Maqueta: `docs/maquetas/medida_y_tarjeta_app.html`.

**Pendientes que dejó:** probar a mano; dividir `formulario_producto_medida_test.dart` (642 líneas); borrar el precio al editar un producto por medida lo guarda como producto antiguo; color ámbar repetido (pasar a `AppColors`); Configuración → Medidas sigue con «1/4 kg».

---

## 2b. Variables — modelos y «Se vende en» (HECHO 2026-10-28, sin desplegar)

Alcance: solo variables. **Fuera:** extras, presentación nueva (jaba), combos y mezclas.

Decisiones tomadas:
- **Un documento por producto**: `tituloModelos`, `tituloFilas` y `modelos[…filas…]` van dentro del mismo documento. Sin subcolecciones: 0 lecturas extra, 1 escritura al guardar.
- **El stock vive solo en las filas**; el modelo muestra su total (candado). `precioCentavos` / `stock` / `stockBase` del producto son derivados (precio «desde» y suma) para la vista legacy de la tienda.
- **La palabra la pone el vendedor** (Color, Aroma, Diseño…); el sistema solo sugiere según el rubro (`SugerenciasModelos`).
- **La fila** lleva su etiqueta y, si la presentación tiene formatos (botella), el tamaño real. Por medida cada modelo tiene una sola fila.
- Límites: 30 modelos × 20 filas. Ids estables cortos (el pedido guardará producto · modelo · fila).
- **«No»** queda como siempre: un precio y un stock.

Limitaciones conocidas y pendientes: ver bitácora 2026-10-28 (el «No» sin varias filas, fotos huérfanas si falla la subida, palabras no guardadas en la lista del negocio, descartar modelos al decir «No»).

---

## 3. Diseño acordado del producto (Bloque B — aún no construido)

Maquetas aprobadas: `docs/maquetas/flujo_modelos_app.html` y `docs/maquetas/se_vende_en_app.html`.

### 3.1 Producto base (no cambia)
Categoría · forma de venta (**presentación** o **medida**, una sola para todo el producto) · foto general · precio base.
- **Categoría** = sección de la tienda (junta productos distintos). **No** confundir con modelo.
- **Forma de venta** = "¿lo cuentas o lo pesas?".

### 3.2 Tres partes, iguales en los 6 rubros
| Parte | Qué es | Stock | Foto |
|---|---|---|---|
| 📷 **Modelos** | Tipos del mismo producto (color, sabor, diseño, tono, material). Agrupa | No (salvo que no tenga filas: ver 3.4) | Una por modelo |
| 📦 **Se vende en** | Filas dentro de la forma de venta: tallas, números, tamaños o formatos | **Sí, cada fila** | No |
| ➕ **Extras** | Lo que el cliente agrega o elige (con ají, bordado + S/ 8) | **No** | No |

- **No existe una categoría "Tallas" aparte**: la talla es una fila de "Se vende en", donde ya vivía el stock. Así no choca con presentación ni volumen.
- El título de las filas se puede cambiar: Talla, Número, Tamaño, Formato.
- **Por medida hay una sola fila** (por kg, L, m o m²) con su stock en esa unidad; no hay "tallas de queso".

### 3.3 Flujo del vendedor
1. Sube la foto y lo básico.
2. Pregunta única con el ejemplo de su rubro: **"¿Este producto viene en distintos colores, sabores o diseños?"** (polo rojo y polo azul). "No" → producto simple con su lista "Se vende en".
3. Nombra la variable con su palabra (sugerencias: Color, Sabor, Diseño, Tono, Material). Queda en la **lista del negocio** para reusarla.
4. La foto que subió es el **primer modelo** ("¿Cómo se llama este?" → Azul). Si el producto ya tenía stock, **se pasa a ese modelo** (nada se pierde ni se duplica).
5. "+ Modelo" para cada otro, con su foto y **su propia lista "Se vende en"**.

### 3.4 Stock y precio
- **El stock vive siempre en lo de más adentro**: en cada fila de cada modelo; si el modelo no tiene filas, en el modelo; si no hay modelos, en el producto.
- **Los totales se calculan** (por modelo y del producto) y se muestran con candado: no se escriben.
- **Precio = donde va el stock**, empieza en el precio base; atajo "poner a toda la fila / a todas".
- Cada fila: stock (obligatorio o "ilimitado" para todo el producto), precio, código opcional.
- Vender "Azul · M" baja solo esa casilla.
- **Avisos anti-duplicado:** misma fila dos veces en un modelo ("Ya tienes Azul · XL con 3: ¿sumar, reemplazar, cancelar?"); dos modelos con el mismo nombre; producto con nombre repetido ("Ir a ese producto / crear igual"). **Duplicar producto** copia con stock 0.
- Borrar todos los modelos → ofrecer juntar el stock en el producto.

### 3.5 Extras
Texto con precio opcional (+ S/). **No descuentan stock** (por ahora). Van en el formulario, no en la descripción (el cliente los elige y llegan al pedido). La descripción queda para texto que solo se lee.

### 3.6 Combos (simples)
- Producto propio con **su foto y su precio**.
- Lista de **productos fijos**: cada línea apunta a "producto · modelo · fila" × cantidad, con su foto.
- Extras de texto (no tocan stock).
- **Sin elecciones dentro del combo por ahora** ("Inca o Coca" → otro combo). Sin combos dentro de combos.
- Stock del combo **calculado** (el menor de stock ÷ cantidad de cada parte); vender uno descuenta cada parte en una transacción. Recuadro "Al vender 1 combo se descuenta: …".
- No se puede borrar un producto usado en un combo; cada producto muestra "Se usa en: …".

### 3.7 Presentaciones propias en todos los rubros
Hoy solo "Otros" puede crearlas (`permitePersonalizadas`). Acordado: **todos los rubros** con nombre + cuánto trae en unidades del registro (Jaba = 30 unidades, Saco = 42.5 kg, Galón = 3 785 ml; Libra = 454 g con aviso de aproximado).

**Dónde se crean (acordado 2026-10-29): en Configuración del negocio → Catálogo de venta**, igual que las medidas. NO dentro del formulario del producto (el «+ Nueva presentación…» de la maqueta `formulario_producto_app.html`, caso 1, queda superado). El formulario solo agrega, bajo «Presentación», una línea: «¿No ves tu presentación? Créala en Configuración → Catálogo», con enlace para ir. Así el formulario no se alarga y hay un solo lugar para manejarlas. El trabajo es abrir a los 6 rubros la pantalla que hoy ya usa «Otros».

**Con variables no choca:** la presentación es una sola para todo el producto («Jaba de 30») y las variables van dentro (Tipo: Rosados / Blancos), con el stock en jabas dentro de cada una. Una jaba de 30 y una de 15 son **una sola presentación («Jaba») con dos formatos** (30 unidades y 15 unidades): en el producto, cada fila elige su formato. Comprobado en el panel real con «Huevos de granja» (2026-10-29).

### 3.8 Guía con ejemplo por rubro (en gris, enseña sin texto)
| Rubro | 📷 Modelos | 📦 Se vende en | ➕ Extras |
|---|---|---|---|
| Ropa | Azul, Rojo | S, M, L | Bordado + S/ 8 |
| Bodega | Inca, Coca | Botella 500 ml, 1.5 L | — |
| Bodega (medida) | Queso fresco, andino | por kg | — |
| Restaurante | Personal, Balde | — | Con ají, + papas S/ 6 |
| Accesorios | Plata, Acero | Anillo 6, 7 | Grabado + S/ 10 |
| Belleza | Tono rojo, nude | — | Envoltura de regalo |
| Tecnología (Otros) | Negro, Blanco | 64 GB, 128 GB | Mica + S/ 15 |

### 3.9 Límites de la primera versión
Un nivel de modelos y una lista de filas; una foto por modelo; extras sin stock; combos fijos.

---

## 4. Orden de construcción
1. ~~**Bloque A**~~ (hecho 2026-10-28).
2. ~~**Especificación técnica del modelo de datos**~~ (hecho para modelos y filas: ver 2b; extras y combos se especifican en sus pasos).
3. ~~**Modelos + Se vende en**~~ (hecho 2026-10-28, falta desplegar; el «No» con varias filas queda pendiente).
4. **Extras** ← siguiente.
5. **Presentaciones propias en todos los rubros** (se crean en Configuración → Catálogo; el formulario solo avisa y enlaza).
6. **Combos**.
7. **Tienda pública (`web/`) — AL FINAL, con todo listo** (acordado 2026-10-29): cuando estén variables, extras, presentaciones propias y combos, se hace una sola vez para que el cliente pueda comprar con todo. Ver notas abajo.
8. Después: stock en pedidos (descontar al confirmar, transacciones, cancelar devuelve lo descontado), cambio de rubro, moneda por país.

### Notas para cuando toque la tienda (investigado 2026-10-29)
- Son 4 plantillas estáticas (`web/public/moldes/`): **galería** (catálogo + carrito local + pedido por WhatsApp, 596 líneas), **cristal**, **neón** y **sabroso** (catálogo + ventana por producto + WhatsApp por producto). Todas leen por `shared/cargar-negocio.js`.
- Hoy `normalizarProducto` solo lee nombre, `precio`, `stock`, `urlImagen`, `unidadMedidaNombre` y `fraccionesSeleccionadas`: **no lee modelos, filas ni extras**. El cliente ve un solo producto con la portada y el stock total.
- Con variables hay que: leer `modelos`/`tituloModelos`/`tituloFilas`; elegir modelo y talla (la foto cambia, el precio es el de la fila, la fila sin stock sale tachada); el carrito de galería hoy usa el `id` del producto como clave y debe pasar a producto · modelo · fila; el mensaje de WhatsApp debe decir «Polo básico · Luna · M». Los productos sin modelos siguen igual.
- Lecturas: ninguna extra (la misma consulta única, `disponible == true`). Deploy: `firebase deploy --only hosting:tienda` desde `web/`.
- Con extras: se eligen y suman al precio en el carrito y el mensaje. Con combos: el stock del combo se calcula con los productos ya leídos.

## 5. Ideas acordadas para más adelante (no construir aún)
- **Cambio de rubro con 3 opciones:** Sumar (recomendada, no borra nada), Reemplazar configuración (productos quedan "Revisar"), Empezar de cero (borra productos y fotos; doble confirmación escribiendo el nombre del negocio, ofrecer descargar antes, todo o nada).
- Elecciones dentro de combos y extras unidos a un producto (descuentan stock).
- Varias formas del mismo stock (unidad / blíster / caja).
- Ficha técnica (marca, voltaje…).
- Stock en pedidos con apartado y web pública (necesita Blaze y Cloud Functions), catálogo web en CDN, App Check, alerta de presupuesto.
- Moneda por país (enteros en unidad menor + formateador; hoy hay "S/" fijo en varios lugares).

## 6. Maquetas
| Archivo | Estado |
|---|---|
| `flujo_modelos_app.html` | **Vigente**: flujo de 5 pasos para crear modelos |
| `se_vende_en_app.html` | **Vigente**: palabras propias del vendedor, stock solo en las filas, mismo orden en varios rubros |
| `prototipo_modelos_app.html` | **Vigente**: prototipo interactivo (se puede tocar) |
| `medida_y_tarjeta_app.html` | **Vigente**: Bloque A (menú «Por», 4 casos, tarjeta) |
| `formulario_producto_app.html` | Parcial: jamonada por ¼ kg vigente; la presentación propia (jaba) se crea ahora en Configuración, no en el formulario; versiones y combo reemplazados |
| `stock_precio_versiones_combo_app.html`, `pollo_y_combo_app.html` | Superadas (combos con elecciones; tabla color × talla) |
| `versiones_y_fotos_app.html`, `versiones_tallas_opciones_app.html`, `formulario_producto.html` | Superadas (etapas previas del diseño) |
