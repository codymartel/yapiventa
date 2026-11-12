import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { after, before, beforeEach, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  serverTimestamp,
  setDoc,
  setLogLevel,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

// Reglas del cobro de un pedido (`cobro`: dónde entró la plata a la caja) y
// de lo «por cobrar» del resumen del día. Solo el dueño las escribe y con la
// forma correcta. También `pedidoPor` de la venta de mostrador (paso R).

const projectId = 'yapiventa-cobros-caja-rules-tests';
const rulesPath = fileURLToPath(new URL('../../firestore.rules', import.meta.url));

const DUENO = 'dueno-1';
const OTRO = 'dueno-2';
const NEGOCIO = 'negocio-1';
const PEDIDO = `negocios/${NEGOCIO}/pedidos/p1`;
const RESUMEN = `negocios/${NEGOCIO}/resumenes/2026-11-12`;

let testEnv;

setLogLevel('silent');

before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      'FIRESTORE_EMULATOR_HOST is missing. Run this suite through firebase emulators:exec.',
    );
  }
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules: await readFile(rulesPath, 'utf8') },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (contexto) => {
    const db = contexto.firestore();
    const lote = writeBatch(db);
    lote.set(doc(db, `negocios/${NEGOCIO}`), {
      propietarioUid: DUENO,
      webActiva: false,
    });
    lote.set(doc(db, 'negocios/negocio-2'), {
      propietarioUid: OTRO,
      webActiva: false,
    });
    lote.set(doc(db, PEDIDO), {
      negocioId: NEGOCIO,
      estado: 'entregado',
      estadoPago: 'pendiente',
      totalCentavos: 4000,
    });
    await lote.commit();
  });
});

after(async () => {
  await testEnv?.cleanup();
});

const dbDe = (uid) => testEnv.authenticatedContext(uid).firestore();
const dbAnonima = () => testEnv.unauthenticatedContext().firestore();

const COBRADO = { dia: '2026-11-12', pago: 'efectivo', centavos: 4000 };
const PENDIENTE = { centavos: 4000, porCobrarDia: '2026-11-12' };

/** Venta de mostrador en el local, como la escribe Caja. */
function ventaMostrador(cambios = {}) {
  return {
    negocioId: NEGOCIO,
    clave: 'VENTA1',
    estado: 'entregado',
    origen: 'mostrador',
    enLocal: true,
    tipoEntrega: 'recojo',
    fecha: serverTimestamp(),
    cliente: {},
    deliveryCentavos: 0,
    descuentoCentavos: 0,
    subtotalCentavos: 900,
    totalCentavos: 900,
    lineas: [{ productoId: 'gaseosa', cantidad: 2 }],
    metodoPago: 'efectivo',
    estadoPago: 'pagado',
    stockDescontado: [],
    reembolso: 'ninguno',
    historial: [{ estado: 'entregado', fecha: Timestamp.now() }],
    actualizadoEn: serverTimestamp(),
    cobro: { dia: '2026-11-12', pago: 'efectivo', centavos: 900 },
    ...cambios,
  };
}

test('el dueño guarda el cobro al marcar cobrado o al entregar sin cobrar', async () => {
  const db = dbDe(DUENO);
  await assertSucceeds(updateDoc(doc(db, PEDIDO), { cobro: PENDIENTE }));
  await assertSucceeds(
    updateDoc(doc(db, PEDIDO), {
      estadoPago: 'pagado',
      cobro: { ...COBRADO, porCobrarDia: '2026-11-12' },
    }),
  );
});

test('un cobro con otra forma se rechaza', async () => {
  const ref = doc(dbDe(DUENO), PEDIDO);
  await assertFails(updateDoc(ref, { cobro: { ...COBRADO, extra: 1 } }));
  await assertFails(updateDoc(ref, { cobro: { ...COBRADO, centavos: -1 } }));
  await assertFails(updateDoc(ref, { cobro: { ...COBRADO, centavos: 40.5 } }));
  await assertFails(updateDoc(ref, { cobro: { ...COBRADO, dia: 'hoy' } }));
  await assertFails(updateDoc(ref, { cobro: { ...COBRADO, pago: 'Yape Plin' } }));
  await assertFails(updateDoc(ref, { cobro: 'efectivo' }));
});

test('otro negocio y un visitante anónimo no tocan el cobro', async () => {
  await assertFails(updateDoc(doc(dbDe(OTRO), PEDIDO), { cobro: COBRADO }));
  await assertFails(updateDoc(doc(dbAnonima(), PEDIDO), { cobro: COBRADO }));
});

test('la venta de mostrador nace con su cobro (y sin él también)', async () => {
  const db = dbDe(DUENO);
  await assertSucceeds(
    setDoc(doc(db, `negocios/${NEGOCIO}/pedidos/v1`), ventaMostrador()),
  );
  const { cobro, ...sinCobro } = ventaMostrador();
  await assertSucceeds(
    setDoc(doc(db, `negocios/${NEGOCIO}/pedidos/v2`), sinCobro),
  );
  await assertFails(
    setDoc(
      doc(db, `negocios/${NEGOCIO}/pedidos/v3`),
      ventaMostrador({ cobro: { ...cobro, centavos: -900 } }),
    ),
  );
});

test('la venta en tienda guarda por dónde la pidió antes (lista cerrada)', async () => {
  const db = dbDe(DUENO);
  const ref = (id) => doc(db, `negocios/${NEGOCIO}/pedidos/${id}`);
  for (const por of ['whatsapp', 'facebook', 'llamada', 'otro']) {
    await assertSucceeds(setDoc(ref(`r-${por}`), ventaMostrador({ pedidoPor: por })));
  }
  await assertFails(setDoc(ref('r1'), ventaMostrador({ pedidoPor: 'instagram' })));
  await assertFails(setDoc(ref('r2'), ventaMostrador({ pedidoPor: '' })));
  await assertFails(setDoc(ref('r3'), ventaMostrador({ pedidoPor: true })));
});

test('un delivery de Caja no lleva pedidoPor', async () => {
  const db = dbDe(DUENO);
  const delivery = {
    enLocal: false,
    tipoEntrega: 'delivery',
    estado: 'confirmado',
    zona: 'Centro',
    cliente: { nombre: 'Ana', telefono: '999888777', direccion: 'Av. Lima 1' },
    cobro: { dia: '2026-11-12', pago: 'efectivo', centavos: 900 },
  };
  await assertSucceeds(
    setDoc(doc(db, `negocios/${NEGOCIO}/pedidos/d1`), ventaMostrador(delivery)),
  );
  await assertFails(
    setDoc(
      doc(db, `negocios/${NEGOCIO}/pedidos/d2`),
      ventaMostrador({ ...delivery, pedidoPor: 'whatsapp' }),
    ),
  );
});

test('el resumen del día acepta lo por cobrar en enteros >= 0', async () => {
  const ref = doc(dbDe(DUENO), RESUMEN);
  await assertSucceeds(
    setDoc(ref, { porCobrarCentavos: 4000, porCobrar: 1, porPago: {} }),
  );
  await assertFails(setDoc(ref, { porCobrarCentavos: -1 }));
  await assertFails(setDoc(ref, { porCobrar: 1.5 }));
  await assertFails(setDoc(doc(dbDe(OTRO), RESUMEN), { porCobrar: 1 }));
});
