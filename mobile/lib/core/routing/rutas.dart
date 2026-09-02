/// Nombres de las rutas de la app, en un solo lugar.
///
/// Están aparte de main.dart para que un test pueda comprobar que toda
/// ruta a la que se navega esté realmente registrada — navegar a un
/// nombre que no existe no da error de compilación, revienta en runtime.
class Rutas {
  Rutas._();

  static const login = '/';
  static const verificarCorreo = '/verificar-correo';
  static const elegirRubro = '/elegir-rubro';
  static const configurarNegocio = '/configurar-negocio';
  static const home = '/home';

  /// Rutas del mapa `routes` de MaterialApp (las que no reciben datos).
  static const declaradas = <String>{
    login,
    verificarCorreo,
    elegirRubro,
    home,
  };

  /// Rutas que se arman en `onGenerateRoute` porque reciben argumentos.
  static const generadas = <String>{configurarNegocio};

  static const todas = <String>{...declaradas, ...generadas};
}
