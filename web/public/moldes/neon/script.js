/* ═══════════════════════════════════════════════════════════════════════
   MOLDE NEON — lógica Alpine (catálogo + filtro + búsqueda + modal).
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
    busqueda: '',
    activo: null,

    init() {},

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
      const q = this.busqueda.trim().toLowerCase();
      return this.todos.filter((p) => {
        const porCategoria = !this.categoriaActiva || p.categoria === this.categoriaActiva;
        const porBusqueda =
          !q ||
          (p.nombre || '').toLowerCase().includes(q) ||
          (p.descripcion || '').toLowerCase().includes(q);
        return porCategoria && porBusqueda;
      });
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
    iniciales(nombre) {
      const partes = String(nombre || ' ').split(/\s+/).slice(0, 2);
      return partes.map((p) => p.charAt(0).toUpperCase()).join('') || '?';
    },

    get waGeneral() { return CargarNegocio.urlWhatsApp(this.negocio, null); },
    get waProducto() { return CargarNegocio.urlWhatsApp(this.negocio, this.activo); },
    get waSinProducto() {
      return String((this.negocio && this.negocio.telefono) || '')
        .replace(/[^\d]/g, '')
        .replace(/^00/, '');
    },
  }));
});