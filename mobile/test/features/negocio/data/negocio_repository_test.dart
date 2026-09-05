import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/negocio/data/negocio_repository.dart';
import 'package:mobile/features/negocio/domain/models/config_pago_metodo.dart';
import 'package:mobile/features/negocio/domain/models/horario_dia.dart';
import 'package:mobile/features/negocio/domain/models/metodo_pago_tipo.dart';
import 'package:mobile/features/negocio/domain/models/zona_delivery.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late NegocioRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = NegocioRepository(firestore: firestore);
  });

  test(
    'actualiza la configuracion y serializa delivery, horarios y pagos',
    () async {
      await firestore.collection('users').doc('usuario-1').set({
        'email': 'ana@example.com',
      });

      await repository.guardarConfiguracionNegocio(
        uid: 'usuario-1',
        nombreNegocio: '  Bodega Ana  ',
        slug: 'bodega-ana',
        telefonoCompleto: '+51999999999',
        direccionCompleta: 'Av. Lima 123',
        ruc: '12345678901',
        facebook: 'facebook.com/bodegaana',
        tiktok: '',
        instagram: 'instagram.com/bodegaana',
        youtube: '',
        categorias: ['Bebidas'],
        unidadesMedida: const [
          UnidadInfoResumen(
            nombre: 'Unidad',
            tipo: 'entera',
            fraccionesPermitidas: [],
            esOpcional: false,
          ),
        ],
        tieneDelivery: true,
        zonasDelivery: const [ZonaDelivery(zona: 'Centro', costo: '7.50')],
        horarios: const [
          HorarioDia(
            dia: 'Lunes',
            apertura: '08:00',
            cierre: '18:00',
            activo: true,
          ),
        ],
        metodosPagoConfig: const [
          ConfigPagoMetodo(
            metodoId: 'yape',
            activo: true,
            numeroPago: '999999999',
            descuentoActivo: true,
            tipoDescuento: TipoDescuento.porcentaje,
            valorDescuento: '10',
            montoMinimo: '20',
          ),
          ConfigPagoMetodo(metodoId: 'efectivo', activo: true),
          ConfigPagoMetodo(metodoId: 'plin'),
        ],
      );

      final datos = (await firestore.collection('users').doc('usuario-1').get())
          .data()!;

      expect(datos['email'], 'ana@example.com');
      expect(datos['nombreNegocio'], 'Bodega Ana');
      expect(datos['setupComplete'], isTrue);
      expect(datos['deliveryZonas'], [
        {'zona': 'Centro', 'costo': 7.5},
      ]);
      expect(datos['horarios'], [
        {
          'dia': 'Lunes',
          'apertura': '08:00',
          'cierre': '18:00',
          'activo': true,
        },
      ]);
      expect(datos['metodosPago'], ['yape', 'efectivo']);
      expect(datos['configPagos'], {
        'yape': {
          'numero': '999999999',
          'descuentoActivo': true,
          'montoMinimo': 20.0,
          'tipoDescuento': 'porcentaje',
          'valorDescuento': 10.0,
        },
      });
    },
  );
}
