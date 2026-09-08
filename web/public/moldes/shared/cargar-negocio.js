// ═════════════════════════════════════════════════════════════════════════
// CargarNegocio — cargador único de datos para los moldes web.
//
// QUÉ HACE:
//   - Resuelve el negocio por su `slug` (desde ?slug=... en la URL).
//   - Lee `users/{uid}` y la subcolección `users/{uid}/productos`.
//   - Normaliza la data al mismo esquema que usa la app móvil.
//   - Cachea la promesa: las N páginas de un molde comparten UN solo fetch.
//
// CÓMO SE USA (no duplicar este fetch en cada molde):
//   await CargarNegocio.obtener();
//   → { negocio, productos, categorias }
//
// Depende de firebase-app-compat + firebase-firestore-compat (CDN) y de
// que firebase ya esté inicializado por firebase-config.js.
// ═════════════════════════════════════════════════════════════════════════
window.CargarNegocio = (function () {
  'use strict';

  const formatoPrecio = new Intl.NumberFormat('es-PE', {
    style: 'currency',
    currency: 'PEN',
    minimumFractionDigits: 2,
  });

  let promesaCache = null;

  function leerSlugDesdeURL() {
    const params = new URLSearchParams(window.location.search);
    return (params.get('slug') || params.get('negocio') || '').trim();
  }

  function normalizarProducto(id, datos) {
    const nombre = String(datos.nombre || '').trim();
    if (!nombre) return null;
    return {
      id: id,
      nombre: nombre,
      precio: Number(datos.precio) || 0,
      stock: Number(datos.stock) || 0,
      esStockInfinito: Boolean(datos.esStockInfinito),
      descripcion: String(datos.descripcion || '').trim(),
      categoria: String(datos.categoria || '').trim(),
      disponible: datos.disponible === undefined ? true : Boolean(datos.disponible),
      tieneDelivery: Boolean(datos.tieneDelivery),
      urlImagen: String(datos.urlImagen || '').trim(),
      unidadMedidaNombre: String(datos.unidadMedidaNombre || '').trim(),
    };
  }

  function deducirCategorias(productos) {
    const categorias = [];
    const vistas = new Set();
    for (const producto of productos) {
      const nombre = producto.categoria.trim();
      if (nombre && !vistas.has(nombre)) {
        vistas.add(nombre);
        categorias.push(nombre);
      }
    }
    return categorias;
  }

  async function cargar() {
    const db = firebase.firestore();

    const slug = leerSlugDesdeURL();
    if (!slug) {
      throw new Error('Falta el slug del negocio. Abre esta página como ?slug=mi-negocio');
    }

    const resultado = await db
      .collection('users')
      .where('slug', '==', slug)
      .limit(1)
      .get();

    if (resultado.empty) {
      throw new Error('No se encontró el negocio "' + slug + '".');
    }

    const documento = resultado.docs[0];
    const datos = documento.data() || {};

    const negocio = {
      id: documento.id,
      nombre: String(datos.nombreNegocio || datos.nombre || '').trim(),
      rubro: String(datos.rubro || '').trim(),
      telefono: String(datos.telefono || '').trim(),
      direccion: String(datos.direccion || '').trim(),
      categorias: Array.isArray(datos.categorias)
        ? datos.categorias.filter((c) => String(c || '').trim() !== '')
        : [],
    };

    const snapProductos = await db
      .collection('users')
      .doc(documento.id)
      .collection('productos')
      .get();

    const productos = snapProductos.docs
      .map((doc) => normalizarProducto(doc.id, doc.data()))
      .filter((p) => p !== null)
      .sort((a, b) => a.nombre.localeCompare(b.nombre, 'es', { sensitivity: 'base' }));

    const disponibles = productos.filter((p) => p.disponible);
    const categorias =
      negocio.categorias.length > 0 ? negocio.categorias : deducirCategorias(disponibles);

    return { negocio: negocio, productos: disponibles, categorias: categorias };
  }

  return {
    obtener: function () {
      if (!promesaCache) promesaCache = cargar();
      return promesaCache;
    },

    formatearPrecio: function (valor) {
      return formatoPrecio.format(Number(valor) || 0);
    },

    urlWhatsApp: function (negocio, producto) {
      const telefono = String((negocio && negocio.telefono) || '')
        .replace(/[^\d]/g, '')
        .replace(/^00/, '');
      const mensaje = producto
        ? 'Hola ' + (negocio.nombre || '') + ', me interesa: ' +
          producto.nombre + ' (' + formatoPrecio.format(producto.precio) + '). ¿Está disponible?'
        : 'Hola ' + (negocio.nombre || '') + ', quiero hacer un pedido.';
      return 'https://wa.me/' + telefono + '?text=' + encodeURIComponent(mensaje);
    },
  };
})();