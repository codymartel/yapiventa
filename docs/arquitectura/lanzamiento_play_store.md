# Lanzamiento a Google Play: prueba cerrada del panel

Plan acordado el **2026-11-07**. Sirve para abrir una **conversación nueva** y empezar de inmediato.

## 1. Decisión

- **Se lanza ya, en prueba cerrada, solo el panel del vendedor** (la app Flutter de `mobile/`).
- La **tienda pública** (`web/`) y **Caja** no frenan el lanzamiento: se agregan después como **actualizaciones**, día a día.
- **Por qué:** Google Play revisa la app Android, no la tienda web pública. La prueba cerrada de una cuenta
  personal nueva pide **12 testers durante 14 días** (dato de fuentes comerciales: **confirmarlo en Play Console**).
  Empezar ya hace que esa espera corra mientras se sigue construyendo. El usuario tiene **5 testers de los 12**.
- **Riesgo aceptado:** sin la tienda pública no llegan pedidos reales (falta la «tienda parte a»). La versión de
  prueba se explica así en la ficha; para el público general se abre cuando la tienda ya reciba pedidos.

## 2. Qué entra en la versión 1

| Entra (ya funciona) | Se esconde o queda fuera |
|---|---|
| Inicio de sesión (correo y Google), crear el negocio y su configuración | Caja (no está conectada al menú: queda oculta sola) |
| Productos: variables, extras, combos, medidas, foto obligatoria | Los 8 «próximamente» (ver sección 4, paso 6) |
| Pedidos: lista, confirmar con stock, entregar y cobrar, cancelar, historial | Reclamaciones, Plan, Ayuda, Stock (se esconden hasta tenerlos) |
| Plantillas de la tienda | Dashboard con ceros: decidir si se muestra |

## 3. Decisiones que faltan (responde el usuario al empezar)

1. **Nombre del paquete** (`applicationId`): es **permanente** en Play. Hoy es `com.example.mobile`.
   Recomendado: **`com.yapiventa.app`**.
2. **Tipo de cuenta de Play:** personal u organización. Personal nueva → prueba de 12 testers por 14 días.
   Organización (con D-U-N-S) está exenta, pero pide más trámites.
3. **Dónde va la política de privacidad:** recomendado `https://yapiventa.web.app/privacidad.html`, dentro del
   hosting del panel (así no se toca `web/`).
4. **¿Pedidos visible en la versión 1?** Recomendado: **esconderlo** hasta que la tienda reciba pedidos, para que
   los testers no encuentren una función vacía.
5. **Nombre en Play, ícono y correo de soporte** (hoy el nombre visible es «mobile» y la descripción es la de plantilla).
6. **Logo (elegido el 2026-11-07, falta guardar los archivos):** la idea 3, **«sello con nombre»**: una **Y** minimalista dentro
   de un sello cuadrado inclinado (-6°), el nombre «YapiVenta» y, al final del nombre, una **bolsita de producto con ✓ verde**
   (como comprado). Colores de `app_colors.dart`: azul `#2457B3`/`#3D72D4`, `#8AB2FF`, texto `#E8EDF5`, fondo `#0D1526`,
   ✓ `#4ADE80` (en fondo claro `#16A34A`). **El ícono de la app es solo el sello** (la bolsa no se lee en 32 px). Entregables
   pendientes (piden «sí» para crear archivos): SVG oscuro, SVG claro y SVG del sello en `docs/branding/`; PNG de **ícono de
   512 px** y **gráfico de 1 024 × 500** para Play; y el ícono de Android (zona segura) en el paso del paquete nuevo.
   **Antes de gastar en registrar la marca, revisar derechos (ver sección 5).**

## 4. Pasos técnicos, en orden

1. **Identidad del paquete.** Cambiar `namespace` y `applicationId` en `mobile/android/app/build.gradle.kts`, mover
   `MainActivity.kt` a la carpeta del paquete nuevo (`android/app/src/main/kotlin/...`) y su `package`, y poner el
   nombre visible en `AndroidManifest.xml` (`android:label`, hoy «mobile»). Actualizar `pubspec.yaml`
   (`description`). Ícono de la app.
2. **Firebase para el paquete nuevo.** En el proyecto `yapiventa` registrar una **app Android nueva** con el paquete
   nuevo, descargar su `google-services.json` y regenerar `lib/firebase_options.dart` (`flutterfire configure`).
   **Google Sign-In está en uso:** agregar los **SHA-1 y SHA-256** de la clave de debug, de la clave de subida y de la
   clave de firma de Play (se ve en Play Console, «Integridad de la app»). Sin eso, el inicio con Google falla en la
   versión de Play aunque funcione en pruebas.
3. **Firma de release.** Crear un keystore con `keytool`, un `key.properties` y la configuración `release` en
   `build.gradle.kts` (hoy el release se firma con la clave de **debug**). `key.properties`, `*.jks` y `*.keystore`
   ya están en `mobile/android/.gitignore`. **Guardar el keystore y sus contraseñas fuera del repositorio y con
   respaldo**: perderlos impide actualizar la app. Usar **Play App Signing** (Google guarda la clave final).
4. **Política de privacidad** (página pública) que diga: qué datos se guardan (correo, datos del negocio, productos,
   fotos, pedidos y datos de los clientes del vendedor), quiénes los procesan (Google Firebase, Cloudinary para las
   fotos), para qué, cuánto tiempo, cómo pedir que se borren y un correo de contacto.
5. **Borrar cuenta.** Obligatorio si la app crea cuentas: una opción **dentro de la app** (Configuración) y una
   **página web** con la forma de pedirlo, cuyo enlace se declara en Play. **Desactivar no cuenta.** Hoy no existe.
   Decidir qué se borra y qué se conserva (los pedidos «nunca se borran» según las reglas de Firestore: definir con
   cuidado; puede requerir marcar la cuenta y borrar los datos personales).
6. **Esconder los 8 «próximamente»** (lo no listo se oculta): `dashboard_contenido_inicio.dart` (Stock, Pedidos,
   Reclamaciones), `dashboard_web_screen.dart` (Ventas, Reclamaciones, Plan, Ayuda) y `seleccion_plantilla_flow.dart`
   (vista web).
7. **Probar la versión release en un teléfono real**: crear cuenta, iniciar con Google, crear negocio, crear un
   producto con foto, Pedidos, cerrar sesión. Revisar la consola de errores.
8. **Compilar:** `flutter build appbundle --release` (desde `mobile/`). Sube el `versionCode` en cada versión nueva
   (`version: 1.0.0+N` en `pubspec.yaml`).
9. **Play Console:**
   - Crear la cuenta de desarrollador (pago único de unos US$25 y verificación de identidad; **confirmar el monto y
     los requisitos vigentes en la consola**).
   - Crear la app (nombre, idioma, gratis).
   - **Contenido de la app:** política de privacidad (URL), anuncios (no), **acceso a la app** (la app pide inicio de
     sesión: dar una cuenta de prueba al revisor), clasificación de contenido, público objetivo, **seguridad de los
     datos** (incluye el enlace de borrar cuenta) y las demás declaraciones que pida la consola.
   - **Ficha:** descripción corta y larga, ícono de 512 px, gráfico de 1 024 × 500 y capturas de teléfono.
   - **Prueba cerrada:** crear la pista, agregar los testers (correos o grupo), subir el `.aab` y compartir el enlace
     para que se sumen. Los 12 testers deben **seguir inscritos** los 14 días.
10. **Durante los 14 días:** completar los testers que falten (el usuario tiene 5), recoger comentarios y subir
    versiones nuevas (`versionCode` más alto). Al terminar, pedir el acceso a producción.

## 5. Cosas que NO están confirmadas (verificar en la consola, no asumir)

- Que la prueba cerrada exija 12 testers por 14 días para esta cuenta, y si cuenta desde el día 12.º inscrito.
- El **nivel de API objetivo** (`targetSdk`) que exige Play para apps nuevas hoy.
- El monto y los requisitos de la cuenta de desarrollador y la verificación de identidad.
- Los formularios de declaraciones (cambian con el tiempo).

### Derechos del nombre y del logo (revisión hecha el 2026-11-07; **no es asesoría legal**)

- **Lo que se pudo comprobar:** una búsqueda web de «YapiVenta» no encontró otra app con ese nombre (no prueba que
  no exista una marca registrada). El logo se **dibujó desde cero** (letra Y, sello y una bolsa simple): no se copió
  ningún archivo ni ícono de terceros, y los colores son los del panel.
- **Riesgo a revisar: el nombre.** «Yapi» suena parecido a **Yape**, la marca de pagos digitales del BCP. Hay un caso
  público (YAPA contra YAPE) en que INDECOPI no consideró que una vocal de diferencia causara confusión, pero
  **cada caso se resuelve aparte y no es una garantía**. «YapiVenta» es otro nombre completo y otro rubro (gestión de
  ventas, no pagos), lo que ayuda.
- **Qué hacer:** (1) buscar gratis «Yapi», «Yapiventa» y variantes en el buscador de marcas de INDECOPI («Busca tu marca»);
  (2) si sale libre, pedir la **búsqueda de antecedentes** oficial (fonética y figurativa para el logo, con tasa por clase;
  clases 9, 35 y 42 de la clasificación de Niza) y luego **registrar la marca**; el registro dura 10 años. Los montos
  que se vieron en sitios de terceros (unos S/ 30 por búsqueda y unos S/ 535 por clase) **hay que confirmarlos en el TUPA
  oficial**. (3) Para Play **no se exige** registro de marca, pero conviene empezar la búsqueda antes de gastar en
  ficha, íconos y publicidad.
- **La tipografía del nombre:** el dibujo de prueba usa una fuente del sistema. En los archivos finales hay que usar una
  fuente con **licencia libre (por ejemplo, una de Google Fonts con licencia OFL)** y convertir el texto a trazos, para no
  depender de una fuente con derechos.
- **Lo genérico:** una bolsa de compras con una marca ✓ es un símbolo muy común; lo propio es la **combinación** (Y en
  sello inclinado + bolsa + nombre). No hay forma de garantizar por internet que nadie tenga algo parecido: la
  búsqueda figurativa de INDECOPI es la que lo comprueba para Perú.

## 6. Después de la versión 1 (actualizaciones, en este orden sugerido)

1. Tienda pública, parte a: leer variables, extras, combos y peso con cuentas en céntimos enteros, escribir la
   fecha con la hora del servidor y la unidad de las líneas; App Check. Así llegan pedidos reales.
2. Caja: terminar 4c-3 (ticket y cobrar), historial y anular, informes, tamaños y conectar «Ventas» al menú
   (antes dividir `dashboard_web_screen.dart`, 585 líneas). **Republicar las reglas** con el tope de 300 entradas de
   `stockDescontado` (la nube tiene 60).
3. Reclamaciones (confirmar con INDECOPI si es obligatorio y los plazos), Dashboard con datos reales.
4. Costo y seguridad: limitar o firmar las subidas de Cloudinary, alerta de presupuesto en Firebase.

## 7. Primer mensaje para la conversación nueva

> Lee `CLAUDE.md` y `docs/arquitectura/lanzamiento_play_store.md`. Vamos a **lanzar el panel a prueba cerrada en
> Google Play**. Empieza por las **3 decisiones de la sección 3** (te las respondo ahora: paquete, tipo de cuenta y
> dónde va la privacidad), y luego sigue los pasos de la sección 4 en orden, uno por uno, pidiéndome el «sí» antes
> de commit y antes de escribir en Firebase o publicar algo. Usa `/implementar-paso` y respeta la regla de tamaño
> (máximo 2 responsabilidades y 500 líneas por archivo). Tengo 5 testers y necesito completar 12.
