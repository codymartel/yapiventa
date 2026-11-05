---
name: mejorar-diseno
description: Guía de calidad visual para pantallas y maquetas de YapiVenta (panel del vendedor y tienda). Usar siempre que se dibuje una maqueta, se diseñe o rediseñe una pantalla, o el usuario pida que algo "se vea mejor". Combina los skills de Apple (apple-hig-designer, apple-ui-skills, design) como guía de calidad con la identidad propia de YapiVenta.
---

# Mejorar el diseño en YapiVenta

Los skills de Apple (`apple-hig-designer`, `apple-ui-skills`, `design`) son **guía de calidad, no identidad**: sirven para revisar jerarquía, espacios, tipografía, contraste, zonas de toque y detalles pulidos. **No se copian colores, logo ni íconos de Apple.** La identidad es la de YapiVenta (tema oscuro Material 3).

## Pasos
1. **Inventariar** todas las funciones de la pantalla antes de dibujar. Ninguna se quita ni se esconde sin avisar al usuario: minimalista en aspecto, nunca con menos funciones.
2. **Leer** `mobile/lib/core/theme/app_colors.dart` y una maqueta aprobada de `docs/maquetas/` para respetar el estilo del panel.
3. **Dibujar la maqueta** como HTML fijo, sin JavaScript, en `docs/maquetas/` (celular y PC cuando haya las dos), y enviarla con SendUserFile.
4. **Revisar con la lista de abajo** y decir qué se corrigió.
5. **Esperar el «apruebo»** antes de pasar a Flutter (`/implementar-paso`).

## Lista de revisión
- **Cuadrícula de 4 px** para espacios y tamaños; jerarquía clara (un solo elemento principal por zona).
- **Zonas de toque** de al menos 44 px (botones de 46 a 48 px en celular); nada importante pegado al borde.
- **Contraste:** texto sobre `fondo`/`card` con `texto`, `muted` o `hint`. `dim` y `bordeSutil` son solo para bordes y rellenos, nunca texto. Avisos en ámbar, errores en rojo, éxito en verde, siempre con texto además del color.
- **Tipografía:** pocos tamaños, pesos con intención; textos cortos, en español simple.
- **Dinero:** céntimos enteros, con coma en pantalla (S/ 12,00).
- **Responsive:** menos de 900 px es modo celular (hoja desde abajo para formularios y detalles); 900 px o más usa el ancho (tabla, lista y detalle lado a lado).
- **Estados completos:** vacío, cargando, sin conexión, error y con muchos datos.
- **Detalles:** radios y bordes coherentes, iconos del mismo trazo, animaciones cortas y que no estorban.
- **Sin lecturas nuevas de Firebase por el diseño:** lo visual no debe pedir datos extra.

## Límites
- No tocar `web/` salvo que el usuario lo pida.
- Los colores salen de `AppColors`; no inventar colores sueltos ni selectores libres de color.
