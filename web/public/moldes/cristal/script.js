/* ═══════════════════════════════════════════════════════════════════════
   MOLDE CRISTAL — lógica Alpine (catálogo + filtro por categoría + modal).
   Los datos llegan desde shared/cargar-negocio.js; aquí NO se consulta
   Firestore.
   ═══════════════════════════════════════════════════════════════════════ */
document.addEventListener('alpine:init', () => {
  Alpine.data('catalogo', () => ({
    cargando: true,
    error: '',
    negocio: {},
    todos: [],
    categorias: [],
    categoriaActiva: '',
    activo: null,

    async cargar() {
      try {
        this.cargando = true;
        const datos = await CargarNegocio.obtener();
        this.negocio = datos.negocio;
        this.todos = datos.productos;
        this.categorias = datos.categorias;
      } catch (e) {
        this.error = e && e.message ? e.message : String(e);
      } finally {
        this.cargando = false;
      }
    },

    get filtrados() {
      const porCategoria = (p) =>
        !this.categoriaActiva || p.categoria === this.categoriaActiva;
      return this.todos.filter(porCategoria);
    },

    abrir(p) {
      this.activo = p;
      document.body.style.overflow = 'hidden';
    },
    cerrar() {
      this.activo = null;
      document.body.style.overflow = '';
    },

    fmt(v) { return CargarNegocio.formatearPrecio(v); },
    stockDisponible(p) { return p && !p.esStockInfinito && p.stock > 0; },

    get waGeneral() { return CargarNegocio.urlWhatsApp(this.negocio, null); },
    get waProducto() { return CargarNegocio.urlWhatsApp(this.negocio, this.activo); },
  }));
});