import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Nombres de los 43 iconos del prototipo (`assets/iconos/svg/<name>.svg`).
abstract final class YgIcons {
  static const acelerar = 'acelerar';
  static const alerta = 'alerta';
  static const atras = 'atras';
  static const bandera = 'bandera';
  static const bus = 'bus';
  static const buscar = 'buscar';
  static const caminarCompacto = 'caminar-compacto';
  static const caminar = 'caminar';
  static const campana = 'campana';
  static const casa = 'casa';
  static const cerrar = 'cerrar';
  static const check = 'check';
  static const chevronAbajo = 'chevron-abajo';
  static const chevronDerecha = 'chevron-derecha';
  static const descargar = 'descargar';
  static const eliminar = 'eliminar';
  static const escudo = 'escudo';
  static const flechaAdelante = 'flecha-adelante';
  static const flechaAtras = 'flecha-atras';
  static const gimnasio = 'gimnasio';
  static const guardado = 'guardado';
  static const intercambiar = 'intercambiar';
  static const lista = 'lista';
  static const mapa = 'mapa';
  static const mas = 'mas';
  static const menos = 'menos';
  static const navegar = 'navegar';
  static const preferencias = 'preferencias';
  static const recorridoCompleto = 'recorrido-completo';
  static const reducirMovimiento = 'reducir-movimiento';
  static const reintentar = 'reintentar';
  static const reloj = 'reloj';
  static const sinConexion = 'sin-conexion';
  static const telefono = 'telefono';
  static const tendencia = 'tendencia';
  static const trabajo = 'trabajo';
  static const transbordo = 'transbordo';
  static const ubicacionDesactivada = 'ubicacion-desactivada';
  static const ubicacion = 'ubicacion';
  static const universidad = 'universidad';
  static const usuario = 'usuario';
  static const zoomMas = 'zoom-mas';
  static const zoomMenos = 'zoom-menos';
}

/// Icono SVG del prototipo (24×24, trazo 1,8, `currentColor`).
class YgIcon extends StatelessWidget {
  const YgIcon(
    this.name, {
    super.key,
    this.size = 20,
    this.color,
    this.semanticLabel,
  });

  final String name;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? const Color(0xFF2C3424);
    return SvgPicture.asset(
      'assets/iconos/svg/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}

/// Símbolo G-recorrido de la marca.
class YgMark extends StatelessWidget {
  const YgMark({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/logo/simbolo/yegamo-simbolo-claro.svg',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}
