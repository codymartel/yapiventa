(function () {
  'use strict';

  const plantillasPermitidas = new Set(['neon', 'cristal', 'sabroso', 'galeria']);

  function mostrarError(titulo, mensaje) {
    const estado = document.getElementById('estado');
    estado.classList.add('error');
    estado.setAttribute('aria-busy', 'false');
    estado.querySelector('h1').textContent = titulo;
    document.getElementById('mensaje').textContent = mensaje;
    document.title = titulo + ' | YapiVenta';
  }

  function leerSlugDesdeRuta() {
    const segmentos = window.location.pathname.split('/').filter(Boolean);
    if (segmentos.length !== 1) return '';

    try {
      return decodeURIComponent(segmentos[0]).trim();
    } catch (_) {
      return '';
    }
  }

  async function resolver() {
    const slug = leerSlugDesdeRuta();
    if (!slug) {
      mostrarError(
        'Tienda no encontrada',
        'Revisa que el enlace incluya el identificador de la tienda.'
      );
      return;
    }

    try {
      const negocio = await CargarNegocio.obtenerNegocio(slug);
      if (!negocio.webActiva) {
        mostrarError(
          'Tienda no disponible',
          'Este negocio ha desactivado temporalmente su tienda.'
        );
        return;
      }

      if (!plantillasPermitidas.has(negocio.plantilla)) {
        mostrarError(
          'Tienda pendiente de configurar',
          'El negocio todavía no tiene una plantilla web válida.'
        );
        return;
      }

      const parametros = new URLSearchParams({ slug: slug });
      window.location.replace(
        '/moldes/' + negocio.plantilla + '/?' + parametros.toString()
      );
    } catch (_) {
      mostrarError(
        'Tienda no encontrada',
        'No pudimos encontrar una tienda activa con este enlace.'
      );
    }
  }

  resolver();
})();
