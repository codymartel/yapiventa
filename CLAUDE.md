# YapiVenta

App para que pequeños negocios de Latinoamérica (bodegas, restaurantes, ropa, etc.) armen su catálogo, su tienda web y reciban pedidos por WhatsApp. Todo en español: código, comentarios, commits y conversación. El usuario escribe rápido y con errores: interpretar con calma y confirmar lo dudoso. Explicar simple, con ejemplos reales y maquetas cuando hay pantallas.

## Proyecto
| Carpeta | Qué es |
|---|---|
| `mobile/` | App Flutter (móvil y **panel web** del vendedor). Firebase Auth + Firestore, `provider` |
| `web/` | **Tienda pública**: HTML/CSS/JS estático, sin build. Moldes en `web/public/moldes/`. **No se toca salvo que el usuario lo pida** |
| `docs/arquitectura/` | `00_PROGRESO.md` y **`plano_producto.md` (diseño acordado del producto y próximos pasos: leerlo antes de trabajar en productos)** |
| `docs/maquetas/` | Maquetas HTML aprobadas (estilo del panel) |
| `docs/bitacora/` | Una entrada por día (`AAAA-MM-DD.md`) |
| `.agents/`, `.opencode/`, `opencode.json` | Son de OpenCode. **No usarlos ni editarlos desde Claude Code** |

Firebase: proyecto `yapiventa`, plan **Spark** (sin Cloud Functions por ahora). Panel → sitio `yapiventa` (https://yapiventa.web.app). Tienda → target `tienda` (sitio `yapiventa-tienda`).

## Forma de trabajar (obligatoria)
**Nunca hacer una acción sin aprobación.** Eso incluye: editar archivos, crear o borrar archivos, commits, push, deploy y cualquier escritura o borrado en Firebase. Leer y analizar sí se puede sin preguntar.

1. **Analizar**: leer el código y los tests involucrados; anotar el tamaño de cada archivo.
2. **Proponer** (`/especificar`): especificación con puntos, capas, archivos, pruebas, **impacto en lecturas de Firebase** y decisiones pendientes con una recomendación. Maqueta si cambia una pantalla.
3. **Esperar el "sí"** explícito.
4. **Ejecutar** (`/implementar-paso`): por capas, con tests.
5. **Revisar el código** propio antes de informar (ver "Revisión de código").
6. **Informar y preguntar** antes de commit y antes de deploy.

## Separación de responsabilidades
- **Capas:** widget (pantalla) → provider (estado) → service / dominio (lógica pura, sin Flutter) → repository (datos). La UI no habla con Firestore; el provider no construye widgets; la lógica pura no vive en carpetas de widgets (va a `application/services` o `domain`).
- **Cuándo dividir un archivo:** si pasa de ~500 líneas (o va a pasar con el cambio), **preguntar siempre** antes de seguir. Se divide si además tiene más de una responsabilidad y se toca ahora; un archivo grande pero estable no se toca.
- **Cómo dividir:** por responsabilidad, no por tamaño. No crear archivos de menos de ~50 líneas salvo que se reusen.
- **Commit aparte:** primero el que solo divide (pruebas intactas y en verde), después el cambio de funcionalidad.

## Lecturas de Firebase (preguntar y optimizar siempre)
- **Toda propuesta que lea o escuche Firestore dice cuántas lecturas agrega** (por visita, por acción, por día) y **se pregunta** antes de implementarla.
- **Optimizar por defecto:** paginar listas; no escuchar colecciones enteras (escuchar un solo documento, por ejemplo uno de disponibilidad por negocio); cerrar los `onSnapshot` al salir; no releer lo que ya está en memoria; preferir un documento resumen a muchos documentos.
- **Escrituras** que tocan varios documentos (stock, combos): en una transacción, todo o nada.
- La tienda pública es anónima: los bots son el mayor riesgo de costo (catálogo en CDN y App Check cuando se trabaje en la web).

## Revisión de código (siempre, antes de informar)
Revisar el diff propio buscando: errores de lógica y casos límite; cuentas de dinero y stock (enteros, redondeo una vez, nada de `double`); lecturas o escrituras de Firebase de más; responsabilidades mezcladas o archivos que pasan de ~500 líneas; código duplicado o muerto; tests que faltan. Contar lo encontrado, aunque se haya corregido.

## Comandos (desde `mobile/`)
```bash
flutter test
flutter analyze
flutter build web
firebase deploy --only hosting --project yapiventa
```
Tienda pública (desde `web/`): `firebase deploy --only hosting:tienda`.

## Reglas de dominio (no negociables)
- **Dinero en enteros** (céntimos o unidad menor). Nunca `double` para precios ni cantidades.
- **Stock en unidad base entera** (g, ml, mm, cm², unidad). Registro de unidades **cerrado** (`unidad_registrada.dart`): las unidades extranjeras (galón, libra, docena) se guardan como presentación con su equivalencia.
- **Redondear una sola vez**: por línea al céntimo, hacia abajo (a favor del cliente); el redondeo de cobro solo al total.
- **El rubro sugiere, no prohíbe**: todos los rubros tienen las 4 medidas (peso, volumen, longitud, área); el preset solo decide cuáles empiezan activas.
- **Cada cosa que se cuenta tiene un solo lugar donde vive su stock**; los totales se calculan, no se escriben.
- Stock de pedidos: sumar **todo el carrito por producto base**; al cancelar, devolver **lo que se descontó**, no recalcular.
- Productos legacy se leen sin migrar a la fuerza.

## Trampas conocidas
- **No usar `git stash`**: `flutter analyze`/`pub get` regeneran `mobile/macos/Flutter/GeneratedPluginRegistrant.swift` y el `stash pop` falla. Ese archivo tiene un cambio local del usuario: **no commitearlo**.
- `git mv` deja el renombre preparado: revisar `git diff --cached` antes de cada commit para que no se cuele en otro.
- `flutter analyze` tiene 10 avisos previos (no son del trabajo actual).
- Los precios se muestran con coma (`centavosATexto`: S/ 12,00); la tarjeta de producto usa punto. Pendiente unificar (ver `plano_producto.md`).
- Archivos grandes conocidos: `configuracion_negocio_provider.dart` (~1 770 líneas), `paso_catalogo.dart` (~1 200), `productos_content.dart` (~560).

## Git
Conventional Commits en español (`feat(productos): ...`, `fix(medidas): ...`, `refactor(...)`, `docs: bitacora AAAA-MM-DD`). Se trabaja en `main`. Commit, push y deploy solo cuando el usuario lo pida.
