import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { after, before, beforeEach, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  setLogLevel,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

// Reglas de los gastos rápidos de Caja (negocios/{id}/gastos/{id}) y de sus
// sumas en el resumen del día. Lo principal: SOLO el dueño del negocio los
// crea, los lee y los anula; otro negocio y un visitante anónimo no pueden.

const projectId = 'yapiventa-gastos-caja-rules-tests';
const rulesPath = fileURLToPath(new URL('../../firestore.rules', import.meta.url));

const DUENO = 'dueno-1';
const OTRO = 'dueno-2';
const NEGOCIO = 'negocio-1';
const GASTO = `negocios/${NEGOCIO}/gastos/g1`;
const RESUMEN = `negocios/${NEGOCIO}/resumenes/2026-11-11`;

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
  await sembrar({
    [`negocios/${NEGOCIO}`]: { propietarioUid: DUENO, webActiva: false },
    'negocios/negocio-2': { propietarioUid: OTRO, webActiva: false },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

function dbDe(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function dbAnonima() {
  return testEnv.unauthenticatedContext().firestore();
}

async function sembrar(documentos) {
  await testEnv.withSecurityRulesDisabled(async (contexto) => {
    const lote = writeBatch(contexto.firestore());
    for (const [ruta, datos] of Object.entries(documentos)) {
      lote.set(doc(contexto.firestore(), ruta), datos);
    }
    await lote.commit();
  });
}

function gastoNuevo(cambios = {}) {
  return {
    montoCentavos: 1000,
    motivo: 'comida',
    metodoPago: 'efectivo',
    dia: '2026-11-11',
    fecha: serverTimestamp(),
    anulado: false,
    ...cambios,
  };
}

const gastoGuardado = {
  montoCentavos: 1000,
  motivo: 'comida',
  metodoPago: 'efectivo',
  dia: '2026-11-11',
  fecha: Timestamp.fromMillis(1_800_000_000_000),
  anulado: false,
};

test('el dueño guarda un gasto y lo suma al resumen en el mismo lote', async () => {
  const db = dbDe(DUENO);
  const lote = writeBatch(db);
  lote.set(doc(db, GASTO), gastoNuevo({ nota: 'almuerzo' }));
  lote.set(
    doc(db, RESUMEN),
    {
      gastosCentavos: 1000,
      gastos: 1,
      porGastoPago: { efectivo: 1000 },
      porGastoMotivo: { comida: 1000 },
      actualizadoEn: serverTimestamp(),
    },
    { merge: true },
  );
  await assertSucceeds(lote.commit());
  await assertSucceeds(getDoc(doc(db, GASTO)));
});

test('otro negocio no puede crear, leer ni anular gastos ajenos', async () => {
  await sembrar({ [GASTO]: gastoGuardado });
  const db = dbDe(OTRO);
  await assertFails(setDoc(doc(db, `negocios/${NEGOCIO}/gastos/g2`), gastoNuevo()));
  await assertFails(getDoc(doc(db, GASTO)));
  await assertFails(
    updateDoc(doc(db, GASTO), { anulado: true, anuladoEn: serverTimestamp() }),
  );
});

test('un visitante anónimo no puede crear ni leer gastos', async () => {
  await sembrar({ [GASTO]: gastoGuardado });
  const db = dbAnonima();
  await assertFails(setDoc(doc(db, `negocios/${NEGOCIO}/gastos/g2`), gastoNuevo()));
  await assertFails(getDoc(doc(db, GASTO)));
});

test('un gasto inválido se rechaza', async () => {
  const db = dbDe(DUENO);
  const ruta = doc(db, GASTO);
  await assertFails(setDoc(ruta, gastoNuevo({ montoCentavos: 0 })));
  await assertFails(setDoc(ruta, gastoNuevo({ montoCentavos: -500 })));
  await assertFails(setDoc(ruta, gastoNuevo({ montoCentavos: 10.5 })));
  await assertFails(setDoc(ruta, gastoNuevo({ montoCentavos: 10000001 })));
  await assertFails(setDoc(ruta, gastoNuevo({ motivo: 'fiesta' })));
  await assertFails(setDoc(ruta, gastoNuevo({ metodoPago: 'Efectivo!' })));
  await assertFails(setDoc(ruta, gastoNuevo({ dia: '11/11/2026' })));
  await assertFails(setDoc(ruta, gastoNuevo({ nota: 'x'.repeat(121) })));
  await assertFails(setDoc(ruta, gastoNuevo({ anulado: true })));
  await assertFails(setDoc(ruta, gastoNuevo({ negocioId: 'negocio-2' })));
  await assertFails(
    setDoc(ruta, gastoNuevo({ fecha: Timestamp.fromMillis(1_000_000_000_000) })),
  );
});

test('el dueño anula un gasto una sola vez y no puede cambiar el monto', async () => {
  await sembrar({ [GASTO]: gastoGuardado });
  const db = dbDe(DUENO);
  const ruta = doc(db, GASTO);
  await assertFails(updateDoc(ruta, { montoCentavos: 1 }));
  await assertFails(
    updateDoc(ruta, {
      anulado: true,
      anuladoEn: serverTimestamp(),
      montoCentavos: 1,
    }),
  );
  await assertFails(updateDoc(ruta, { anulado: true }));
  await assertSucceeds(
    updateDoc(ruta, { anulado: true, anuladoEn: serverTimestamp() }),
  );
  // Ya anulado: no se puede "desanular" ni volver a anular.
  await assertFails(
    updateDoc(ruta, { anulado: false, anuladoEn: serverTimestamp() }),
  );
  await assertFails(
    updateDoc(ruta, { anulado: true, anuladoEn: serverTimestamp() }),
  );
});

test('los gastos no se borran (salvo al eliminar la cuenta)', async () => {
  await sembrar({ [GASTO]: gastoGuardado });
  await assertFails(deleteDoc(doc(dbDe(DUENO), GASTO)));
  await assertFails(deleteDoc(doc(dbDe(OTRO), GASTO)));

  await sembrar({
    [`negocios/${NEGOCIO}`]: {
      propietarioUid: DUENO,
      webActiva: false,
      eliminando: true,
    },
  });
  await assertFails(deleteDoc(doc(dbDe(OTRO), GASTO)));
  await assertSucceeds(deleteDoc(doc(dbDe(DUENO), GASTO)));
});

test('el resumen rechaza sumas de gastos negativas, raras o de otro negocio', async () => {
  const db = dbDe(DUENO);
  const ruta = doc(db, RESUMEN);
  await assertFails(setDoc(ruta, { gastosCentavos: -1 }));
  await assertFails(setDoc(ruta, { gastos: -1 }));
  await assertFails(setDoc(ruta, { gastosCentavos: '1000' }));
  await assertFails(setDoc(ruta, { porGastoPago: 'efectivo' }));
  await assertFails(setDoc(ruta, { gastosInventados: 1 }));
  await assertFails(
    setDoc(doc(dbDe(OTRO), RESUMEN), { gastosCentavos: 1000, gastos: 1 }),
  );
});

test('sumar gastos no borra las ventas que ya tenía el resumen', async () => {
  await sembrar({
    [RESUMEN]: { ventasCentavos: 30000, entregados: 4, porPago: { efectivo: 30000 } },
  });
  const db = dbDe(DUENO);
  await assertSucceeds(
    setDoc(
      doc(db, RESUMEN),
      {
        gastosCentavos: 1000,
        gastos: 1,
        porGastoPago: { efectivo: 1000 },
        porGastoMotivo: { comida: 1000 },
        actualizadoEn: serverTimestamp(),
      },
      { mergeFields: ['gastosCentavos', 'gastos', 'porGastoPago', 'porGastoMotivo', 'actualizadoEn'] },
    ),
  );
  const guardado = (await getDoc(doc(db, RESUMEN))).data();
  if (guardado.ventasCentavos !== 30000 || guardado.gastosCentavos !== 1000) {
    throw new Error('El resumen perdió las ventas o no guardó los gastos.');
  }
});
