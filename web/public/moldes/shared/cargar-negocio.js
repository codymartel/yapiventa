// ═════════════════════════════════════════════════════════════════════════
// CargarNegocio — cargador único de datos para los moldes web.
//
// QUÉ HACE:
//   - Resuelve el negocio por su `slug` (recibido o desde ?slug=... en la URL).
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

  let promesaNegocioCache = null;
  let slugNegocioCache = '';
  let promesaCache = null;

  function leerSlugDesdeURL() {
    const params = new URLSearchParams(window.location.search);
    return (params.get('slug') || params.get('negocio') || '').trim();
  }

  function leerPlantillaDesdeRuta() {
    const segmentos = window.location.pathname.split('/').filter(Boolean);
    const indiceMoldes = segmentos.lastIndexOf('moldes');
    return indiceMoldes >= 0 && segmentos.length > indiceMoldes + 1
      ? segmentos[indiceMoldes + 1].trim()
      : '';
  }

  function texto(valor) {
    return String(valor || '').trim();
  }

  function numeroNoNegativo(valor) {
    const numero = Number(valor);
    return Number.isFinite(numero) && numero >= 0 ? numero : 0;
  }

  function urlHttpsSegura(valor) {
    const contenido = texto(valor);
    if (!contenido) return '';
    try {
      const url = new URL(contenido);
      return url.protocol === 'https:' ? url.href : '';
    } catch (_) {
      return '';
    }
  }

  function listaTextos(valor) {
    if (!Array.isArray(valor)) return [];
    const vistos = new Set();
    return valor.reduce((resultado, elemento) => {
      const contenido = texto(elemento);
      if (contenido && !vistos.has(contenido)) {
        vistos.add(contenido);
        resultado.push(contenido);
      }
      return resultado;
    }, []);
  }

  function normalizarZonas(valor) {
    if (!Array.isArray(valor)) return [];
    return valor.reduce((resultado, elemento) => {
      if (!elemento || typeof elemento !== 'object' || Array.isArray(elemento)) {
        return resultado;
      }
      const zona = texto(elemento.zona);
      if (zona) resultado.push({ zona: zona, costo: numeroNoNegativo(elemento.costo) });
      return resultado;
    }, []);
  }

  function normalizarHorarios(valor) {
    if (!Array.isArray(valor)) return [];
    return valor.reduce((resultado, elemento) => {
      if (!elemento || typeof elemento !== 'object' || Array.isArray(elemento)) {
        return resultado;
      }
      const dia = texto(elemento.dia);
      const apertura = texto(elemento.apertura);
      const cierre = texto(elemento.cierre);
      if (dia && elemento.activo === true) {
        resultado.push({
          dia: dia,
          apertura: apertura,
          cierre: cierre,
          activo: true,
        });
      }
      return resultado;
    }, []);
  }

  function normalizarMetodosPago(valor) {
    return listaTextos(valor)
      .map((metodo) => metodo.toLowerCase())
      .filter((metodo) => /^[a-z0-9_-]{1,40}$/.test(metodo));
  }

  function normalizarConfigPagos(valor, metodos) {
    const origen = valor && typeof valor === 'object' && !Array.isArray(valor)
      ? valor
      : {};
    const resultado = Object.create(null);
    for (const metodo of metodos) {
      const config = origen[metodo];
      if (!config || typeof config !== 'object' || Array.isArray(config)) continue;
      const tipoDescuento = config.tipoDescuento === 'porcentaje' ||
        config.tipoDescuento === 'monto_fijo'
        ? config.tipoDescuento
        : '';
      resultado[metodo] = {
        numero: texto(config.numero),
        descuentoActivo: config.descuentoActivo === true,
        montoMinimo: numeroNoNegativo(config.montoMinimo),
        tipoDescuento: tipoDescuento,
        valorDescuento: numeroNoNegativo(config.valorDescuento),
      };
    }
    return resultado;
  }

  function normalizarProducto(id, datos) {
    const nombre = texto(datos.nombre);
    if (!nombre) return null;
    return {
      id: id,
      nombre: nombre,
      precio: numeroNoNegativo(datos.precio),
      stock: Math.floor(numeroNoNegativo(datos.stock)),
      esStockInfinito: datos.esStockInfinito === true,
      descripcion: texto(datos.descripcion),
      categoria: texto(datos.categoria),
      disponible: datos.disponible === undefined ? true : datos.disponible === true,
      tieneDelivery: datos.tieneDelivery === true,
      urlImagen: urlHttpsSegura(datos.urlImagen),
      unidadMedidaNombre: texto(datos.unidadMedidaNombre),
      fraccionesSeleccionadas: listaTextos(datos.fraccionesSeleccionadas),
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

  async function cargarNegocio(slugSolicitado) {
    const db = firebase.firestore();
    const slug = String(slugSolicitado || leerSlugDesdeURL()).trim();
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
    const plantillaOficial =
      typeof datos.plantillaWeb === 'string' ? datos.plantillaWeb.trim() : '';
    const plantillaLegada =
      typeof datos.plantilla === 'string' ? datos.plantilla.trim() : '';
    const categorias = listaTextos(datos.categorias);
    const metodosPago = normalizarMetodosPago(datos.metodosPago);

    return {
      id: documento.id,
      slug: slug,
      nombre: texto(datos.nombreNegocio || datos.nombre),
      rubro: texto(datos.rubro),
      telefono: texto(datos.telefono),
      direccion: texto(datos.direccion),
      ruc: texto(datos.ruc),
      facebook: texto(datos.facebook),
      instagram: texto(datos.instagram),
      tiktok: texto(datos.tiktok),
      youtube: texto(datos.youtube),
      plantilla: plantillaOficial || plantillaLegada,
      webActiva: datos.webActiva === true,
      categorias: categorias,
      delivery: datos.delivery === true,
      deliveryZonas: normalizarZonas(datos.deliveryZonas),
      horarios: normalizarHorarios(datos.horarios),
      metodosPago: metodosPago,
      configPagos: normalizarConfigPagos(datos.configPagos, metodosPago),
    };
  }

  function obtenerNegocio(slugSolicitado) {
    const slug = String(slugSolicitado || leerSlugDesdeURL()).trim();
    if (!promesaNegocioCache || slugNegocioCache !== slug) {
      slugNegocioCache = slug;
      promesaNegocioCache = cargarNegocio(slug);
    }
    return promesaNegocioCache;
  }

  async function cargar() {
    const db = firebase.firestore();
    const negocio = await obtenerNegocio();
    const plantillaActual = leerPlantillaDesdeRuta();
    if (!negocio.webActiva) {
      throw new Error('Esta tienda no está disponible temporalmente.');
    }
    if (plantillaActual && negocio.plantilla !== plantillaActual) {
      throw new Error('La plantilla solicitada no corresponde a este negocio.');
    }

    const snapProductos = await db
      .collection('users')
      .doc(negocio.id)
      .collection('productos')
      .where('disponible', '==', true)
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
    obtenerNegocio: obtenerNegocio,

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
