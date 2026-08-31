// ═════════════════════════════════════════════════════════════════════════
// PaisTelefono
// ═════════════════════════════════════════════════════════════════════════
//
// QUÉ HACE ESTE ARCHIVO:
// Reemplaza la validación "+51 fijo, 9 dígitos" que tenía tu Kotlin
// (pensada solo para Perú) por un selector de país: el usuario elige su
// país, y el sistema ya sabe el prefijo correcto y cuántos dígitos debe
// tener el número, sin necesitar código distinto por país.
//
// ALCANCE: cubre los 19 países de Latinoamérica continental + Rep.
// Dominicana. Los dígitos son la longitud típica del número de celular
// (sin contar el prefijo de país), según el estándar de numeración de
// cada país.
//
// NO VALIDAMOS documentos tributarios (RUC/NIT/RFC/etc.) por país — eso
// se decidió dejarlo como texto libre y opcional, sin formato específico,
// porque no es una app de facturación formal.
//
// CON QUÉ SE CONECTA:
// - Lo usará el widget del paso "Negocio" del wizard de configuración,
//   en el campo de WhatsApp — un dropdown de país al lado del campo de
//   número, en vez del prefijo "+51" fijo que había antes.
// ═════════════════════════════════════════════════════════════════════════

class PaisTelefono {
  final String nombre;
  final String prefijo;
  final int digitosEsperados;

  const PaisTelefono({
    required this.nombre,
    required this.prefijo,
    required this.digitosEsperados,
  });
}

const List<PaisTelefono> paisesLatam = [
  PaisTelefono(nombre: 'Argentina', prefijo: '+54', digitosEsperados: 10),
  PaisTelefono(nombre: 'Bolivia', prefijo: '+591', digitosEsperados: 8),
  PaisTelefono(nombre: 'Brasil', prefijo: '+55', digitosEsperados: 11),
  PaisTelefono(nombre: 'Chile', prefijo: '+56', digitosEsperados: 9),
  PaisTelefono(nombre: 'Colombia', prefijo: '+57', digitosEsperados: 10),
  PaisTelefono(nombre: 'Costa Rica', prefijo: '+506', digitosEsperados: 8),
  PaisTelefono(nombre: 'Cuba', prefijo: '+53', digitosEsperados: 8),
  PaisTelefono(nombre: 'Ecuador', prefijo: '+593', digitosEsperados: 9),
  PaisTelefono(nombre: 'El Salvador', prefijo: '+503', digitosEsperados: 8),
  PaisTelefono(nombre: 'Guatemala', prefijo: '+502', digitosEsperados: 8),
  PaisTelefono(nombre: 'Honduras', prefijo: '+504', digitosEsperados: 8),
  PaisTelefono(nombre: 'México', prefijo: '+52', digitosEsperados: 10),
  PaisTelefono(nombre: 'Nicaragua', prefijo: '+505', digitosEsperados: 8),
  PaisTelefono(nombre: 'Panamá', prefijo: '+507', digitosEsperados: 8),
  PaisTelefono(nombre: 'Paraguay', prefijo: '+595', digitosEsperados: 9),
  PaisTelefono(nombre: 'Perú', prefijo: '+51', digitosEsperados: 9),
  PaisTelefono(
    nombre: 'República Dominicana',
    prefijo: '+1',
    digitosEsperados: 10,
  ),
  PaisTelefono(nombre: 'Uruguay', prefijo: '+598', digitosEsperados: 8),
  PaisTelefono(nombre: 'Venezuela', prefijo: '+58', digitosEsperados: 10),
];

/// Valida un número ya sin el prefijo (solo los dígitos que escribió el
/// usuario) contra la cantidad esperada para el país elegido.
bool telefonoValidoParaPais(String numero, PaisTelefono pais) {
  final soloDigitos = numero.replaceAll(RegExp(r'[^0-9]'), '');
  return soloDigitos.length == pais.digitosEsperados;
}