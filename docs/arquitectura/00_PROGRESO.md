# Progreso del análisis de arquitectura — YapiVenta

**Modo:** solo lectura (no se modifica código del proyecto).
**Fase actual:** FASE 0 TERMINADA — esperando aprobación.

---

## 1. Inventario del repositorio

Raíz: `C:\Users\User\Downloads\YapiVenta` (repo git, rama activa con commits deConventional Commits en español).

El repositorio contiene **3 sub-proyectos independientes**, no un monorepo con tooling unificado:

| Sub-proyecto | Ruta | Naturaleza |
|---|---|---|
| App de administración | `mobile/` | Flutter (Dart) multi-plataforma, empaquetado por Firebase Hosting |
| Tiendas públicas | `web/` | Sitio estático HTML/CSS/JS sin build ni framework, para Firebase Hosting |
| Configuración de agentes | `.agents/`, `.opencode/`, `opencode.json` | Skills/subagentes de opencode + `testsprite-plans/` (planes de pruebas E2E JSON) |

### Árbol de carpetas (3 niveles, sin build/vendor)

```
YapiVenta/
├── opencode.json
├── mobile/                        <- Flutter app "mobile"
│   ├── pubspec.yaml / pubspec.lock / analysis_options.yaml
│   ├── firebase.json / .firebaserc / firestore.rules
│   ├── README.md                  <- README boilerplate de Flutter (sin documentar)
│   ├── lib/
│   │   ├── main.dart              <- punto de entrada + router manual
│   │   ├── firebase_options.dart  <- generado por FlutterFire
│   │   ├── core/                  <- config, services, theme, widgets
│   │   ├── data/repositories/     <- 1 archivo VACÍO
│   │   ├── domain/models/         <- 4 modelos "sueltos"
│   │   ├── services/              <- 1 archivo VACÍO
│   │   └── features/              <- 17 módulos (4 implementados, 13 placeholders)
│   ├── test/                      <- 57 tests Dart + test/firestore_rules (Node)
│   ├── android/ ios/ macos/ linux/ web/ windows/   <- scaffolds generados
│   └── .firebase/ .dart_tool/ build/ (ignorados)
├── web/                           <- sitio estático "tienda"
│   ├── firebase.json / .firebaserc / .gitignore
│   └── public/
│       ├── index.html             <- landing "Preparando tu tienda"
│       ├── resolver-tienda.js     <- resuelve slug -> plantilla
│       └── moldes/                <- 4 plantillas (neon, cristal, sabroso, galeria) + shared/
├── testsprite-plans/              <- 9 planes JSON de pruebas E2E + README.md
├── .agents/ .opencode/            <- skills de opencode (testsprite, revisores)
```

## 2. Dimensión del proyecto

| Ámbito | Archivos | Líneas aprox. |
|---|---|---|
| `mobile/lib` (Dart, incluyendo 22 archivos vacíos) | 127 | ~21.400 |
| `mobile/lib/main.dart` | 1 | 353 |
| `mobile/test` (Dart tests, excluyendo node_modules) | 57 | ~20.700 |
| `mobile/test/firestore_rules` (JS + node_modules) | 2 propios | ~700 |
| `web/public` (HTML/CSS/JS propios) | 17 | ~4.000 |
| `testsprite-plans` (JSON) | 10 | ~9 KB |

**Hallazgo de Phase 0:** 22 archivos Dart tienen **0 bytes**. Todos son marcadores de posición
(feature folders "heredadas" del scaffold), no código roto. Ver lista en §4.

## 3. Módulos detectados (features de `mobile/lib/features`)

Ordenados por tamaño. "Vacío" = todos sus archivos tienen 0 bytes.

| # | Módulo | Ruta | Archivos | Líneas | Estado |
|---|---|---|---|---|---|
| 1 | **negocio** | `mobile/lib/features/negocio/` | 48 | 11.709 | Implementado |
| 2 | **dashboard** | `mobile/lib/features/dashboard/` | 15 | 3.012 | Implementado |
| 3 | **productos** | `mobile/lib/features/productos/` | 27 | 2.942 | Implementado |
| 4 | **auth** | `mobile/lib/features/auth/` | 11 | 2.622 | Implementado |
| 5 | **pedidos** | `mobile/lib/features/pedidos/` | 3 | 0 | **Vacío** |
| 6 | **configuracion** | `mobile/lib/features/configuracion/` | 4 | 0 | **Vacío** |
| 7 | **home** | `mobile/lib/features/home/` | 2 | 0 | **Vacío** |
| 8 | **caja** | `mobile/lib/features/caja/` | 1 | 0 | **Vacío** |
| 9 | **colaboradores** | `mobile/lib/features/colaboradores/` | 1 | 0 | **Vacío** |
| 10 | **encuestas** | `mobile/lib/features/encuestas/` | 1 | 0 | **Vacío** |
| 11 | **marketing** | `mobile/lib/features/marketing/` | 1 | 0 | **Vacío** |
| 12 | **planes** | `mobile/lib/features/planes/` | 1 | 0 | **Vacío** |
| 13 | **quejas** | `mobile/lib/features/quejas/` | 1 | 0 | **Vacío** |
| 14 | **stock** | `mobile/lib/features/stock/` | 1 | 0 | **Vacío** |

Fuera de `features/` (candidatos a "módulo transversal"):

| Módulo | Ruta | Archivos | Líneas | Estado |
|---|---|---|---|---|
| **core** | `mobile/lib/core/` | 8 | 470 | Parcial (2 vacíos) |
| **domain raíz** | `mobile/lib/domain/models/` | 4 | 298 | Modelos sueltos sin feature |
| **data raíz** | `mobile/lib/data/repositories/` | 1 | 0 | **Vacío** |
| **services raíz** | `mobile/lib/services/` | 1 | 0 | **Vacío** |

**Módulos del sub-proyecto `web/`** (a documentar como módulo aparte):

| Módulo | Ruta | Líneas aprox. |
|---|---|---|
| Resolver / landing | `web/public/index.html`, `web/public/resolver-tienda.js` | 160 |
| Plantilla neon | `web/public/moldes/neon/` | 447 |
| Plantilla cristal | `web/public/moldes/cristal/` | 406 |
| Plantilla sabroso | `web/public/moldes/sabroso/` | 367 |
| Plantilla galeria | `web/public/moldes/galeria/` | 2.090 |
| Shared web | `web/public/moldes/shared/` | 272 |

## 4. Archivos Dart vacíos (0 bytes) — confirmado por tamaño de archivo

```
mobile/lib/core/config/app_config.dart
mobile/lib/core/theme/app_theme.dart
mobile/lib/data/repositories/firestore_repository.dart
mobile/lib/services/yapa_messaging_service.dart
mobile/lib/features/caja/presentation/screens/caja_diaria_screen.dart
mobile/lib/features/colaboradores/presentation/screens/colaboradores_screen.dart
mobile/lib/features/configuracion/presentation/screens/delivery_config_screen.dart
mobile/lib/features/configuracion/presentation/screens/metodos_pago_config_screen.dart
mobile/lib/features/configuracion/presentation/screens/monto_minimo_config_screen.dart
mobile/lib/features/configuracion/presentation/screens/precios_hoy_screen.dart
mobile/lib/features/encuestas/presentation/screens/encuestas_screen.dart
mobile/lib/features/home/presentation/screens/home_screen.dart
mobile/lib/features/home/presentation/state/home_ui_state.dart
mobile/lib/features/marketing/presentation/screens/marketing_screen.dart
mobile/lib/features/negocio/presentation/screens/extra_negocio_screen.dart
mobile/lib/features/pedidos/presentation/screens/pedidos_screen.dart
mobile/lib/features/pedidos/services/pedidos_background_service.dart
mobile/lib/features/pedidos/services/pedidos_notification_helper.dart
mobile/lib/features/planes/presentation/screens/planes_screen.dart
mobile/lib/features/productos/presentation/widgets/image_source_picker_dialog.dart
mobile/lib/features/quejas/presentation/screens/quejas_screen.dart
mobile/lib/features/stock/presentation/screens/stock_rapido_screen.dart
```

## 5. Archivos demasiado grandes (>500 líneas) — a documentar en Fase 2/6

| Archivo | Líneas |
|---|---|
| `mobile/lib/features/negocio/presentation/widgets/paso_catalogo.dart` | 2.374 |
| `mobile/lib/features/negocio/presentation/providers/configuracion_negocio_provider.dart` | 1.548 |
| `mobile/lib/features/negocio/presentation/widgets/seccion_medidas.dart` | 1.048 |
| `mobile/lib/features/negocio/data/negocio_repository.dart` | 911 |
| `mobile/lib/features/negocio/presentation/widgets/paso_negocio.dart` | 680 |
| `mobile/lib/features/auth/presentation/screens/register_screen.dart` | 631 |
| `mobile/lib/features/negocio/presentation/widgets/configuracion_negocio_content.dart` | 596 |
| `mobile/lib/features/dashboard/presentation/screens/dashboard_web_screen.dart` | 549 |
| `mobile/lib/features/negocio/domain/models/catalogo_venta/catalogo_venta_persistido.dart` | 504 |
| `mobile/lib/features/productos/presentation/widgets/productos_content.dart` | 503 |
| `mobile/test/firestore_rules/firestore.rules` | ~300 (10.5 KB) |

## 6. Configuración y puntos de entrada leídos

- **`mobile/pubspec.yaml`** — `name: mobile`, SDK `^3.12.2`, version `1.0.0+1`. Dependencias:
  `firebase_core ^3.6.0`, `firebase_auth ^5.3.1`, `cloud_firestore ^5.4.3`, `provider ^6.1.2`,
  `http ^1.6.0`, `image_picker ^1.1.2`, `image_picker_for_web ^3.1.1`, `google_sign_in ^6.2.1`,
  `url_launcher ^6.3.2`, `cupertino_icons ^1.0.8`. Dev: `flutter_test`, `fake_cloud_firestore ^3.1.0`,
  `mocktail ^1.0.4`, `flutter_lints ^6.0.0`. **No hay `cloudinary` en pubspec** (aun así existe
  `mobile/lib/core/services/cloudinary_service.dart` — NO CONFIRMADO cómo funciona sin el SDK).
- **`mobile/lib/main.dart`** — inicializa Firebase, `MaterialApp` con `ThemeData.dark()`, routing
  manual por `onGenerateRoute`/`onGenerateInitialRoutes` hacia `RutasAcceso`. `MultiProvider`
  inyecta `NegocioRepository`, `AuthProvider`, `AccesoProvider`. Los `ChangeNotifierProvider` de
  `DashboardProvider` y `ConfiguracionNegocioProvider` se crean **por ruta**.
- **`mobile/lib/firebase_options.dart`** — generado por FlutterFire (82 líneas). Proyecto Firebase: `yapiventa`.
- **`mobile/firebase.json`** — declara plataformas Flutter, `firestore.rules` y hosting `build/web`.
- **`mobile/.firebaserc` / `web/.firebaserc`** — mismo proyecto `yapiventa`; `web/` añade target de
  hosting `tienda` → `yapiventa-tienda`.
- **`web/firebase.json`** — solo hosting, target `tienda`, `public: "public"`, rewrite `**` → `/index.html`.
- **`web/public/index.html`** — landing sin build; carga Firebase JS **compat v10.14.1 vía CDN**,
  `firebase-config.js` y `cargar-negocio.js` desde `/moldes/shared/`, y `resolver-tienda.js`.
- **`web/public/resolver-tienda.js`** — lee el slug de la ruta, llama `CargarNegocio.obtenerNegocio(slug)`,
  valida `negocio.webActiva` y whitelist de plantillas (`neon|cristal|sabroso|galeria`), y redirige
  a `/moldes/<plantilla>/?slug=...`. Plantilla y el resto = **NO CONFIRMADO** (se leerá en Fase 4).
- **`mobile/lib/features/auth/domain/politica_acceso.dart`** — define las 6 rutas
  (`/`, `/verificar-correo`, `/home`, `/elegir-rubro`, `/configurar-negocio`, `/productos`, `/elegir-plantilla`)
  y la matriz de permisos por etapa de configuración.
- **`mobile/README.md`** — boilerplate sin documentación del proyecto (**hallazgo**).
- **`opencode.json`** — skills en `.agents/skills` + plugin `@tarquinen/opencode-dcp`.
- **`mobile/test/firestore_rules/package.json`** — proyecto Node independiente `@firebase/rules-unit-testing 5.0.2` +
  `firebase 12.19.0`, script `node --test`. Confirma que las reglas de Firestore se testean fuera de Flutter.

**NO CONFIRMADO en Fase 0:** contenido de `firestore.rules`, estructura de `cloudinary_service.dart`,
config de `firebase-config.js`, y si existe algún runner/CI (no hay `.github/` ni `melos.yaml`/`Makefile`
visibles en la raíz).

## 7. Estado de fases

| Fase | Archivo | Estado |
|---|---|---|
| 0 — Reconocimiento | este archivo | ✅ TERMINADA (esperando aprobación) |
| 1 — Visión global | `docs/arquitectura/01_vision_global.md` | ⏳ pendiente |
| 2 — Módulos (en tandas de 3) | `docs/arquitectura/modulos/*.md` | ⏳ pendiente |
| 3 — Transversal | `docs/arquitectura/03_transversal.md` | ⏳ pendiente |
| 4 — Datos e integraciones | `docs/arquitectura/04_datos_integraciones.md` | ⏳ pendiente |
| 5 — Flujos reales | `docs/arquitectura/05_flujos.md` | ⏳ pendiente |
| 6 — Diagnóstico | `docs/arquitectura/06_diagnostico.md` | ⏳ pendiente |
| 7 — Consolidación | `ARQUITECTURA_ACTUAL.md` (raíz) | ⏳ pendiente |

### Estado de módulos para Fase 2

| Módulo | ¿Tanda? | Estado |
|---|---|---|
| negocio | Tanda 1 | pendiente |
| dashboard | Tanda 1 | pendiente |
| productos | Tanda 1 | pendiente |
| auth | Tanda 2 | pendiente |
| core | Tanda 2 | pendiente |
| web (tiendas públicas) | Tanda 2 | pendiente |
| pedidos / caja / colaboradores / encuestas / marketing / planes / quejas / stock | Tanda 3 | pendiente |
| domain raíz / data raíz / services raíz | Tanda 3 | pendiente |