/* ═══════════════════════════════════════════════════════════════════════
   MOLDE GALERIA — lógica Alpine (colección + hero + carrito).
   Los datos llegan desde shared/cargar-negocio.js; aquí NO se consulta
   Firestore. El carrito se persiste en localStorage.
   ═══════════════════════════════════════════════════════════════════════ */
document.addEventListener('alpine:init', () => {
  Alpine.data('catalogo', () => ({
    cargando: true,
    error: '',
    negocio: {},
    todos: [],
    categorias: [],
    categoriaActiva: '',

    heroIndex: 0,
    items: [],
    carritoAbierto: false,
    _heroTemporizador: null,
    _claveCarrito: 'yapi_carrito',

    init() {
      this.restaurarCarrito();
      this.cargar();
    },

    async cargar() {
      try {
        this.cargando = true;
        const datos = await CargarNegocio.obtener();
        this.negocio = datos.negocio;
        this.todos = datos.productos;
        this.categorias = datos.categorias;
        this.heroIndex = 0;
        this.iniciarHero();
      } catch (e) {
        this.error = e && e.message ? e.message : String(e);
      } finally {
        this.cargando = false;
      }
    },

    /* Hero: recorre las fotos destacadas UNA sola vez y se detiene.
       Nunca entra en loop infinito. */
    iniciarHero() {
      if (this._heroTemporizador) clearTimeout(this._heroTemporizador);
      const total = Math.min(this.destacadas.length, 3);
      if (total <= 1) return;

      const avanzar = () => {
        this.heroIndex = this.heroIndex + 1;
        if (this.heroIndex < total) {
          this._heroTemporizador = setTimeout(avanzar, 3200);
        }
      };
      this._heroTemporizador = setTimeout(avanzar, 3200);
    },

    get destacadas() {
      return this.todos.filter((p) => p.urlImagen);
    },

    get productosFiltrados() {
      const porCategoria = (p) =>
        !this.categoriaActiva || p.categoria === this.categoriaActiva;
      return this.todos.filter(porCategoria);
    },

    /* ── Carrito (localStorage) ── */
    restaurarCarrito() {
      try {
        const guardado = JSON.parse(localStorage.getItem(this._claveCarrito) || '[]');
        this.items = Array.isArray(guardado) ? guardado : [];
      } catch (e) {
        this.items = [];
      }
    },
    guardarCarrito() {
      try {
        localStorage.setItem(this._claveCarrito, JSON.stringify(this.items));
      } catch (e) { /* almacenamiento no disponible */ }
    },
    ocultarImagen(producto) {
      producto.urlImagen = '';
    },
    agregar(p) {
      if (!p.esStockInfinito && p.stock === 0) return;
      const existente = this.items.find((i) => i.id === p.id);
      if (existente) {
        if (p.esStockInfinito || existente.cant < p.stock) existente.cant += 1;
      } else {
        this.items.push({
          id: p.id,
          nombre: p.nombre,
          precio: p.precio,
          urlImagen: p.urlImagen,
          cant: 1,
        });
      }
      this.guardarCarrito();
    },
    restar(item) {
      item.cant -= 1;
      if (item.cant <= 0) this.eliminarItem(item);
      else this.guardarCarrito();
    },
    sumar(item) {
      item.cant += 1;
      this.guardarCarrito();
    },
    eliminarItem(item) {
      this.items = this.items.filter((i) => i.id !== item.id);
      this.guardarCarrito();
    },

    get totalItems() {
      return this.items.reduce((acc, i) => acc + i.cant, 0);
    },
    get total() {
      return this.items.reduce((acc, i) => acc + i.cant * i.precio, 0);
    },

    /* Pedido consolidado por WhatsApp */
    get waPedido() {
      const telefono = String((this.negocio && this.negocio.telefono) || '')
        .replace(/[^\d]/g, '')
        .replace(/^00/, '');
      const lineas = this.items.map(
        (i) =>
          '• ' + i.nombre + ' x' + i.cant + ' (' + CargarNegocio.formatearPrecio(i.precio) + ')'
      );
      const mensaje =
        'Hola ' + (this.negocio.nombre || '') + ', quiero hacer un pedido:\n' + lineas.join('\n') +
        '\nTotal: ' + CargarNegocio.formatearPrecio(this.total);
      return 'https://wa.me/' + telefono + '?text=' + encodeURIComponent(mensaje);
    },

    get waGeneral() { return CargarNegocio.urlWhatsApp(this.negocio, null); },

    fmt(v) { return CargarNegocio.formatearPrecio(v); },
  }));
});
