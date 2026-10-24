---
name: especificar
description: Arma la especificación de un cambio o paso de YapiVenta antes de tocar código (analizar y proponer). Usar cuando el usuario pide una funcionalidad, un arreglo o un rediseño, o escribe /especificar.
---

# Especificar antes de programar (analizar → proponer)

El usuario quiere **conversar y acordar** antes de que se escriba código. Esta skill **no edita archivos del proyecto**: solo lee, analiza y propone. Nada se ejecuta sin un "sí" explícito.

## Pasos
1. **Entender el pedido.** El usuario escribe rápido y con errores: interpretar con calma y confirmar lo dudoso (máximo 2–3 preguntas concretas). Si el tema es productos, leer antes `docs/arquitectura/plano_producto.md`: ahí está lo ya acordado.
2. **Analizar el código** (solo lectura): modelos de dominio, provider, repository, widgets y tests relacionados. Anotar el tamaño de cada archivo y qué responsabilidades mezcla.
3. **Simular el caso real**: un vendedor de un rubro concreto (Bodega, Restaurante, Ropa, Accesorios, Belleza, Otros) usando la función paso a paso, y lo que ve su cliente. Buscar casos límite.
4. **Escribir la especificación** con este formato:

```
## Especificación: <nombre>

**Problema / objetivo:** 1–2 frases.

**Puntos** (uno por cambio, numerados X.1, X.2…):
- X.1 <título> — capa (widget/provider/service/dominio/repository) — archivo (líneas)
  Hoy: qué pasa.  Cambio: qué se hará.  Resultado: qué nota el usuario.

**Lecturas de Firebase:** cuántas lecturas/escrituras agrega o quita (por visita, por acción) y cómo se optimiza. "Ninguna" si no toca Firestore.

**Fuera de este paso:** lo que se deja para después y por qué.

**Pruebas:** tests que cambian (y por qué) + tests nuevos por punto.

**Archivos grandes:** los que pasan de ~500 líneas o pasarán con el cambio, y la propuesta de división por responsabilidad. Preguntar siempre antes de dividir.

**Decisiones pendientes:** preguntas con la opción recomendada.
```

5. **Maqueta** cuando cambia una pantalla: lo que ve el vendedor y lo que ve el cliente, con el estilo del panel (colores de `mobile/lib/core/theme/app_colors.dart`, tema oscuro Material 3). Guardarla como HTML **fijo, sin JavaScript** (el visor no lo ejecuta) en `docs/maquetas/` y enviarla con SendUserFile.
6. **Revisar reglas de dominio** de `CLAUDE.md` (dinero en enteros, stock en unidad base y en un solo lugar, redondeo único, el rubro sugiere y no prohíbe). Si toca precios o stock, revisar sumas y restas con ejemplos numéricos.
7. **Terminar preguntando** si se aprueba. No implementar hasta un "sí" explícito; para implementar se usa `/implementar-paso`. Si la conversación cambió decisiones del producto, proponer actualizar `plano_producto.md`.

## Estilo
- Español simple, como para alguien que no es técnico; si no se entiende, explicarlo "como a un niño" con un ejemplo de su tienda.
- Tablas y ejemplos con números reales (S/ 4.50 el kg, 250 g…).
- Recomendar una opción, no listar todas. Ordenar por impacto cuando hay varios pasos.
