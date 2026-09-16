import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { after, before, beforeEach, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteField,
  doc,
  getDoc,
  setDoc,
  setLogLevel,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'yapiventa-firestore-rules-tests';
const rulesPath = fileURLToPath(new URL('../../firestore.rules', import.meta.url));

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
});

after(async () => {
  await testEnv?.cleanup();
});

function dbFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

async function seedDocuments(documents) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const batch = writeBatch(context.firestore());
    for (const [path, data] of Object.entries(documents)) {
      batch.set(doc(context.firestore(), path), data);
    }
    await batch.commit();
  });
}

test('users create accepts only the authorized profile fields', async () => {
  const db = dbFor('owner');
  await assertSucceeds(
    setDoc(doc(db, 'users/owner'), {
      email: 'owner@example.test',
      terminosAceptados: true,
      createdAt: Timestamp.now(),
    }),
  );

  for (const forbiddenField of ['webActiva', 'setupComplete', 'rubro']) {
    const uid = `user-with-${forbiddenField}`;
    await assertFails(
      setDoc(doc(dbFor(uid), `users/${uid}`), {
        email: 'owner@example.test',
        createdAt: Timestamp.now(),
        [forbiddenField]: true,
      }),
    );
  }

  await assertFails(
    setDoc(doc(dbFor('invalid-created-at'), 'users/invalid-created-at'), {
      email: 'invalid@example.test',
      createdAt: 'created-at',
    }),
  );
});

test('a legacy user can update email while legacy fields remain unchanged', async () => {
  await seedDocuments({
    'users/legacy-user': {
      email: 'old@example.test',
      terminosAceptados: true,
      createdAt: 'created-at',
      webActiva: true,
      setupComplete: true,
      legacyPlan: 'founder',
    },
  });

  const db = dbFor('legacy-user');
  const userRef = doc(db, 'users/legacy-user');

  await assertSucceeds(updateDoc(userRef, { email: 'new@example.test' }));

  const snapshot = await assertSucceeds(getDoc(userRef));
  assert.equal(snapshot.data().email, 'new@example.test');
  assert.equal(snapshot.data().webActiva, true);
  assert.equal(snapshot.data().setupComplete, true);
  assert.equal(snapshot.data().legacyPlan, 'founder');
});

test('legacy fields cannot be modified, added, or removed', async () => {
  await seedDocuments({
    'users/legacy-user': {
      email: 'old@example.test',
      createdAt: 'created-at',
      webActiva: true,
      setupComplete: true,
    },
  });

  const userRef = doc(dbFor('legacy-user'), 'users/legacy-user');

  await assertFails(updateDoc(userRef, { webActiva: false }));
  await assertFails(updateDoc(userRef, { legacyPlan: 'new' }));
  await assertFails(updateDoc(userRef, { setupComplete: deleteField() }));
});

test('users.createdAt cannot be changed or removed', async () => {
  await seedDocuments({
    'users/owner': {
      email: 'owner@example.test',
      createdAt: 'created-at',
    },
  });

  const userRef = doc(dbFor('owner'), 'users/owner');
  await assertFails(updateDoc(userRef, { createdAt: 'changed-at' }));
  await assertFails(updateDoc(userRef, { createdAt: deleteField() }));
});

test('users.negocioId can be linked to a new owned business in the same batch', async () => {
  await seedDocuments({
    'users/owner': {
      email: 'owner@example.test',
      createdAt: 'created-at',
    },
  });

  const db = dbFor('owner');
  const batch = writeBatch(db);
  batch.set(doc(db, 'negocios/new-business'), {
    propietarioUid: 'owner',
    webActiva: false,
  });
  batch.update(doc(db, 'users/owner'), { negocioId: 'new-business' });

  await assertSucceeds(batch.commit());

  const createDb = dbFor('created-owner');
  const createBatch = writeBatch(createDb);
  createBatch.set(doc(createDb, 'negocios/created-business'), {
    propietarioUid: 'created-owner',
    webActiva: false,
  });
  createBatch.set(doc(createDb, 'users/created-owner'), {
    email: 'created-owner@example.test',
    createdAt: Timestamp.now(),
    negocioId: 'created-business',
  });

  await assertSucceeds(createBatch.commit());
});

test('an existing users.negocioId cannot be changed or removed', async () => {
  await seedDocuments({
    'users/owner': {
      email: 'owner@example.test',
      createdAt: 'created-at',
      negocioId: 'business-one',
    },
    'negocios/business-one': {
      propietarioUid: 'owner',
      webActiva: false,
    },
    'negocios/business-two': {
      propietarioUid: 'owner',
      webActiva: false,
    },
  });

  const userRef = doc(dbFor('owner'), 'users/owner');
  await assertFails(updateDoc(userRef, { negocioId: 'business-two' }));
  await assertFails(updateDoc(userRef, { negocioId: deleteField() }));
});

test('users.negocioId only links to a new owned business', async () => {
  await seedDocuments({
    'users/owner': {
      email: 'owner@example.test',
      createdAt: 'created-at',
    },
    'negocios/foreign-business': {
      propietarioUid: 'other-owner',
      webActiva: false,
    },
    'negocios/existing-owned-business': {
      propietarioUid: 'owner',
      webActiva: false,
    },
    'negocios/existing-new-owner-business': {
      propietarioUid: 'new-owner',
      webActiva: false,
    },
  });

  const userRef = doc(dbFor('owner'), 'users/owner');
  await assertFails(updateDoc(userRef, { negocioId: 'foreign-business' }));
  await assertFails(updateDoc(userRef, { negocioId: 'existing-owned-business' }));
  await assertFails(updateDoc(userRef, { negocioId: 'missing-business' }));
  await assertFails(
    setDoc(doc(dbFor('new-owner'), 'users/new-owner'), {
      email: 'new-owner@example.test',
      negocioId: 'existing-new-owner-business',
    }),
  );
});

test('negocios create requires webActiva to be a boolean', async () => {
  const db = dbFor('owner');

  await assertSucceeds(
    setDoc(doc(db, 'negocios/valid-business'), {
      propietarioUid: 'owner',
      webActiva: false,
    }),
  );
  await assertFails(
    setDoc(doc(db, 'negocios/missing-web-activa'), {
      propietarioUid: 'owner',
    }),
  );
  await assertFails(
    setDoc(doc(db, 'negocios/string-web-activa'), {
      propietarioUid: 'owner',
      webActiva: 'false',
    }),
  );
});

test('negocios.propietarioUid is immutable', async () => {
  await seedDocuments({
    'negocios/owned-business': {
      propietarioUid: 'owner',
      webActiva: false,
    },
  });

  const businessRef = doc(dbFor('owner'), 'negocios/owned-business');
  await assertFails(updateDoc(businessRef, { propietarioUid: 'other-owner' }));
  await assertFails(updateDoc(businessRef, { propietarioUid: deleteField() }));
});

test('public webActiva must be boolean and match the private business', async () => {
  await seedDocuments({
    'negocios/owned-business': {
      propietarioUid: 'owner',
      slug: 'valid-store',
      webActiva: true,
    },
    'negocios/non-boolean-business': {
      propietarioUid: 'owner',
      slug: 'non-boolean-store',
      webActiva: true,
    },
    'negocios/mismatched-business': {
      propietarioUid: 'owner',
      slug: 'mismatched-store',
      webActiva: true,
    },
  });

  const db = dbFor('owner');
  await assertSucceeds(
    setDoc(doc(db, 'negocios_publicos/valid-store'), {
      negocioId: 'owned-business',
      webActiva: true,
    }),
  );
  await assertFails(
    setDoc(doc(db, 'negocios_publicos/non-boolean-store'), {
      negocioId: 'non-boolean-business',
      webActiva: 'true',
    }),
  );
  await assertFails(
    setDoc(doc(db, 'negocios_publicos/mismatched-store'), {
      negocioId: 'mismatched-business',
      webActiva: false,
    }),
  );
  await assertFails(
    updateDoc(doc(db, 'negocios_publicos/valid-store'), {
      webActiva: 'true',
    }),
  );
});

test('a public projection must use the private business slug', async () => {
  await seedDocuments({
    'negocios/owned-business': {
      propietarioUid: 'owner',
      slug: 'canonical-store',
      webActiva: true,
    },
  });

  await assertFails(
    setDoc(doc(dbFor('owner'), 'negocios_publicos/alias-store'), {
      negocioId: 'owned-business',
      webActiva: true,
    }),
  );
});

test('an atomic batch can change matching private and public webActiva values', async () => {
  await seedDocuments({
    'negocios/owned-business': {
      propietarioUid: 'owner',
      slug: 'owned-store',
      webActiva: false,
    },
    'negocios_publicos/owned-store': {
      negocioId: 'owned-business',
      webActiva: false,
    },
  });

  const db = dbFor('owner');
  const batch = writeBatch(db);
  batch.update(doc(db, 'negocios/owned-business'), { webActiva: true });
  batch.update(doc(db, 'negocios_publicos/owned-store'), { webActiva: true });

  await assertSucceeds(batch.commit());
});

test('an atomic batch can move a business to a new public slug', async () => {
  await seedDocuments({
    'negocios/owned-business': {
      propietarioUid: 'owner',
      slug: 'old-store',
      nombreNegocio: 'Old store',
      webActiva: false,
    },
    'negocios_publicos/old-store': {
      negocioId: 'owned-business',
      slug: 'old-store',
      nombreNegocio: 'Old store',
      webActiva: false,
    },
  });

  const db = dbFor('owner');
  const batch = writeBatch(db);
  batch.update(doc(db, 'negocios/owned-business'), {
    slug: 'new-store',
    nombreNegocio: 'New store',
  });
  batch.set(doc(db, 'negocios_publicos/new-store'), {
    negocioId: 'owned-business',
    slug: 'new-store',
    nombreNegocio: 'New store',
    webActiva: false,
  });
  batch.delete(doc(db, 'negocios_publicos/old-store'));

  await assertSucceeds(batch.commit());

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    const privateBusiness = await getDoc(
      doc(adminDb, 'negocios/owned-business'),
    );
    const oldPublic = await getDoc(
      doc(adminDb, 'negocios_publicos/old-store'),
    );
    const newPublic = await getDoc(
      doc(adminDb, 'negocios_publicos/new-store'),
    );

    assert.equal(privateBusiness.data().slug, 'new-store');
    assert.equal(oldPublic.exists(), false);
    assert.equal(newPublic.data().slug, 'new-store');
    assert.equal(newPublic.data().nombreNegocio, 'New store');
  });
});

test('a private-only webActiva update is rejected as an incomplete batch', async () => {
  await seedDocuments({
    'negocios/owned-business': {
      propietarioUid: 'owner',
      slug: 'owned-store',
      webActiva: false,
    },
    'negocios_publicos/owned-store': {
      negocioId: 'owned-business',
      webActiva: false,
    },
  });

  await assertFails(
    updateDoc(doc(dbFor('owner'), 'negocios/owned-business'), {
      webActiva: true,
    }),
  );
});

test('a private-only update cannot exploit an already divergent public value', async () => {
  await seedDocuments({
    'negocios/owned-business': {
      propietarioUid: 'owner',
      slug: 'owned-store',
      webActiva: false,
    },
    'negocios_publicos/owned-store': {
      negocioId: 'owned-business',
      webActiva: true,
    },
  });

  await assertFails(
    updateDoc(doc(dbFor('owner'), 'negocios/owned-business'), {
      webActiva: true,
    }),
  );
});

test('a contradictory public webActiva update is rejected', async () => {
  await seedDocuments({
    'negocios/owned-business': {
      propietarioUid: 'owner',
      slug: 'owned-store',
      webActiva: false,
    },
    'negocios_publicos/owned-store': {
      negocioId: 'owned-business',
      webActiva: false,
    },
  });

  await assertFails(
    updateDoc(doc(dbFor('owner'), 'negocios_publicos/owned-store'), {
      webActiva: true,
    }),
  );
});

test('a public-only update cannot exploit an already divergent private value', async () => {
  await seedDocuments({
    'negocios/owned-business': {
      propietarioUid: 'owner',
      slug: 'owned-store',
      webActiva: true,
    },
    'negocios_publicos/owned-store': {
      negocioId: 'owned-business',
      webActiva: false,
    },
  });

  await assertFails(
    updateDoc(doc(dbFor('owner'), 'negocios_publicos/owned-store'), {
      webActiva: true,
    }),
  );
});

test('a missing public document prevents changing private webActiva', async () => {
  await seedDocuments({
    'negocios/owned-business': {
      propietarioUid: 'owner',
      slug: 'missing-store',
      webActiva: false,
    },
  });

  await assertFails(
    updateDoc(doc(dbFor('owner'), 'negocios/owned-business'), {
      webActiva: true,
    }),
  );
});
