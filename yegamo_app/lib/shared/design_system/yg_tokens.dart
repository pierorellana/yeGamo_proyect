import 'package:flutter/material.dart';

/// Tokens del prototipo yeGamo «Bosque claro» (fuente: prototipo/Main.dc.html
/// y assets/colores-y-tokens). Todas las pantallas deben consumir estos
/// valores en lugar de literales sueltos.
abstract final class YgColors {
  static const moss = Color(0xFF2C3424);
  static const cypress = Color(0xFF4C583E);
  static const olive = Color(0xFF768064);
  static const cedar = Color(0xFF959581);
  static const aloe = Color(0xFFDADED8);
  static const clay = Color(0xFF9C4F3A);

  static const text = Color(0xFF1E2419);
  static const text2 = Color(0xFF5B624F);
  static const text3 = Color(0xFF6E7362);

  static const white = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const page = Color(0xFFF4F5F1);
  static const fill = Color(0xFFEEF0EA);
  static const fill2 = Color(0xFFF4F6F0);
  static const fill3 = Color(0xFFF1F2EE);
  static const control = Color(0xFFEAECE5);
  static const border = Color(0xFFE6E8E1);
  static const borderStrong = Color(0xFFE1E4DB);
  static const divider = Color(0xFFEEF0EA);
  static const handle = Color(0xFFD3D7CC);
  static const handleHover = Color(0xFFB9BEAF);
  static const track = Color(0xFFE6E9E0);
  static const muted = Color(0xFFB9BCA9);

  // Mapa
  static const mapLand = Color(0xFFF3F4EF);
  static const mapBlock = Color(0xFFE3E6DD);
  static const mapBlockFar = Color(0xFFE9EBE4);
  static const mapWater = Color(0xFFC8D3CC);
  static const mapShore = Color(0xFFB6C3BA);
  static const mapPark = Color(0xFFD3DBC6);
  static const mapRoadCasing = Color(0xFFD2D6CA);
  static const routeAlt = Color(0xFFABAD98);
}

abstract final class YgSpace {
  static const x05 = 4.0;
  static const x1 = 8.0;
  static const x15 = 12.0;
  static const x2 = 16.0;
  static const x3 = 24.0;
  static const x4 = 32.0;

  /// Margen lateral de pantalla.
  static const gutter = 16.0;

  /// Separación entre secciones.
  static const section = 24.0;

  /// Padding interno de tarjeta.
  static const card = 16.0;
}

abstract final class YgRadius {
  static const chip = 16.0;
  static const tile = 10.0;
  static const card = 20.0;
  static const banner = 16.0;
  static const sheet = 32.0;
  static const pill = 9999.0;
}

abstract final class YgSize {
  static const buttonLg = 56.0;
  static const buttonMd = 48.0;
  static const buttonSm = 36.0;
  static const iconButton = 44.0;
  static const iconButtonSm = 36.0;
  static const tile = 36.0;
  static const listRow = 56.0;
  static const chip = 32.0;
  static const topbar = 44.0;

  /// Y de la barra superior (debajo de la status bar del prototipo).
  static const topbarY = 56.0;

  /// Y de avisos y banners flotantes (debajo de la barra superior).
  static const floatY = 108.0;
  static const tabbarHeight = 64.0;
  static const tabbarBottom = 24.0;
  static const touch = 44.0;
}

abstract final class YgMotion {
  static const sheet = Duration(milliseconds: 550);
  static const enter = Duration(milliseconds: 500);
  static const tap = Duration(milliseconds: 300);
  static const camera = Duration(milliseconds: 1300);
  static const vehicleTick = Duration(seconds: 1);
  static const reduced = Duration(milliseconds: 120);

  static const spring = Cubic(.3, 1.16, .4, 1);
  static const easeOut = Cubic(.22, 1, .36, 1);
  static const tapCurve = Cubic(.34, 1.56, .64, 1);
  static const cameraCurve = Cubic(.2, .85, .25, 1);
  static const popCurve = Cubic(.34, 1.3, .5, 1);
  static const drawCurve = Cubic(.6, 0, .2, 1);
}

/// Estilos de texto del prototipo. La fuente es la del sistema (SF Pro en
/// Apple), igual que el prototipo (`-apple-system … "Geist"`).
abstract final class YgText {
  static const _tab = [FontFeature.tabularFigures()];

  static const heroTime = TextStyle(
    fontSize: 64,
    fontWeight: FontWeight.w600,
    letterSpacing: -2.56,
    height: 1,
    color: YgColors.moss,
    fontFeatures: _tab,
  );
  static const summaryTime = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.92,
    height: 1,
    color: YgColors.moss,
    fontFeatures: _tab,
  );
  static const display = TextStyle(
    fontSize: 46,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.84,
    height: 1,
    color: YgColors.moss,
    fontFeatures: _tab,
  );
  static const largeTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -.7,
    height: 1.15,
    color: YgColors.text,
  );
  static const title2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -.44,
    height: 1.2,
    color: YgColors.text,
  );
  static const title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -.34,
    height: 1.25,
    color: YgColors.text,
  );
  static const sub = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -.15,
    height: 1.3,
    color: YgColors.text,
  );
  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -.15,
    height: 1.4,
    color: YgColors.text,
  );
  static const bodyStrong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -.15,
    height: 1.4,
    color: YgColors.text,
  );
  static const secondary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -.13,
    height: 1.4,
    color: YgColors.text2,
  );
  static const meta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: -.12,
    height: 1.35,
    color: YgColors.text2,
  );
  static const overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: .66,
    height: 1.3,
    color: YgColors.text3,
  );
  static const eta = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -.6,
    color: YgColors.text,
    fontFeatures: _tab,
  );
}

abstract final class YgShadows {
  /// `inset 0 0 0 1px #E6E8E1, 0 1px 2px rgba(44,52,36,.03),
  /// 0 8px 20px rgba(44,52,36,.04)`; el inset se dibuja con borde.
  static const card = [
    BoxShadow(color: Color(0x082C3424), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A2C3424), blurRadius: 20, offset: Offset(0, 8)),
  ];
  static const glass = [
    BoxShadow(color: Color(0x1F2C3424), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const sheet = [
    BoxShadow(color: Color(0x1F2C3424), blurRadius: 30, offset: Offset(0, -6)),
  ];
  static const pri = [
    BoxShadow(color: Color(0x2E2C3424), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const go = [
    BoxShadow(color: Color(0x384C583E), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const float = [
    BoxShadow(color: Color(0x242C3424), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

/// Compatibilidad con el código anterior al rediseño. Los nombres se
/// conservan pero ahora apuntan a la paleta clara del prototipo.
abstract final class YgTokens {
  static const base = YgColors.page;
  static const surface = YgColors.surface;
  static const surfaceElevated = YgColors.surface;
  static const accent = YgColors.cypress;
  static const textPrimary = YgColors.text;
  static const textSecondary = YgColors.text2;
  static const textTertiary = YgColors.text3;

  static const space1 = YgSpace.x05;
  static const space2 = YgSpace.x1;
  static const space3 = YgSpace.x15;
  static const space4 = YgSpace.x2;
  static const space5 = YgSpace.x3;
  static const touchTarget = YgSize.touch;

  static const radiusBanner = YgRadius.banner;
  static const radiusCard = YgRadius.card;
  static const radiusSheet = YgRadius.sheet;
  static const radiusPill = YgRadius.pill;
  static const heightPill = YgSize.buttonMd;
}
