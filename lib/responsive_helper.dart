import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Tipos de dispositivos soportados
enum DeviceType {
  mobile,
  tablet,
  desktop,
}

/// Helper para detectar el tipo de dispositivo y crear layouts responsive
class ResponsiveHelper {
  // Breakpoints para diferentes tamaños de pantalla
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Detecta si la aplicación se está ejecutando en un dispositivo desktop
  static bool isDesktop() {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Detecta si la aplicación se está ejecutando en un dispositivo móvil
  static bool isMobile() {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Obtiene el tipo de dispositivo basado en el ancho de la pantalla
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= desktopBreakpoint) {
      return DeviceType.desktop;
    } else if (width >= tabletBreakpoint) {
      return DeviceType.tablet;
    } else {
      return DeviceType.mobile;
    }
  }

  /// Verifica si el ancho de la pantalla es suficiente para layouts desktop
  static bool isWideScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  /// Verifica si el ancho de la pantalla es móvil
  static bool isNarrowScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Obtiene el número de columnas recomendado para un GridView según el tamaño de pantalla
  static int getGridColumnCount(BuildContext context, {int mobile = 2, int tablet = 3, int desktop = 4}) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet;
      case DeviceType.desktop:
        return desktop;
    }
  }

  /// Obtiene el padding horizontal recomendado según el tamaño de pantalla
  static double getHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktopBreakpoint) {
      return 48.0;
    } else if (width >= tabletBreakpoint) {
      return 32.0;
    } else {
      return 16.0;
    }
  }

  /// Obtiene el padding vertical recomendado según el tamaño de pantalla
  static double getVerticalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktopBreakpoint) {
      return 32.0;
    } else if (width >= tabletBreakpoint) {
      return 24.0;
    } else {
      return 16.0;
    }
  }

  /// Obtiene el ancho máximo para contenido en pantallas grandes
  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktopBreakpoint) {
      return 1400.0; // Ancho máximo para desktop
    }
    return width;
  }

  /// Widget que se adapta según el tamaño de pantalla
  static Widget responsive({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    required Widget desktop,
  }) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop;
    }
  }

  /// Tamaño de fuente responsive
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return baseFontSize;
      case DeviceType.tablet:
        return baseFontSize * 1.1;
      case DeviceType.desktop:
        return baseFontSize * 1.15;
    }
  }

  /// Espaciado responsive
  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return baseSpacing;
      case DeviceType.tablet:
        return baseSpacing * 1.2;
      case DeviceType.desktop:
        return baseSpacing * 1.5;
    }
  }

  /// Obtiene el tamaño de icono recomendado según el dispositivo
  static double getIconSize(BuildContext context, double baseSize) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return baseSize;
      case DeviceType.tablet:
        return baseSize * 1.2;
      case DeviceType.desktop:
        return baseSize * 1.3;
    }
  }

  /// Verifica si debe mostrarse el drawer permanente (para desktop)
  static bool shouldShowPersistentDrawer(BuildContext context) {
    return isDesktop() && isWideScreen(context);
  }

  /// Obtiene el ancho recomendado para el drawer permanente
  static double getDrawerWidth(BuildContext context) {
    return 280.0;
  }
}

/// Widget base para crear layouts responsive fácilmente
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    Key? key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveHelper.responsive(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
}
