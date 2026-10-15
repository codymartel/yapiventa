---
name: implementar-paso
description: Implementa en YapiVenta un paso ya especificado y aprobado, siguiendo el flujo del usuario (analizar, planear, dividir archivos, capas, tests, build, deploy con confirmación). Usar cuando el usuario aprueba una especificación o escribe /implementar-paso.
---

# Implementar un paso aprobado

Requisito: debe existir una especificación aprobada (ver `/especificar`). Si no la hay, armarla primero y esperar el "sí".

## Flujo (en este orden)
1. **Analizar.** Releer los archivos de la especificación y sus tests. Correr la base:
   `flutter test <carpetas tocadas>` desde `mobile/` y anotar cuántos pasan.
2. **Planear.** Tabla punto → capa → archivo (líneas) → cambio. Mostrarla.
3. **Revisar tamaños y preguntar.** Si un archivo a tocar pasa de ~500 líneas, **preguntar** antes (AskUserQuestion) si dividirlo en carpeta. Dividir es un cambio aparte, sin cambiar comportamiento, y va primero.
4. **Implementar por capas:** dominio (`domain/models`) → repository (`data/`) → provider → widget. La UI no habla con Firestore; el provider no construye widgets.
5. **Tests.** Si un test esperaba el comportamiento viejo a propósito, cambiarlo y decir por qué. Sumar al menos un test por punto de la especificación.
6. **Verificar** desde `mobile/`:
   ```bash
   flutter analyze
   flutter test
   flutter build web
   ```
   Los 10 avisos previos de `analyze` no cuentan; cualquier aviso nuevo en archivos tocados se arregla.
7. **Parar y preguntar** antes de commit y antes de deploy. Nunca desplegar sin confirmación.
8. **Commit** (si lo aprueba): Conventional Commits en español. Agregar solo los archivos del paso (nunca `mobile/macos/Flutter/GeneratedPluginRegistrant.swift`). No usar `git stash`.
9. **Deploy** (si lo aprueba):
   - Panel: `firebase deploy --only hosting --project yapiventa` (desde `mobile/`).
   - Tienda: `firebase deploy --only hosting:tienda` (desde `web/`).
   Verificar después: la URL responde 200 y sirve el código nuevo.
10. **Bitácora:** ofrecer agregar lo hecho y las decisiones a `docs/bitacora/AAAA-MM-DD.md`.

## Al terminar, informar
Qué cambió (por punto), tests (antes/después), qué quedó fuera, qué no se verificó a mano y cómo probarlo.
