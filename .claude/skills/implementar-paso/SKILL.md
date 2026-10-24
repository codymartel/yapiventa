---
name: implementar-paso
description: Implementa en YapiVenta un paso ya especificado y aprobado (ejecutar y revisar), siguiendo el flujo del usuario: analizar, planear, dividir archivos con permiso, capas, lecturas de Firebase optimizadas, tests, revisión de código, build, y commit/deploy solo con confirmación. Usar cuando el usuario aprueba una especificación o escribe /implementar-paso.
---

# Implementar un paso aprobado (ejecutar → revisar)

Requisito: debe existir una especificación aprobada (ver `/especificar`). Si no la hay, armarla primero y esperar el "sí". **Nunca hacer una acción que no esté aprobada**: si aparece algo fuera de la especificación (otro archivo, una escritura en Firebase, un borrado), parar y preguntar.

## Flujo (en este orden)
1. **Analizar.** Releer los archivos de la especificación y sus tests. Correr la base:
   `flutter test <carpetas tocadas>` desde `mobile/` y anotar cuántos pasan.
2. **Planear.** Tabla punto → capa → archivo (líneas) → cambio. Mostrarla.
3. **Revisar tamaños y preguntar.** Si un archivo a tocar pasa de ~500 líneas, o va a pasar con el cambio, **preguntar** (AskUserQuestion) antes de seguir. Dividir por responsabilidad, sin archivos de menos de ~50 líneas (salvo reuso), y la lógica pura fuera de las carpetas de widgets. La división es un commit aparte, sin cambiar comportamiento (pruebas intactas), y va primero.
4. **Implementar por capas:** dominio (`domain/models`) → repository (`data/`) → service → provider → widget. La UI no habla con Firestore; el provider no construye widgets.
5. **Lecturas de Firebase.** Comprobar que el cambio no agrega lecturas o listeners de más: paginar, escuchar un documento y no una colección, cerrar listeners, no releer lo que ya está en memoria. Escrituras de varios documentos en transacción. Si aparece una lectura que no estaba en la especificación, preguntar.
6. **Tests.** Si un test esperaba el comportamiento viejo a propósito, cambiarlo y decir por qué. Sumar al menos un test por punto de la especificación (los services puros se prueban sin pantalla).
7. **Verificar** desde `mobile/`:
   ```bash
   flutter analyze
   flutter test
   flutter build web
   ```
   Los 10 avisos previos de `analyze` no cuentan; cualquier aviso nuevo en archivos tocados se arregla.
8. **Revisar el código propio** (`git diff`) antes de informar: errores de lógica y casos límite; dinero y stock (enteros, redondeo una vez, sin `double`, stock en un solo lugar); lecturas y escrituras de Firebase; responsabilidades mezcladas y tamaño de archivos; código duplicado o muerto; tests que faltan. Corregir y contar lo encontrado.
9. **Parar y preguntar** antes de commit y antes de deploy.
10. **Commit** (si lo aprueba): Conventional Commits en español. Revisar `git diff --cached --stat` antes (los `git mv` quedan preparados y se cuelan). Nunca `mobile/macos/Flutter/GeneratedPluginRegistrant.swift`. No usar `git stash`.
11. **Deploy** (si lo aprueba):
    - Panel: `firebase deploy --only hosting --project yapiventa` (desde `mobile/`).
    - Tienda: `firebase deploy --only hosting:tienda` (desde `web/`).
    Verificar después: la URL responde 200 y sirve el código nuevo.
12. **Documentar:** ofrecer actualizar `docs/arquitectura/plano_producto.md` (estado y pendientes) y agregar la entrada del día en `docs/bitacora/AAAA-MM-DD.md`.

## Al terminar, informar
Qué cambió (por punto), tests (antes/después), lecturas de Firebase, qué encontró la revisión de código, qué quedó fuera, qué no se verificó a mano y cómo probarlo.
