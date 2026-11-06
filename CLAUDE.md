# YapiVenta

App para que pequeños negocios de Latinoamérica (bodegas, restaurantes, ropa, etc.) armen su catálogo, su tienda web y reciban pedidos por WhatsApp. Todo en español: código, comentarios, commits y conversación. El usuario escribe rápido y con errores: interpretar con calma y confirmar lo dudoso. Explicar simple, con ejemplos reales y maquetas cuando hay pantallas.

## Proyecto
| Carpeta | Qué es |
|---|---|
| `mobile/` | App Flutter (móvil y **panel web** del vendedor). Firebase Auth + Firestore, `provider` |
| `web/` | **Tienda pública**: HTML/CSS/JS estático, sin build. Moldes en `web/public/moldes/`. **No se toca salvo que el usuario lo pida** (desde 2026-10-31 se trabaja la fase Pedidos) |
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

**Diseño:** al dibujar una maqueta o diseñar/rediseñar una pantalla, usar siempre `/mejorar-diseno` (guía de calidad con los skills de Apple: `apple-hig-designer`, `apple-ui-skills`, `design`). La identidad es la de YapiVenta (`app_colors.dart`); no se copian colores ni logo de Apple.
**Cuatro reglas en cada paso:** (1) **seguridad** (solo el dueño crea ventas de mostrador; la tienda anónima solo crea pedidos nuevos; `negocioId` siempre de la sesión; textos del cliente como texto plano; nada se borra; reglas probadas en el emulador; revisión de seguridad antes del commit), (2) **ahorro de lecturas**, (3) **separación de capas** y (4) **UX** (`/mejorar-diseno` con los skills de Apple y `ui-ux-pro-max`). La especificación y la revisión final las nombran.

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
- Archivos grandes conocidos: `configuracion_negocio_provider.dart` (~1 770 líneas), `paso_catalogo.dart` (~1 200), `dashboard_web_screen.dart` (~582: dividir el flujo de Configuración cuando se toque), `productos_content.dart` (~560), `formulario_producto_controller.dart` (~480: vigilar, ya se dividió una vez).
- **Reglas de Firestore sin tocar la nube:** `firebase emulators:exec --only firestore --project demo-yapiventa "<script>"` desde `mobile/` (el emulador ya está en caché). Probar con peticiones REST sin token (anónimo) o con un JWT sin firma `alg: none` (usuario). Borra después `mobile/firestore-debug.log`. Publicar reglas o índices es una escritura en `yapiventa`: pedir el «sí».
- `dart format` sobre una carpeta agrega un salto de línea a los archivos vacíos de pedidos (`screens/`, `widgets/`, `services/`) y los deja modificados: formatear solo archivos propios; si pasa, vaciarlos otra vez.
- **Ver el panel en el navegador de la app:** `.claude/launch.json` → `panel-local` (`flutter run -d web-server`, puerto 5050, ~1 min en compilar, sin hot reload: reiniciar la vista previa tras cada cambio). El usuario inicia sesión él mismo. `read_console_messages` muestra los errores de Firestore.
- **El emulador local no exige índices:** una consulta o una suma que pide índice solo falla en la nube (`failed-precondition`). La suma de «por cobrar» pide su propio índice. Un pedido con fecha vieja no se puede crear (`fecha == request.time`): los vencidos se prueban con pruebas automáticas.
- **Los archivos están en CRLF en esta máquina:** scripts de edición deben normalizar (`chr(13)+chr(10)`; un heredoc de Python con `\r\n` se corrompe). `Container(alignment:)` dentro de un `Wrap`/`Row` ocupa todo el ancho (usar `Center(widthFactor: 1)`) y `find.text` no encuentra un `Text.rich`.
- `fake_cloud_firestore` 3.1.0 no soporta `startAfter` con orden descendente (devuelve vacío): verificar esos cursores contra el emulador real.
- **Cloudinary** tiene `cloudName` y `uploadPreset` en el código (subida sin firma): limitar el preset en su panel o firmar las subidas (requiere Cloud Functions).
- `Timestamp.toDate()` devuelve hora **local**, no UTC: en pruebas comparar con `.toUtc()`.
- **`dart format` solo sobre los archivos propios**: sobre carpetas reformatea archivos ajenos (se revierten con `git checkout -- <archivo>`, nunca el `GeneratedPluginRegistrant.swift`).
- Heredocs de bash con comillas fallan: para editar muchos archivos usar la herramienta Edit o un script Python guardado con Write en el scratchpad, nunca en la raíz del repo.
- El sistema bloquea `git checkout --` (descartar cambios): no insistir; dejar el archivo sin incluir en el commit.
- Navegador integrado: la emulación de 375 px recorta las capturas; probar con el panel a ~800 px (menos de 900 px ya activa el modo celular). El selector de fotos es del sistema: la foto la elige el usuario.

## Estado del proyecto (actualizar al cerrar cada sesión)
Leer `docs/arquitectura/plano_producto.md` (sección 7: hoja de ruta) y la última bitácora de `docs/bitacora/`.
**Decisiones 2026-11-06 (ver `docs/bitacora/2026-11-06.md`):**
- **MVP solo Perú** (S/, `PEN`, hora de Lima; publicar la app solo en Perú). «País y moneda» queda para después del lanzamiento (especificación M.1–M.7 en la bitácora). En lo nuevo, el símbolo y la moneda van en un solo lugar por archivo.
- **Nada dice «próximamente»**: lo que no está listo se esconde. Hoy hay 10 lugares (`dashboard_web_screen.dart`, `dashboard_contenido_inicio.dart`, `seleccion_plantilla_flow.dart`); el atajo de Pedidos en Inicio dice «próximamente» aunque Pedidos ya funciona.
- **Caja (ventas en mostrador): diseño y maqueta hechos** (`docs/maquetas/caja_por_rubro.html` vigente; `caja_mostrador.html` superada). **Especificación técnica hecha** (bitácora 2026-11-06). **Hecho:** pasos 0, 1 y 2 y, del paso 3, la **3a** (contadores en el resumen del día) y la **3c** (cobrar una venta en una transacción: `ventas_mostrador_repository.dart` y `RegistrarVentaMostrador`). **Falta del paso 3:** 3b (entregar un pedido de la tienda suma contadores), 3d (anular), 3e (informes por rango), **3f (reglas de Firestore y emulador: sin ellas, cobrar sería rechazado en la nube; publicar pide «sí»)** y 3g (catálogo de 20 en 20 con `nombreBusqueda`, `tipoCaja` y `vendidos`, índices y relleno único; pide «sí»). Anular: local y recojo se anulan desde Caja (devuelve el stock y resta del día de la venta); el delivery en proceso se cancela desde Pedidos; sin otra pantalla. Una venta de mostrador es un **pedido con `origen: mostrador`**: en el local y recojo nacen entregados y cobrados; delivery queda confirmado y sigue en Pedidos; se **anula, no se borra**; solo cuenta como venta lo **entregado**. El resumen del día suma contadores (forma de pago, entrega, producto, modelo, combo) y los informes suman resúmenes diarios (hoy 1, semana 7, mes hasta 31 documentos por consulta). La ganancia no se puede calcular (el producto no guarda costo). Filtros rápidos que cambian por rubro + «Más filtros». Formas de pago reales: Efectivo, Yape, Plin y Transferencia. Notas por rubro (a confirmar con vendedores): Bodega 7, Ropa 7, Accesorios 7, Restaurante 5, Otros 5, Belleza 4.
- **Play Store** (verificar en Play Console): cuentas personales nuevas necesitan prueba cerrada de 12 testers por 14 días; borrar cuenta dentro de la app y con enlace web; política de privacidad. Orden de trabajo: 0 bitácora y commit; 1 especificar Caja; 2 Caja base (dominio, `CalculoCombo` con partes por peso, transacción); 3 Caja datos (repositorio, reglas, contadores); 4 Caja pantallas; 5 tienda parte a; 6 limpiar «próximamente» y conectar Ventas; después Android con la prueba cerrada, Reclamaciones, borrar cuenta.
**Hecho (panel desplegado en https://yapiventa.web.app, 2026-10-31):** productos con variables (modelos con foto obligatoria + filas «Se vende en»), **extras** (opcionales, sin stock, no en «Lo peso»), **combos** (precio propio, stock calculado de las partes, palabra por rubro, imagen conjunta), presentaciones propias en los 6 rubros con enlace a Configuración y «Guardar y volver al producto», **foto obligatoria** en todo producto y **formulario en hoja grande desde abajo en celular** (<900 px; diálogo en PC). Un producto = un documento; la vista legacy (`precio`, `stock`, `unidadMedidaNombre`) se deriva en el mapper.
**Prioridad decidida 2026-10-31: llegar a un MVP publicable en Play Store** (función antes que diseño). En este orden:
1. **Pedidos de punta a punta** (**en curso, 2026-11-05**): la tienda (`web/`) guarda el pedido en Firestore y abre WhatsApp; el panel lo lista y cambia su estado (5 estados: nuevo → confirmado → listo/en camino → entregado, o cancelado); **confirmar descuenta el stock en una transacción desde el panel** (sin Cloud Functions, plan Spark); cancelar devuelve lo descontado; nada se borra. La tienda debe leer variables, extras, combos y cantidades por peso, con cuentas en **céntimos enteros** (hoy lee solo `precio` y `stock` y calcula con decimales de JS).
   - **Hecho** (en `mobile/lib/features/pedidos/`): paso 1 dominio y servicios (`892f575`), paso 2 mapper, repository con transacciones, reglas e índice (`45765aa`), paso 3 casos de uso, abiertos de 10 en 10 y vencidos (`0e982d0`) y paso 4 providers: pestañas Nuevos y Activos en vivo, «Ver más», historial (`5f493c4`), paso 5a pantalla compacta para celular y tableta, con montos sin símbolo (`edcaf24`), y el resto del paso 5: resumen de ventas del día con sus reglas **ya publicadas** (`d0dd06e`), provider dividido en escucha y acciones (`e0a22af`), pantalla de PC con tabla, búsqueda y lote (`4a8ffd9`) pantalla de TV para control remoto (`d4a6dca`), pestañas Todos, Por cobrar y Reembolsos con 2 índices **ya publicados** (`2f86515`), tablero dividido (`9bd9e30`) y **Pedidos conectado en el tablero** (`ea5e95a`). **Probado a mano en el panel real** (confirmar, falta de stock, entregar y cobrar, cancelar con stock devuelto, historial, Por cobrar, PC). Diseño según la maqueta y ayuda «¿Cómo funciona?» de Pedidos (`717d8bb`), con el tercer índice **ya publicado**. 1 624 pruebas pasan (2 omitidas por límite del simulador de Firestore). Maquetas: `docs/maquetas/pedidos_responsive.html` (vigente) y `pedidos_panel_app.html`.
   - **Falta:** **comprobar en pantalla** el diseño y la ayuda de Pedidos y que «Por cobrar» use la suma exacta (el índice `estadoPago + estado + totalCentavos` ya está publicado, tarda unos minutos; sin él la pantalla cae a «cargados»); **la tienda** (a: simples y por peso, b: modelos y filas, c: extras y combos, con App Check; debe escribir `fecha` con `serverTimestamp` y la unidad de las líneas por medida; hasta entonces no llegan pedidos reales); el paso **«País y moneda»** (el selector de país hoy solo cambia el prefijo del teléfono; falta moneda, decimales y zona horaria; «S/» está escrito a mano en tablero y productos, y la hora usa Lima fija). Detalles menores: «1 entregados» sin singular, el aviso de abajo tapa los botones (usar `floating`), la etiqueta «Por cobrar (cargados)» se corta. La web no tiene caché local: los listeners se pausan si la pestaña lleva >2 min oculta. Fuera por ahora: Exportar e Imprimir (PC) y «Stock bajo» (TV). Sin probar con un control remoto ni una TV real. Quedan 3 pedidos de prueba en el negocio «fdsfsf» (no se pueden borrar).
   - **Decidido:** los pedidos se cancelan, **no se borran**; vencidos (12 h) con el reloj del teléfono y a mano (la cancelación automática queda para Cloud Functions); entregar y cobrar en una sola transacción.
   - **Sin decidir:** «en preparación» por rubro, resumen del día (1 lectura), TV en el MVP o después. Las insignias de pestaña se cuentan de lo cargado («10+»), sin lecturas. **Ticket del día** = ventas del día ÷ entregados (delivery y recojo, total del pedido, sin cancelados), calculado al mostrarlo; el resumen del día (`negocios/{id}/resumenes/AAAA-MM-DD`) se escribe dentro de confirmar y entregar (+1 lectura y +1 escritura cada uno). Ver `docs/bitacora/2026-11-05.md`.
2. **Reclamaciones** (Libro de Reclamaciones: formulario en la tienda + lista y respuesta en el panel). Verificar requisitos y plazos con INDECOPI antes de construir.
3. **Dashboard con datos reales** (hoy muestra ceros) y cerrar **Negocio / Configuración**.
4. **Android**: cambiar `applicationId` (hoy `com.example.mobile`), firmar, probar en teléfonos reales, política de privacidad, borrar cuenta. Una cuenta personal nueva de Play puede exigir prueba cerrada (~12 testers, ~14 días): verificar en la documentación oficial.
5. **Después del lanzamiento**: rediseño de las 4 plantillas (`web/public/moldes/`: galería, cristal, neón, sabroso), planes de pago, IA (la llave de la API no puede ir en el cliente: requiere Cloud Functions → plan Blaze).
Otros pendientes: leer partes de combos no cargadas (la lista carga 10 por página; hoy la tarjeta muestra «—»), tarjeta nueva (`docs/maquetas/diseno_producto_app.html`), textos en singular («1 color», «6 unidad»), pruebas de uso por rubro, push a GitHub (los commits desde `96dad0d` están solo en local).
**Código Kotlin original:** el usuario pasa lo que hizo en Kotlin (pedidos, quejas, etc.) para analizarlo y migrarlo a Flutter: **leerlo antes de diseñar**. Pedidos ya se analizó y se está migrando. Las carpetas `mobile/lib/features/{quejas,caja,stock,colaboradores,planes,marketing,encuestas}` están vacías (archivos sin contenido).

## Bitácora (registro de portafolio)
`docs/bitacora/AAAA-MM-DD.md`: **un archivo por día, una entrada por cada cambio o agregado**, con su **hora** (`### HH:MM · hash título`) y el commit. Cada entrada dice qué se hizo, por qué, cómo y el resultado (pruebas, lecturas de Firebase, decisiones). Las decisiones tomadas y las no tomadas van en entradas aparte. Sirve también como registro del proyecto para el portafolio del usuario: escribir claro y con datos reales. Al cerrar cada cambio importante, agregar su entrada.

## Git
Conventional Commits en español (`feat(productos): ...`, `fix(medidas): ...`, `refactor(...)`, `docs: bitacora AAAA-MM-DD`). Se trabaja en `main`. Commit, push y deploy solo cuando el usuario lo pida.
