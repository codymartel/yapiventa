import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/caja/caja_dependencies.dart';
import 'package:mobile/features/caja/presentation/providers/informes_caja_provider.dart';
import 'package:mobile/features/caja/presentation/providers/preparacion_catalogo_provider.dart';
import 'package:mobile/features/pedidos/application/services/periodo_informe.dart';
import 'package:mobile/features/pedidos/application/use_cases/obtener_informe_ventas.dart';
import 'package:mobile/features/pedidos/data/resumenes_ventas_repository.dart';
import 'package:mobile/features/pedidos/data/ventas_mostrador_repository.dart';
import 'package:mobile/features/productos/application/use_cases/preparar_catalogo_caja.dart';
import 'package:mobile/features/productos/data/catalogo_caja_repository.dart';
import 'package:mobile/features/productos/data/relleno_catalogo_caja_repository.dart';
import 'package:mobile/features/productos/domain/repositories/repositorio_relleno_catalogo.dart';

class _RellenoFalso implements RepositorioRellenoCatalogo {
  bool listo = false;
  Object? fallaAlLeer;
  Object? fallaAlRellenar;
  ResultadoRelleno resultado = const ResultadoRelleno(
    actualizados: 36,
    yaCompletos: 2,
    total: 38,
  );
  int rellenos = 0;
  int lecturasMarca = 0;

  @override
  Future<bool> catalogoListo(String negocioId) async {
    lecturasMarca++;
    if (fallaAlLeer != null) throw fallaAlLeer!;
    return listo;
  }

  @override
  Future<ResultadoRelleno> rellenar(String negocioId) async {
    rellenos++;
    if (fallaAlRellenar != null) throw fallaAlRellenar!;
    return resultado;
  }
}

void main() {
  group('PreparacionCatalogoProvider', () {
    late _RellenoFalso repo;
    late PreparacionCatalogoProvider p;

    setUp(() {
      repo = _RellenoFalso();
      p = PreparacionCatalogoProvider(
        negocioId: 'n1',
        preparar: PrepararCatalogoCaja(repo),
      );
    });

    test(
      'al verificar, si falta preparar pide confirmar y NO escribe nada',
      () async {
        await p.verificar();

        expect(p.estado, EstadoPreparacion.pideConfirmar);
        expect(p.hayQueMostrar, isTrue);
        expect(repo.rellenos, 0);
        expect(repo.lecturasMarca, 1);
      },
    );

    test('si ya estaba preparado no muestra nada', () async {
      repo.listo = true;

      await p.verificar();

      expect(p.estado, EstadoPreparacion.noHaceFalta);
      expect(p.hayQueMostrar, isFalse);
    });

    test('verificar dos veces lee la marca una sola vez', () async {
      await p.verificar();
      await p.verificar();

      expect(repo.lecturasMarca, 1);
    });

    test(
      'sin conexión al abrir: no bloquea Caja y vuelve a preguntar luego',
      () async {
        repo.fallaAlLeer = Exception('sin red');
        await p.verificar();

        expect(p.estado, EstadoPreparacion.desconocido);
        expect(p.hayQueMostrar, isFalse);
        repo.fallaAlLeer = null;
        await p.verificar();
        expect(p.estado, EstadoPreparacion.pideConfirmar);
      },
    );

    test(
      'preparar: bloquea las ventas mientras corre y termina en «lista»',
      () async {
        await p.verificar();
        final estados = <EstadoPreparacion>[];
        p.addListener(() => estados.add(p.estado));

        await p.preparar();

        expect(estados, [
          EstadoPreparacion.preparando,
          EstadoPreparacion.lista,
        ]);
        expect(p.bloqueaVentas, isFalse);
        expect(p.resultado!.total, 38);
        expect(p.resultado!.actualizados, 36);
        expect(repo.rellenos, 1);
      },
    );

    test('un segundo toque en «Preparar ahora» no corre dos veces', () async {
      final a = p.preparar();
      await p.preparar();
      await a;

      expect(repo.rellenos, 1);
    });

    test('más de 500 productos: estado «demasiados», con límites', () async {
      repo.resultado = const ResultadoRelleno(demasiados: true, total: 501);

      await p.preparar();

      expect(p.estado, EstadoPreparacion.demasiados);
      expect(p.conLimites, isTrue);
      expect(p.hayQueMostrar, isTrue);
    });

    test('un corte: error, y reintentar completa', () async {
      repo.fallaAlRellenar = Exception('sin red');
      await p.preparar();
      expect(p.estado, EstadoPreparacion.error);
      expect(p.bloqueaVentas, isFalse);
      expect(p.conLimites, isTrue);

      repo.fallaAlRellenar = null;
      await p.preparar();

      expect(p.estado, EstadoPreparacion.lista);
    });

    test(
      '«Más tarde»: Caja sigue con límites y no pregunta de nuevo',
      () async {
        await p.verificar();

        p.posponer();

        expect(p.estado, EstadoPreparacion.pospuesta);
        expect(p.conLimites, isTrue);
        expect(p.hayQueMostrar, isFalse);
        await p.verificar();
        expect(p.estado, EstadoPreparacion.pospuesta);
        expect(repo.lecturasMarca, 1);
      },
    );

    test('cerrar el aviso de «Listo» lo da por terminado', () async {
      await p.preparar();

      p.cerrarListo();

      expect(p.estado, EstadoPreparacion.noHaceFalta);
    });
  });

  group('InformesCajaProvider', () {
    late FakeFirebaseFirestore db;
    late InformesCajaProvider p;
    final jueves = DateTime.utc(2026, 11, 5, 19, 32);

    Future<void> resumen(String dia, int ventas, int entregados) => db
        .collection('negocios')
        .doc('n1')
        .collection('resumenes')
        .doc(dia)
        .set({'ventasCentavos': ventas, 'entregados': entregados});

    setUp(() async {
      db = FakeFirebaseFirestore();
      p = InformesCajaProvider(
        negocioId: 'n1',
        obtener: ObtenerInformeVentas(ResumenesVentasRepository(db: db)),
        reloj: () => jueves,
      );
      await resumen('2026-11-05', 3000, 3);
      await resumen('2026-11-04', 2000, 4);
    });

    test('al iniciar carga hoy y lo compara con ayer', () async {
      await p.iniciar();

      expect(p.cargando, isFalse);
      expect(p.informe!.actual.ventasCentavos, 3000);
      expect(p.informe!.anterior!.ventasCentavos, 2000);
      expect(p.informe!.ventas!.porcentaje, 50);
    });

    test('cambiar a semana vuelve a consultar el rango de 7 días', () async {
      await p.iniciar();

      await p.elegirPeriodo(TipoPeriodo.semana);

      expect(p.tipo, TipoPeriodo.semana);
      expect(p.informe!.actual.ventasCentavos, 5000);
      expect(p.informe!.actual.desde, '2026-10-30');
    });

    test('un día elegido', () async {
      await p.elegirPeriodo(TipoPeriodo.dia, dia: '2026-11-04');

      expect(p.informe!.actual.ventasCentavos, 2000);
      expect(p.dia, '2026-11-04');
    });

    test('un día inválido da un mensaje y no rompe', () async {
      await p.elegirPeriodo(TipoPeriodo.dia, dia: 'ayer');

      expect(p.error, 'Ese día no es válido.');
      expect(p.cargando, isFalse);
    });

    test('sin comparar no hay periodo anterior', () async {
      await p.cambiarComparar(false);

      expect(p.informe!.anterior, isNull);
      expect(p.informe!.ventas, isNull);
    });

    test('sin ventas: informe vacío, no error', () async {
      await p.elegirPeriodo(TipoPeriodo.dia, dia: '2026-10-01');

      expect(p.error, isNull);
      expect(p.informe!.actual.sinMovimientos, isTrue);
    });
  });

  test('CajaDependencies arma los providers con el mismo negocio', () {
    final db = FakeFirebaseFirestore();
    final deps = CajaDependencies.conRepositorios(
      ventas: VentasMostradorRepository(db: db),
      resumenes: ResumenesVentasRepository(db: db),
      catalogo: CatalogoCajaRepository(db),
      relleno: RellenoCatalogoCajaRepository(db),
    );

    final venta = deps.crearVenta('n1');
    final catalogo = deps.crearCatalogo('n1');
    final preparacion = deps.crearPreparacion('n1');
    final informes = deps.crearInformes('n1');

    expect(venta.negocioId, 'n1');
    expect(catalogo.negocioId, 'n1');
    expect(preparacion.negocioId, 'n1');
    expect(informes.negocioId, 'n1');
    for (final c in [venta, catalogo, preparacion, informes]) {
      c.dispose();
    }
  });
}
