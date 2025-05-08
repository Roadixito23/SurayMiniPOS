import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Clase optimizadora para gestionar recursos de PDF y mejorar rendimiento
class PdfOptimizer {
  // Imágenes almacenadas en caché
  pw.ImageProvider? _logoImage;
  pw.ImageProvider? _endImage;
  pw.ImageProvider? _tijeraImage;

  // Rutas de los assets
  final String _logoPath = 'assets/logobkwt.png';
  final String _endPath = 'assets/endTicket.png';
  final String _tijeraPath = 'assets/tijera.png';

  // Flag para saber si ya se han precargado los recursos
  bool _resourcesLoaded = false;

  // Constructor
  PdfOptimizer();

  // Método para crear un documento con configuraciones optimizadas
  pw.Document createDocument() {
    return pw.Document(
      compress: true,
      version: PdfVersion.pdf_1_5,
      verbose: false,
    );
  }

  // Método para precargar todos los recursos
  Future<void> preloadResources() async {
    if (!_resourcesLoaded) {
      try {
        _logoImage = await _loadImageAsset(_logoPath);
        _endImage = await _loadImageAsset(_endPath);
        _tijeraImage = await _loadImageAsset(_tijeraPath);
        _resourcesLoaded = true;
      } catch (e) {
        debugPrint('Error al precargar recursos: $e');
        throw e;
      }
    }
  }

  // Obtener logo (con fallback)
  pw.ImageProvider getLogoImage() {
    if (_logoImage == null) {
      return _createFallbackImage();
    }
    return _logoImage!;
  }

  // Obtener imagen de fin (con fallback)
  pw.ImageProvider getEndImage() {
    if (_endImage == null) {
      return _createFallbackImage();
    }
    return _endImage!;
  }

  // Obtener imagen de tijera (con fallback)
  pw.ImageProvider getTijeraImage() {
    if (_tijeraImage == null) {
      return _createFallbackImage();
    }
    return _tijeraImage!;
  }

  // Método para limpiar caché de imágenes
  void clearCache() {
    _logoImage = null;
    _endImage = null;
    _tijeraImage = null;
    _resourcesLoaded = false;
  }

  // Método privado para cargar imagen desde assets
  Future<pw.ImageProvider?> _loadImageAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error al cargar imagen "$path": $e');
      return null;
    }
  }

  // Crear imagen de fallback para casos donde no se pueda cargar la original
  pw.ImageProvider _createFallbackImage() {
    final List<int> pixels = List<int>.generate(
      256 * 256 * 4,
          (int index) => index % 4 < 3 ? 0xFF : 0x88,
    );

    return pw.MemoryImage(Uint8List.fromList(pixels));
  }
}