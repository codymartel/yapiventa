# YapiVenta

App para que pequeños negocios de Latinoamérica (bodegas, restaurantes, ropa, etc.) armen su catálogo, su tienda web y reciban pedidos por WhatsApp. Todo en español: código, comentarios, commits y conversación.

## Proyecto
| Carpeta | Qué es |
|---|---|
| `mobile/` | App Flutter (móvil y **panel web** del vendedor). Firebase Auth + Firestore, `provider` |
| `web/` | **Tienda pública**: HTML/CSS/JS estático, sin build. Moldes en `web/public/moldes/` |
| `docs/arquitectura/` | Análisis y progreso (`00_PROGRESO.md`) |
| `docs/bitacora/` | Una entrada por día (`AAAA-MM-DD.md`) |
| `.agents/`, `.opencode/`, `opencode.json` | Son de OpenCode. **No usarlos ni editarlos desde Claude Code** |

Firebase: proyecto `yapiventa`, plan **Spark** (sin Cloud Functions por ahora). Panel → sitio `yapiventa` (https://yapiventa.web.app). Tienda → target `tienda` (sitio `yapiventa-tienda`).

## Forma de trabajar (obligatoria)
1. **Primero conversar y especificar.** No tocar código hasta que el usuario apruebe la especificación (usar `/especificar`).
2. Analizar → planear → **revisar el tamaño de los archivos**: si uno pasa de ~500 líneas, **preguntar** antes de meterle más y proponer dividirlo en carpeta.
3. **Separar por capas:** widget → service → provider → repository (y dominio en `domain/models`).
4. Ajustar tests → `flutter analyze` → `flutter test` → build → **deploy solo con confirmación**.
Para implementar un paso aprobado usar `/implementar-paso`.

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
- **Stock en unidad base entera** (g, ml, mm, cm², unidad). Registro de unidades **cerrado** (`unidad_registrada.dart`).
- **Redondear una sola vez**: por línea al céntimo; el redondeo de cobro solo al total.
- **El rubro sugiere, no prohíbe**: todos los rubros tienen las 4 medidas (peso, volumen, longitud, área); el preset solo decide cuáles empiezan activas.
- Stock de pedidos: sumar **todo el carrito por producto base**; al cancelar, devolver **lo que se descontó**, no recalcular.
- Productos legacy se leen sin migrar a la fuerza.

## Trampas conocidas
- **No usar `git stash`**: `flutter analyze`/`pub get` regeneran `mobile/macos/Flutter/GeneratedPluginRegistrant.swift` y el `stash pop` falla. Ese archivo tiene un cambio local del usuario: **no commitearlo**.
- `flutter analyze` tiene 10 avisos previos (no son del trabajo actual).
- Archivos grandes conocidos: `configuracion_negocio_provider.dart` (~1 770 líneas), `paso_catalogo.dart` (~1 200), `formulario_producto.dart` (~850).

## Git
Conventional Commits en español (`feat(productos): ...`, `fix(medidas): ...`, `docs: bitacora AAAA-MM-DD`). Se trabaja en `main`. Commit y push solo cuando el usuario lo pida.
