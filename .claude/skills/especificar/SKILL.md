---
name: especificar
description: Arma la especificación de un cambio o paso de YapiVenta antes de tocar código. Usar cuando el usuario pide una funcionalidad, un arreglo o un rediseño, o escribe /especificar.
---

# Especificar antes de programar

El usuario quiere **conversar y acordar** antes de que se escriba código. Esta skill NO edita archivos del proyecto: solo lee, analiza y propone.

## Pasos
1. **Entender el pedido.** Si algo es ambiguo, preguntar (máximo 2–3 preguntas concretas). El usuario escribe rápido y con errores: interpretar con calma y confirmar lo dudoso.
2. **Leer el código involucrado** (solo lectura): modelos de dominio, provider, repository, widgets y tests relacionados. Anotar el tamaño de cada archivo.
3. **Simular el caso real** cuando aplique: un vendedor de un rubro concreto (Bodega, Restaurante, Ropa, Accesorios, Belleza, Otros) usando la función paso a paso, y lo que ve el cliente.
4. **Escribir la especificación** con este formato:

```
## Especificación: <nombre>

**Problema / objetivo:** 1–2 frases.

**Puntos** (uno por cambio, numerados X.1, X.2…):
- X.1 <título> — capa (widget/service/provider/repository/dominio) — archivo (líneas)
  Hoy: qué pasa.  Cambio: qué se hará.  Resultado: qué nota el usuario.

**Fuera de este paso:** lo que se deja para después y por qué.

**Pruebas:** tests que cambian (y por qué) + tests nuevos por punto.

**Archivos grandes:** los que pasan de ~500 líneas y la propuesta de división.

**Decisiones pendientes:** preguntas con opción recomendada.
```

5. **Mostrar maquetas** (show_widget) cuando el cambio es de pantalla: lo que ve el vendedor y lo que ve el cliente.
6. **Revisar reglas de dominio** de `CLAUDE.md` (dinero en enteros, stock en unidad base, redondeo único, el rubro sugiere y no prohíbe). Si el cambio toca precios o stock, revisar sumas y restas con ejemplos numéricos.
7. **Terminar preguntando** si se aprueba. No implementar hasta un "sí" explícito; para implementar se usa `/implementar-paso`.

## Estilo
- Español simple, tablas y ejemplos con números reales (S/ 4.50 el kg, 250 g…).
- Recomendar una opción, no listar todas.
- Ordenar por impacto cuando hay varios pasos.
