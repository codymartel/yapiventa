// ═════════════════════════════════════════════════════════════════════════
// Configuración central de Firebase para los moldes web de YapiVenta.
// Valores extraídos de DefaultFirebaseOptions.web (mobile/lib/firebase_options.dart).
// Los moldes cargan este archivo ANTES que cargar-negocio.js.
// ═════════════════════════════════════════════════════════════════════════
window.YAPI_FIREBASE_CONFIG = {
  apiKey: 'AIzaSyAzQCT6ROO6csao35wtB70k-ow0-c7Mzd4',
  authDomain: 'yapiventa.firebaseapp.com',
  projectId: 'yapiventa',
  storageBucket: 'yapiventa.firebasestorage.app',
  messagingSenderId: '359947632947',
  appId: '1:359947632947:web:4dc78637cedac4081ebe46',
  measurementId: 'G-PM8T6SR4CZ',
};

if (typeof firebase !== 'undefined' && firebase.apps.length === 0) {
  firebase.initializeApp(window.YAPI_FIREBASE_CONFIG);
}