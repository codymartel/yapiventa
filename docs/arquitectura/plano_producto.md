# Plano del producto — diseño acordado y próximos pasos

Documento vivo. Resume lo que se decidió con el usuario sobre el **producto** (panel del vendedor) para retomarlo en una conversación nueva. Leer antes de trabajar en productos. Última actualización: 2026-10-24.

> El producto es el punto donde todo choca (presentación, medida, modelos, extras, combos, stock). Primero se cierra esto; lo demás (cambio de rubro, web pública, pedidos) son agregados que leen lo que ya existe.

---

## 1. Estado actual (hecho y desplegado en https://yapiventa.web.app)

| Commit | Qué |
|---|---|
| `d96797e` | Medidas: switch en la tarjeta, las 4 medidas en todos los rubros (Bodega con peso y volumen activas), guardar `catalogoVenta` al dar Siguiente (sin crear el documento si no existe), "Por medida" apagado con aviso, una medida por familia en datos legacy. `seccion_medidas.dart` dividido en `widgets/medidas/` |
| `3442d0a` | Formulario de producto dividido por capas (widget, controller, services) |
| `4af06d6` | Pasos 2 y 3: presentación sugerida, "por botella (625 ml)", medida única elegida sola, precio "por kg" u "otra cantidad", mínimo e incremento propios (`Producto.minimoBase` / `incrementoBase`), vista previa con cantidades rápidas y ejemplo por monto |

Archivos clave del formulario (`mobile/lib/features/productos/`):
- `presentation/widgets/formulario_producto.dart` (diálogo) · `presentation/providers/formulario_producto_controller.dart` y `formulario_medida_controller.dart` (estado)
- `application/services/constructor_producto.dart`, `lectura_unidades_producto.dart`, `vista_previa_medida.dart`, `entrada_numerica.dart` (lógica pura)
- `domain/models/producto.dart`, `data/mappers/producto_firestore_mapper.dart`

---

## 2. Pendiente inmediato — Bloque A (medida y tarjeta)

**Bugs vistos por el usuario:**
1. **Tarjeta muestra `S/ 0.00` y `Stock: 0` tras guardar.** Causa: el repository devuelve el producto del formulario y la tarjeta (`producto_card.dart`) lee los campos legacy `precio` y `stock`, que el formulario deja en 0 (en Firestore está bien). Arreglo especificado: service puro `textos_tarjeta_producto.dart` que lea `precioCentavos` / `stockBase`; la tarjeta lo usa. Stock por medida con decimales (16,65 kg).
2. **Guardar apagado sin decir por qué.** Arreglo: `queFalta` en el controller y texto "Falta: nombre del producto" junto al botón (orden: nombre → categoría → presentación/formato o qué mides → precio → cantidad de "otra cantidad" → stock → mínimo/incremento propios).

**Cambios de diseño acordados en conversación (falta aprobar las decisiones):**
- **Quitar "Unidad de venta"**: la unidad sale de Configuración → Medidas. Peligro actual: elegir "g" y "por g" cobra por gramo.
- **Menú "Por"** con cantidades típicas: peso 1 kg · ½ kg · ¼ kg · 100 g · Otra cantidad…; volumen 1 L · ½ L · ¼ L · 100 ml; longitud 1 m · ½ m · 10 cm; área 1 m². "Otra cantidad" trae su propio g/kg y muestra siempre la equivalencia ("= S/ 12,000.00 por kg") como alarma.
- **4 casos:** medida desactivada (se muestra fija con aviso, nunca se borra ni cambia); unidad habitual "g" (cantidades típicas por familia, stock en la habitual); venta por gramo vía "Otra cantidad"; varias medidas activas (no se elige sola).
- **Tarjeta, opción C:** precio como lo puso el vendedor + "por kg" solo si la cuenta es exacta ("S/ 3.00 / ¼ kg · S/ 12.00 / kg"). Se guarda lo que escribió (300 céntimos / 250 g), nunca convertido.

**Decisiones pendientes del usuario:** (1) quitar "Unidad de venta" + menú (recomendado sí); (2) tarjeta opción C (recomendado sí); (3) separador decimal: punto `S/ 12.00` (recomendado) o coma.

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
1. **Bloque A**: tarjeta (precio y stock reales) + "Falta: …" + medida sin "Unidad de venta" (cuando el usuario apruebe las 3 decisiones).
2. **Especificación técnica del modelo de datos** de 3.2–3.6 (cómo se guarda en Firestore, sin migrar productos actuales) y su impacto en lecturas.
3. **Modelos + Se vende en** (con fotos por modelo, stock y precio por fila, avisos).
4. **Extras**.
5. **Presentaciones propias en todos los rubros**.
6. **Combos**.
7. Después: stock en pedidos (descontar al confirmar, transacciones, cancelar devuelve lo descontado), cambio de rubro, web pública, moneda por país.

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
| `se_vende_en_app.html` | **Vigente**: modelos con su lista "Se vende en", extras; café, gaseosa, queso |
| `formulario_producto_app.html` | Parcial: presentación propia (jaba) y jamonada por ¼ kg vigentes; versiones y combo reemplazados |
| `stock_precio_versiones_combo_app.html`, `pollo_y_combo_app.html` | Superadas (combos con elecciones; tabla color × talla) |
| `versiones_y_fotos_app.html`, `versiones_tallas_opciones_app.html`, `formulario_producto.html` | Superadas (etapas previas del diseño) |
