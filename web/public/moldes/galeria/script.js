/* ═══════════════════════════════════════════════════════════════════════
   MOLDE GALERIA — catálogo público y carrito local.
   Los datos se leen exclusivamente mediante shared/cargar-negocio.js.
   No crea pedidos ni escribe en Firestore.
   ═══════════════════════════════════════════════════════════════════════ */
document.addEventListener('alpine:init', () => {
  'use strict';

  const MAX_CANTIDAD = 999;
  const NOMBRES_METODOS = {
    yape: 'Yape',
    plin: 'Plin',
    efectivo: 'Efectivo',
    transferencia: 'Transferencia',
  };

  Alpine.data('catalogo', () => ({
    cargando: true,
    error: '',
    negocio: {},
    todos: [],
    categorias: [],
    categoriaActiva: '',
    busqueda: '',
    cantidades: {},
    items: [],
    carritoAbierto: false,
    tipoEntrega: '',
    zonaSeleccionada: '',
    metodoPagoSeleccionado: '',
    _claveCarrito: '',

    init() {
      this.cargar();
    },

    async cargar() {
      try {
        this.cargando = true;
        this.error = '';
        const datos = await CargarNegocio.obtener();
        this.negocio = datos && datos.negocio ? datos.negocio : {};
        if (!String(this.negocio.nombre || '').trim()) {
          throw new Error('El negocio no tiene un nombre público configurado.');
        }
        this.todos = datos && Array.isArray(datos.productos) ? datos.productos : [];
        this.categorias = Array.isArray(this.negocio.categorias)
          ? this.negocio.categorias
          : [];
        this._claveCarrito = this.crearClaveCarrito();
        this.restaurarCarrito();
        this.inicializarOpciones();
        if (this.negocio.nombre) {
          document.title = this.negocio.nombre + ' | YapiVenta';
        }
      } catch (error) {
        this.error = error && error.message ? error.message : String(error);
      } finally {
        this.cargando = false;
      }
    },

    crearClaveCarrito() {
      const identidad = String(this.negocio.slug || this.negocio.id || '')
        .trim()
        .replace(/[^a-zA-Z0-9_-]/g, '')
        .slice(0, 100);
      return 'yapiventa:galeria:carrito:' + identidad;
    },

    inicializarOpciones() {
      const entregaGuardadaValida =
        (this.tipoEntrega === 'recojo' && this.puedeRecojo) ||
        (this.tipoEntrega === 'delivery' && this.puedeDelivery);
      if (!entregaGuardadaValida) {
        if (this.puedeRecojo) {
          this.tipoEntrega = 'recojo';
        } else if (this.puedeDelivery) {
          this.tipoEntrega = 'delivery';
        } else {
          this.tipoEntrega = '';
        }
      }

      if (this.tipoEntrega !== 'delivery' || !this.zonaActual) {
        this.zonaSeleccionada = '';
      }

      const existeMetodo = this.metodosPago.some(
        (metodo) => metodo.id === this.metodoPagoSeleccionado
      );
      if (!existeMetodo) {
        this.metodoPagoSeleccionado = this.metodosPago.length
          ? this.metodosPago[0].id
          : '';
      }
    },

    get productosFiltrados() {
      const consulta = this.normalizarTexto(this.busqueda);
      return this.todos.filter((producto) => {
        const coincideCategoria = !this.categoriaActiva ||
          producto.categoria === this.categoriaActiva;
        if (!coincideCategoria || !consulta) return coincideCategoria;
        const contenido = this.normalizarTexto(
          producto.nombre + ' ' + producto.descripcion + ' ' + producto.categoria
        );
        return contenido.includes(consulta);
      });
    },

    get textoResultados() {
      const total = this.productosFiltrados.length;
      return total === 1 ? '1 producto' : total + ' productos';
    },

    normalizarTexto(valor) {
      return String(valor || '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLowerCase()
        .trim();
    },

    seleccionarCategoria(categoria) {
      this.categoriaActiva = String(categoria || '');
    },

    limpiarFiltros() {
      this.busqueda = '';
      this.categoriaActiva = '';
    },

    urlHttpsSegura(valor) {
      const contenido = String(valor || '').trim();
      if (!contenido) return '';
      try {
        const url = new URL(contenido);
        return url.protocol === 'https:' ? url.href : '';
      } catch (_) {
        return '';
      }
    },

    imagenProducto(producto) {
      return this.urlHttpsSegura(producto && producto.urlImagen);
    },

    ocultarImagen(producto) {
      if (producto) producto.urlImagen = '';
    },

    estaAgotado(producto) {
      return !producto.esStockInfinito && this.enteroSeguro(producto.stock, 0) <= 0;
    },

    textoBotonProducto(producto) {
      return this.estaAgotado(producto) ? 'Agotado' : 'Agregar al carrito';
    },

    permiteDeliveryProducto(producto) {
      return this.negocio.delivery === true && producto.tieneDelivery === true;
    },

    textoStock(producto) {
      if (producto.esStockInfinito) return 'Stock disponible';
      const stock = this.enteroSeguro(producto.stock, 0);
      if (stock <= 0) return 'Sin stock';
      return stock === 1 ? '1 unidad disponible' : stock + ' unidades disponibles';
    },

    textoUnidad(producto) {
      const unidad = String(producto.unidadMedidaNombre || '').trim();
      const fracciones = Array.isArray(producto.fraccionesSeleccionadas)
        ? producto.fraccionesSeleccionadas.filter((fraccion) => String(fraccion || '').trim())
        : [];
      if (!unidad && !fracciones.length) return '';
      if (!fracciones.length) return unidad;
      if (!unidad) return fracciones.join(', ');
      return unidad + ': ' + fracciones.join(', ');
    },

    enteroSeguro(valor, minimo) {
      const numero = Number(valor);
      if (!Number.isFinite(numero)) return minimo;
      return Math.max(minimo, Math.floor(numero));
    },

    cantidadMaxima(producto) {
      if (producto.esStockInfinito) return MAX_CANTIDAD;
      return Math.min(MAX_CANTIDAD, this.enteroSeguro(producto.stock, 0));
    },

    cantidadProducto(producto) {
      const cantidad = this.enteroSeguro(this.cantidades[producto.id], 1);
      return Math.min(cantidad, Math.max(1, this.cantidadMaxima(producto)));
    },

    puedeAumentarProducto(producto) {
      return !this.estaAgotado(producto) &&
        this.cantidadProducto(producto) < this.cantidadMaxima(producto);
    },

    reducirCantidadProducto(producto) {
      this.cantidades[producto.id] = Math.max(1, this.cantidadProducto(producto) - 1);
    },

    aumentarCantidadProducto(producto) {
      if (!this.puedeAumentarProducto(producto)) return;
      this.cantidades[producto.id] = this.cantidadProducto(producto) + 1;
    },

    /* ── Carrito: se persisten únicamente id y cantidad. ── */
    restaurarCarrito() {
      if (!this._claveCarrito) return;
      try {
        const contenido = JSON.parse(localStorage.getItem(this._claveCarrito) || '{}');
        const guardados = Array.isArray(contenido) ? contenido : contenido.items;
        this.tipoEntrega = Array.isArray(contenido) ? '' : String(contenido.tipoEntrega || '');
        this.zonaSeleccionada = Array.isArray(contenido)
          ? ''
          : String(contenido.zonaSeleccionada || '');
        this.metodoPagoSeleccionado = Array.isArray(contenido)
          ? ''
          : String(contenido.metodoPagoSeleccionado || '');
        this.items = Array.isArray(guardados)
          ? guardados.map((item) => this.restaurarItem(item)).filter((item) => item !== null)
          : [];
      } catch (_) {
        this.items = [];
      }
    },

    restaurarItem(itemGuardado) {
      if (!itemGuardado || typeof itemGuardado !== 'object') return null;
      const id = String(itemGuardado.id || '');
      const producto = this.todos.find((actual) => actual.id === id);
      if (!producto || this.estaAgotado(producto)) return null;
      const cantidad = Math.min(
        this.enteroSeguro(itemGuardado.cant, 1),
        this.cantidadMaxima(producto)
      );
      return this.crearItem(producto, cantidad);
    },

    crearItem(producto, cantidad) {
      return {
        id: producto.id,
        nombre: producto.nombre,
        precio: this.numeroSeguro(producto.precio),
        urlImagen: this.imagenProducto(producto),
        stock: this.enteroSeguro(producto.stock, 0),
        esStockInfinito: producto.esStockInfinito === true,
        tieneDelivery: producto.tieneDelivery === true,
        cant: cantidad,
      };
    },

    guardarCarrito() {
      if (!this._claveCarrito) return;
      try {
        localStorage.setItem(this._claveCarrito, JSON.stringify({
          items: this.items.map((item) => ({ id: item.id, cant: item.cant })),
          tipoEntrega: this.tipoEntrega,
          zonaSeleccionada: this.zonaSeleccionada,
          metodoPagoSeleccionado: this.metodoPagoSeleccionado,
        }));
      } catch (_) {
        // El catálogo funciona aunque el navegador bloquee localStorage.
      }
    },

    agregar(producto) {
      if (this.estaAgotado(producto)) return;
      const solicitada = this.cantidadProducto(producto);
      const existente = this.items.find((item) => item.id === producto.id);
      if (existente) {
        existente.cant = Math.min(
          existente.cant + solicitada,
          this.cantidadMaxima(producto)
        );
      } else {
        this.items.push(this.crearItem(producto, solicitada));
      }
      this.cantidades[producto.id] = 1;
      this.inicializarOpciones();
      this.guardarCarrito();
      this.abrirCarrito();
    },

    restar(item) {
      if (item.cant <= 1) return;
      item.cant -= 1;
      this.guardarCarrito();
    },

    puedeSumarItem(item) {
      const producto = this.todos.find((actual) => actual.id === item.id);
      return Boolean(producto) && item.cant < this.cantidadMaxima(producto);
    },

    sumar(item) {
      if (!this.puedeSumarItem(item)) return;
      item.cant += 1;
      this.guardarCarrito();
    },

    eliminarItem(item) {
      this.items = this.items.filter((actual) => actual.id !== item.id);
      this.guardarCarrito();
    },

    abrirCarrito() {
      this.carritoAbierto = true;
      document.body.classList.add('cart-open');
    },

    cerrarCarrito() {
      this.carritoAbierto = false;
      document.body.classList.remove('cart-open');
      this.guardarCarrito();
    },

    get totalItems() {
      return this.items.reduce((total, item) => total + this.enteroSeguro(item.cant, 0), 0);
    },

    numeroSeguro(valor) {
      const numero = Number(valor);
      return Number.isFinite(numero) && numero >= 0 ? numero : 0;
    },

    get subtotal() {
      return this.items.reduce(
        (total, item) => total + this.numeroSeguro(item.precio) * this.enteroSeguro(item.cant, 0),
        0
      );
    },

    get zonasDelivery() {
      return Array.isArray(this.negocio.deliveryZonas)
        ? this.negocio.deliveryZonas
        : [];
    },

    get puedeDelivery() {
      const productosCompatibles = this.items.every(
        (item) => item.tieneDelivery === true
      );
      return this.negocio.delivery === true &&
        this.zonasDelivery.length > 0 && productosCompatibles;
    },

    get puedeRecojo() {
      return Boolean(String(this.negocio.direccion || '').trim());
    },

    get hayOpcionesEntrega() {
      return this.puedeDelivery || this.puedeRecojo;
    },

    claveZona(zona, indice) {
      return this.valorZona(zona) + '-' + String(indice);
    },

    valorZona(zona) {
      const nombre = encodeURIComponent(String(zona.zona || '').trim());
      return nombre + ':' + this.numeroSeguro(zona.costo).toFixed(2);
    },

    textoZona(zona) {
      return String(zona.zona || '') + ' · ' + this.fmt(zona.costo);
    },

    get zonaActual() {
      const valorSeleccionado = String(this.zonaSeleccionada || '').trim();
      if (!valorSeleccionado) return null;
      return this.zonasDelivery.find(
        (zona) => this.valorZona(zona) === valorSeleccionado
      ) || null;
    },

    get costoDelivery() {
      return this.tipoEntrega === 'delivery' && this.zonaActual
        ? this.numeroSeguro(this.zonaActual.costo)
        : 0;
    },

    nombreMetodo(id) {
      return NOMBRES_METODOS[id] || String(id || '');
    },

    configMetodo(id) {
      const configuraciones = this.negocio.configPagos;
      if (!configuraciones || typeof configuraciones !== 'object') return {};
      const config = configuraciones[id];
      return config && typeof config === 'object' ? config : {};
    },

    get metodosPago() {
      const metodos = Array.isArray(this.negocio.metodosPago)
        ? this.negocio.metodosPago
        : [];
      return metodos.map((id) => {
        const config = this.configMetodo(id);
        return {
          id: id,
          nombre: this.nombreMetodo(id),
          numero: String(config.numero || '').trim(),
          descuentoActivo: config.descuentoActivo === true,
          montoMinimo: this.numeroSeguro(config.montoMinimo),
          tipoDescuento: String(config.tipoDescuento || ''),
          valorDescuento: this.numeroSeguro(config.valorDescuento),
        };
      });
    },

    get nombresMetodosPago() {
      return this.metodosPago.map((metodo) => metodo.nombre).join(', ');
    },

    mensajeDescuento(metodo) {
      if (!metodo.descuentoActivo || metodo.valorDescuento <= 0) return '';
      if (metodo.tipoDescuento !== 'porcentaje' &&
          metodo.tipoDescuento !== 'monto_fijo') return '';
      const beneficio = metodo.tipoDescuento === 'porcentaje'
        ? Math.min(metodo.valorDescuento, 100) + '% de descuento'
        : this.fmt(metodo.valorDescuento) + ' de descuento';
      return metodo.montoMinimo > 0
        ? beneficio + ' desde ' + this.fmt(metodo.montoMinimo)
        : beneficio;
    },

    get metodoPagoActual() {
      return this.metodosPago.find(
        (metodo) => metodo.id === this.metodoPagoSeleccionado
      ) || null;
    },

    get descuento() {
      const metodo = this.metodoPagoActual;
      if (!metodo || !metodo.descuentoActivo || metodo.valorDescuento <= 0) return 0;
      if (this.subtotal < metodo.montoMinimo) return 0;
      if (metodo.tipoDescuento === 'porcentaje') {
        return this.subtotal * Math.min(metodo.valorDescuento, 100) / 100;
      }
      if (metodo.tipoDescuento === 'monto_fijo') {
        return Math.min(this.subtotal, metodo.valorDescuento);
      }
      return 0;
    },

    get etiquetaDescuento() {
      const metodo = this.metodoPagoActual;
      if (!metodo) return 'Descuento';
      return 'Descuento por ' + metodo.nombre;
    },

    get total() {
      return Math.max(0, this.subtotal + this.costoDelivery - this.descuento);
    },

    get horariosActivos() {
      return Array.isArray(this.negocio.horarios)
        ? this.negocio.horarios.filter((horario) => horario.activo === true)
        : [];
    },

    textoHorario(horario) {
      const apertura = String(horario.apertura || '').trim();
      const cierre = String(horario.cierre || '').trim();
      if (!apertura && !cierre) return '';
      return apertura + (cierre ? ' – ' + cierre : '');
    },

    get resumenHorarios() {
      return this.horariosActivos
        .slice(0, 3)
        .map((horario) => horario.dia + ' ' + this.textoHorario(horario))
        .join(' · ');
    },

    urlRedSocial(valor, dominiosPermitidos) {
      const url = this.urlHttpsSegura(valor);
      if (!url) return '';
      try {
        const host = new URL(url).hostname.toLowerCase();
        const permitido = dominiosPermitidos.some(
          (dominio) => host === dominio || host.endsWith('.' + dominio)
        );
        return permitido ? url : '';
      } catch (_) {
        return '';
      }
    },

    get redesSociales() {
      const candidatas = [
        ['Facebook', this.negocio.facebook, ['facebook.com']],
        ['Instagram', this.negocio.instagram, ['instagram.com']],
        ['TikTok', this.negocio.tiktok, ['tiktok.com']],
        ['YouTube', this.negocio.youtube, ['youtube.com', 'youtu.be']],
      ];
      return candidatas.reduce((resultado, candidata) => {
        const url = this.urlRedSocial(candidata[1], candidata[2]);
        if (url) resultado.push({ nombre: candidata[0], url: url });
        return resultado;
      }, []);
    },

    get hayInformacionComercial() {
      return this.negocio.delivery === true || this.puedeRecojo ||
        this.metodosPago.length > 0 || this.horariosActivos.length > 0;
    },

    get hayInformacionNegocio() {
      return Boolean(this.negocio.nombre || this.negocio.rubro ||
        this.negocio.direccion || this.negocio.ruc || this.negocio.telefono ||
        this.horariosActivos.length || this.metodosPago.length || this.redesSociales.length);
    },

    get hayContacto() {
      return Boolean(this.negocio.telefono || this.negocio.direccion || this.redesSociales.length);
    },

    numeroWhatsApp() {
      return String(this.negocio.telefono || '')
        .replace(/[^\d]/g, '')
        .replace(/^00/, '');
    },

    get telefonoWhatsAppValido() {
      const telefono = this.numeroWhatsApp();
      return /^[1-9]\d{7,14}$/.test(telefono);
    },

    get puedeEnviarWhatsApp() {
      if (!this.items.length || !this.telefonoWhatsAppValido) return false;
      return this.tipoEntrega !== 'delivery' || Boolean(this.zonaActual);
    },

    crearResumenPedido() {
      const lineas = this.items.map((item) => {
        const importe = this.numeroSeguro(item.precio) * this.enteroSeguro(item.cant, 0);
        return '- ' + item.nombre + ' x' + item.cant + ': ' + this.fmt(importe);
      });
      const resumen = [
        'Hola ' + this.negocio.nombre + ', quiero consultar este pedido:',
        '',
        ...lineas,
        '',
        'Subtotal: ' + this.fmt(this.subtotal),
      ];

      if (this.tipoEntrega === 'delivery' && this.zonaActual) {
        resumen.push('Entrega: Delivery en ' + this.zonaActual.zona);
        resumen.push('Costo de delivery: ' + this.fmt(this.costoDelivery));
      } else if (this.tipoEntrega === 'recojo') {
        resumen.push('Entrega: Recojo o atención en el local');
      }

      if (this.metodoPagoActual) {
        resumen.push('Método de pago: ' + this.metodoPagoActual.nombre);
      }
      if (this.descuento > 0) {
        resumen.push(this.etiquetaDescuento + ': -' + this.fmt(this.descuento));
      }
      resumen.push('Total: ' + this.fmt(this.total));
      resumen.push('', 'Quedo atento a la confirmación de disponibilidad.');
      return resumen.join('\n');
    },

    get waPedido() {
      if (!this.puedeEnviarWhatsApp) return '';
      return 'https://wa.me/' + this.numeroWhatsApp() +
        '?text=' + encodeURIComponent(this.crearResumenPedido());
    },

    abrirWhatsApp() {
      if (!this.puedeEnviarWhatsApp) return;
      this.guardarCarrito();
      const ventana = window.open(this.waPedido, '_blank', 'noopener,noreferrer');
      if (ventana) ventana.opener = null;
    },

    get waGeneral() {
      if (!this.telefonoWhatsAppValido) return '#contacto';
      const mensaje = 'Hola ' + this.negocio.nombre + ', quiero consultar sobre sus productos.';
      return 'https://wa.me/' + this.numeroWhatsApp() + '?text=' + encodeURIComponent(mensaje);
    },

    fmt(valor) {
      return CargarNegocio.formatearPrecio(this.numeroSeguro(valor));
    },
  }));
});
