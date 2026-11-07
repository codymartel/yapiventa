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
  setDoc,
  setLogLevel,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

// Reglas de ELIMINAR CUENTA: nada se borra, salvo que el negocio esté marcado
// `eliminando` por su dueño. Se ejecuta con firebase emulators:exec.

const projectId = 'yapiventa-eliminar-cuenta-tests';
const rulesPath = fileURLToPath(new URL('../../firestore.rules', import.meta.url));

let testEnv;

setLogLevel('silent');

before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error('FIRESTORE_EMULATOR_HOST is missing. Use firebase emulators:exec.');
  }
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules: await readFile(rulesPath, 'utf8') },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv?.cleanup();
});

const dbFor = (uid) => testEnv.authenticatedContext(uid).firestore();
const dbAnonima = () => testEnv.unauthenticatedContext().firestore();

async function sembrar({ eliminando = false } = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/owner'), { email: 'a@b.c' });
    await setDoc(doc(db, 'users/owner/plan/actual'), { tipo: 'free' });
    await setDoc(doc(db, 'negocios/n1'), {
      propietarioUid: 'owner',
      webActiva: false,
      slug: 'mi-tienda',
      ...(eliminando ? { eliminando: true } : {}),
    });
    await setDoc(doc(db, 'negocios/n1/pedidos/p1'), { negocioId: 'n1', estado: 'nuevo' });
    await setDoc(doc(db, 'negocios/n1/resumenes/2026-11-07'), { ventasCentavos: 100 });
    await setDoc(doc(db, 'negocios/n1/productos/prod1'), { negocioId: 'n1', disponible: true });
    await setDoc(doc(db, 'negocios_publicos/mi-tienda'), {
      negocioId: 'n1',
      webActiva: false,
    });
  });
}

test('sin marcar el negocio nadie borra pedidos ni resúmenes, ni el dueño', async () => {
  await sembrar();
  const db = dbFor('owner');
  await assertFails(deleteDoc(doc(db, 'negocios/n1/pedidos/p1')));
  await assertFails(deleteDoc(doc(db, 'negocios/n1/resumenes/2026-11-07')));
});

test('el dueño marca su negocio como eliminando', async () => {
  await sembrar();
  await assertSucceeds(updateDoc(doc(dbFor('owner'), 'negocios/n1'), { eliminando: true }));
});

test('eliminando debe ser booleano', async () => {
  await sembrar();
  await assertFails(updateDoc(doc(dbFor('owner'), 'negocios/n1'), { eliminando: 'si' }));
});

test('otro usuario no puede marcar el negocio ajeno', async () => {
  await sembrar();
  await assertFails(updateDoc(doc(dbFor('intruso'), 'negocios/n1'), { eliminando: true }));
  await assertFails(updateDoc(doc(dbAnonima(), 'negocios/n1'), { eliminando: true }));
});

test('con el negocio marcado el dueño borra pedidos y resúmenes', async () => {
  await sembrar({ eliminando: true });
  const db = dbFor('owner');
  await assertSucceeds(deleteDoc(doc(db, 'negocios/n1/pedidos/p1')));
  await assertSucceeds(deleteDoc(doc(db, 'negocios/n1/resumenes/2026-11-07')));
});

test('con el negocio marcado, otro usuario o la tienda anónima siguen sin borrar', async () => {
  await sembrar({ eliminando: true });
  await assertFails(deleteDoc(doc(dbFor('intruso'), 'negocios/n1/pedidos/p1')));
  await assertFails(deleteDoc(doc(dbAnonima(), 'negocios/n1/pedidos/p1')));
  await assertFails(deleteDoc(doc(dbAnonima(), 'negocios/n1/resumenes/2026-11-07')));
});

test('el dueño borra productos, su página pública, el negocio, su plan y su perfil', async () => {
  await sembrar({ eliminando: true });
  const db = dbFor('owner');
  await assertSucceeds(deleteDoc(doc(db, 'negocios/n1/productos/prod1')));
  await assertSucceeds(deleteDoc(doc(db, 'negocios_publicos/mi-tienda')));
  await assertSucceeds(deleteDoc(doc(db, 'negocios/n1')));
  await assertSucceeds(deleteDoc(doc(db, 'users/owner/plan/actual')));
  await assertSucceeds(deleteDoc(doc(db, 'users/owner')));
});

test('nadie borra el perfil, el negocio ni la página pública de otro', async () => {
  await sembrar({ eliminando: true });
  const db = dbFor('intruso');
  await assertFails(deleteDoc(doc(db, 'users/owner')));
  await assertFails(deleteDoc(doc(db, 'negocios/n1')));
  await assertFails(deleteDoc(doc(db, 'negocios_publicos/mi-tienda')));
  await assertFails(deleteDoc(doc(dbAnonima(), 'users/owner')));
});

test('el dueño borra 400 pedidos en un solo lote (el tamaño que usa la app)', async () => {
  await sembrar({ eliminando: true });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const lote = writeBatch(context.firestore());
    for (let i = 0; i < 400; i++) {
      lote.set(doc(context.firestore(), `negocios/n1/pedidos/masivo${i}`), { negocioId: 'n1' });
    }
    await lote.commit();
  });
  const db = dbFor('owner');
  const lote = writeBatch(db);
  for (let i = 0; i < 400; i++) lote.delete(doc(db, `negocios/n1/pedidos/masivo${i}`));
  await assertSucceeds(lote.commit());
});
