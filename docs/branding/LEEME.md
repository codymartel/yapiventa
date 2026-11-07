# Logo de YapiVenta

Elegido el **2026-11-07**: **«sello con nombre»**. Una **Y** minimalista dentro de un sello cuadrado inclinado
(-6°), el nombre **YapiVenta** y, al final, una **bolsita de producto con ✓ verde** (como comprado).

## Archivos

| Archivo | Para qué |
|---|---|
| `logo_yapiventa_fondo_oscuro.svg` | Logo completo sobre azul oscuro (panel, tienda, pantallas oscuras) |
| `logo_yapiventa_fondo_claro.svg` | Logo completo sobre blanco (documentos, facturas, páginas claras) |
| `sello_yapiventa.svg` | Solo el sello, fondo transparente, para fondos oscuros |
| `icono_app_yapiventa.svg` / `.png` | Ícono de la app, **512 × 512 px**, cuadrado completo (Play le pone las esquinas) |
| `grafico_play_1024x500.svg` / `.png` | Gráfico de funciones de la ficha de Play, **1 024 × 500 px** |

## Colores (los del panel, `mobile/lib/core/theme/app_colors.dart`)

| Uso | Fondo oscuro | Fondo claro |
|---|---|---|
| Fondo | `#0D1526` (gráfico de Play: `#070C18`) | `#FFFFFF` |
| Borde del sello y de la bolsa | `#8AB2FF` | `#2457B3` |
| La Y y el nombre | `#E8EDF5` | `#0D1526` |
| La marca ✓ | `#4ADE80` | `#16A34A` |

## Reglas de uso

- Deja alrededor del logo un espacio libre al menos del ancho de la bolsa.
- No lo estires, no lo gires distinto de como está y no cambies los colores.
- **El ícono de la app usa solo el sello**: la bolsa no se lee en tamaños chicos (32 px).
- Debajo de 24 px de alto, usa solo el sello.

## Tipografía y derechos

- El nombre está convertido a **trazos** de **Roboto Medium (licencia Apache 2.0)**: los archivos no necesitan
  ninguna fuente instalada y no dependen de una fuente con derechos reservados.
- El sello, la Y y la bolsa se **dibujaron desde cero**; no se copió ningún archivo ni ícono de terceros.
- **Estado de la marca: sin registrar ni buscada.** «Yapi» suena parecido a **Yape** (BCP). Antes de invertir en
  publicidad, buscar el nombre en «Busca tu marca» de INDECOPI y, si sale libre, pedir la búsqueda de antecedentes y
  registrarla (clases 9, 35 y 42). Detalle y advertencias en `docs/arquitectura/lanzamiento_play_store.md`.

## Pendiente

- **Ícono de Android** (capas adaptativas con el sello dentro de la zona segura, y los tamaños `mipmap`): se hace en el
  paso del paquete nuevo del lanzamiento. Hoy la app usa el ícono por defecto de Flutter.
- Confirmar en Play Console los tamaños y formatos vigentes de los gráficos de la ficha.
