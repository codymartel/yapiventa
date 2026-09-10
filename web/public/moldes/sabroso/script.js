/* ═══════════════════════════════════════════════════════════════════════
   MOLDE SABROSO — lógica Alpine (menú + filtro + modal grande).
   Los datos llegan desde shared/cargar-negocio.js; aquí NO se consulta
   Firestore. Pedidos vía WhatsApp con mensaje pre-armado del plato.
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

    init() {
      this.cargar();
    },

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
    ocultarImagen(producto) {
      producto.urlImagen = '';
    },

    fmt(v) { return CargarNegocio.formatearPrecio(v); },

    get waGeneral() { return CargarNegocio.urlWhatsApp(this.negocio, null); },
    get waProducto() { return CargarNegocio.urlWhatsApp(this.negocio, this.activo); },
  }));
});
