import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registers the selected prototype assets', () async {
    const assets = <String>[
      'assets/logo/lockup/png/yegamo-lockup-horizontal-claro@3x.png',
      'assets/logo/simbolo/png/yegamo-simbolo-oscuro-512.png',
      'assets/ilustraciones/png/onboarding-mini-ruta@3x.png',
      'assets/ilustraciones/png/vacio-busqueda@3x.png',
      'assets/ilustraciones/png/error-ruta@3x.png',
      'assets/ilustraciones/png/guardados-vacio@3x.png',
      'assets/ilustraciones/png/avisos-vacio@3x.png',
      'assets/mapa/png/etiqueta-estimada@3x.png',
      'assets/mapa/png/etiqueta-en-vivo@3x.png',
      'assets/iconos/svg/reintentar.svg',
      'assets/iconos/svg/sin-conexion.svg',
      'assets/iconos/svg/ubicacion-desactivada.svg',
      'assets/iconos/svg/casa.svg',
      'assets/iconos/svg/trabajo.svg',
      'assets/iconos/svg/preferencias.svg',
      'assets/iconos/svg/campana.svg',
    ];

    for (final asset in assets) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }
  });
}
