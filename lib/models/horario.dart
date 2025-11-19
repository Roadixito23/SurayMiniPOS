import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class HorarioManager {
  // Singleton pattern
  static final HorarioManager _instance = HorarioManager._internal();

  factory HorarioManager() {
    return _instance;
  }

  HorarioManager._internal();

  // Constantes para almacenamiento
  static const String _keyHorariosAysen = 'horarios_aysen';
  static const String _keyHorariosCoyhaique = 'horarios_coyhaique';
  static const String _keySalidasExtras = 'salidas_extras';

  // Salidas Extras (temporales solo del día)
  Map<String, Map<String, dynamic>> _salidasExtras = {};
  // Estructura: {
  //   'horario_destino_categoria': {
  //     'horario': '12:30',
  //     'destino': 'Aysen',
  //     'categoria': 'LunesViernes',
  //     'fecha': '2025-01-15',
  //   }
  // }

  // Datos predeterminados para horarios desde Aysén
  Map<String, List<String>> _horariosAysen = {
    'LunesViernes': [
      '06:55', '08:30', '09:45', '11:05', '12:10', '12:50', '14:05',
      '15:30', '16:40', '17:30', '18:00', '19:20'
    ],
    'Sabados': [
      '08:40', '09:50', '11:10', '12:30', '14:10', '15:40',
      '17:15', '18:25'
    ],
    'DomingosFeriados': [
      '08:40', '10:15', '12:30', '14:00']
  };

  // Datos predeterminados para horarios desde Coyhaique
  Map<String, List<String>> _horariosCoyhaique = {
    'LunesViernes': [
      '06:50', '08:30', '09:45', '11:00', '12:00', '13:10', '14:10',
      '15:40', '17:00', '17:30', '18:10', '19:50'
    ],
    'Sabados': [
      '08:40', '10:00', '11:20', '12:50', '14:00', '15:40',
      '17:15', '18:30'
    ],
    'DomingosFeriados': [
      '10:25', '12:00', '13:45', '15:45']
  };

  // Información de contacto
  Map<String, String> contactoAysen = {
    'direccion': 'Of. Eusebio Ibar 630',
    'telefono': '672 233622'
  };

  Map<String, String> contactoCoyhaique = {
    'direccion': 'Terminal Municipal',
    'telefono': '672 212639'
  };

  Map<String, String> correspondenciaAysen = {
    'direccion': 'Of. Eusebio Ibar 630',
    'telefono': '672 232231',
    'horario': 'Lunes A Viernes\nMañana 09:30 - 13:00\nTarde 15:00 - 19:00\nSábados\nMañana 10:00 - 13:00'
  };

  Map<String, String> correspondenciaCoyhaique = {
    'direccion': 'Arturo Prat 265',
    'telefono': '672 234405',
    'horario': 'Lunes A Viernes\nMañana 09:30 - 13:00\nTarde 15:00 - 19:00\nSábados\nMañana 10:00 - 13:00'
  };

  // Getters para los horarios
  Map<String, List<String>> get horariosAysen => _horariosAysen;
  Map<String, List<String>> get horariosCoyhaique => _horariosCoyhaique;

  // Obtener fecha actual en formato String
  String _getFechaHoy() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  // Obtener salidas extras del día para un destino y categoría específicos
  List<String> getSalidasExtrasDelDia(String destino, String categoria) {
    final hoy = _getFechaHoy();
    List<String> salidas = [];

    _salidasExtras.forEach((key, data) {
      if (data['destino'] == destino &&
          data['categoria'] == categoria &&
          data['fecha'] == hoy) {
        salidas.add(data['horario']);
      }
    });

    return salidas;
  }

  // Obtener todos los horarios (fijos + extras del día) para un destino y categoría
  // CORRECCIÓN: Agregado parámetro fecha para controlar si se incluyen salidas extras
  List<String> obtenerHorariosCompletos(String destino, String categoria, {String? fecha}) {
    List<String> horariosBase = [];

    if (destino == 'Aysen') {
      horariosBase = List.from(_horariosAysen[categoria] ?? []);
    } else {
      horariosBase = List.from(_horariosCoyhaique[categoria] ?? []);
    }

    // Solo agregar salidas extras si la fecha es hoy o no se especifica
    final hoy = _getFechaHoy();
    if (fecha == null || fecha == hoy) {
      horariosBase.addAll(getSalidasExtrasDelDia(destino, categoria));
    }

    // Ordenar por hora
    horariosBase.sort((a, b) {
      int minutosA = _convertirAMinutos(a);
      int minutosB = _convertirAMinutos(b);
      return minutosA.compareTo(minutosB);
    });

    return horariosBase;
  }

  // Convertir horario (HH:MM) a minutos
  int _convertirAMinutos(String horario) {
    List<String> partes = horario.split(':');
    if (partes.length != 2) return 0;
    int horas = int.tryParse(partes[0]) ?? 0;
    int minutos = int.tryParse(partes[1]) ?? 0;
    return horas * 60 + minutos;
  }

  // Agregar una salida extra (solo válida para el día actual)
  Future<void> agregarSalidaExtra(String horario, String destino, String categoria) async {
    final hoy = _getFechaHoy();
    final key = '${horario}_${destino}_$categoria';

    _salidasExtras[key] = {
      'horario': horario,
      'destino': destino,
      'categoria': categoria,
      'fecha': hoy,
    };

    await _guardarSalidasExtras();
    debugPrint('Salida extra agregada: $horario para $destino ($categoria)');
  }

  // Eliminar una salida extra
  Future<void> eliminarSalidaExtra(String horario, String destino, String categoria) async {
    final key = '${horario}_${destino}_$categoria';
    _salidasExtras.remove(key);
    await _guardarSalidasExtras();
    debugPrint('Salida extra eliminada: $horario de $destino ($categoria)');
  }

  // Verificar si un horario es una salida extra
  bool esSalidaExtra(String horario, String destino, String categoria) {
    final hoy = _getFechaHoy();
    final key = '${horario}_${destino}_$categoria';

    if (_salidasExtras.containsKey(key)) {
      return _salidasExtras[key]!['fecha'] == hoy;
    }
    return false;
  }

  // Limpiar salidas extras de días anteriores
  Future<void> limpiarSalidasExtrasPasadas() async {
    final hoy = _getFechaHoy();
    final keysToRemove = <String>[];

    _salidasExtras.forEach((key, data) {
      if (data['fecha'] != hoy) {
        keysToRemove.add(key);
      }
    });

    keysToRemove.forEach((key) {
      _salidasExtras.remove(key);
    });

    if (keysToRemove.isNotEmpty) {
      await _guardarSalidasExtras();
      debugPrint('Salidas extras pasadas limpiadas: ${keysToRemove.length}');
    }
  }

  // Guardar salidas extras en SharedPreferences
  Future<void> _guardarSalidasExtras() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySalidasExtras, jsonEncode(_salidasExtras));
      debugPrint('Salidas extras guardadas correctamente');
    } catch (e) {
      debugPrint('Error al guardar salidas extras: $e');
    }
  }

  // Cargar salidas extras desde SharedPreferences
  Future<void> _cargarSalidasExtras() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (prefs.containsKey(_keySalidasExtras)) {
        final String salidasExtrasJson = prefs.getString(_keySalidasExtras) ?? '';
        if (salidasExtrasJson.isNotEmpty) {
          final Map<String, dynamic> decodedData = jsonDecode(salidasExtrasJson);
          _salidasExtras = {
            for (var key in decodedData.keys)
              key: Map<String, dynamic>.from(decodedData[key])
          };
        }
      }

      debugPrint('Salidas extras cargadas correctamente');
    } catch (e) {
      debugPrint('Error al cargar salidas extras: $e');
    }
  }

  // Guardar horarios en SharedPreferences
  Future<void> guardarHorarios() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_keyHorariosAysen, jsonEncode(_horariosAysen));
      await prefs.setString(_keyHorariosCoyhaique, jsonEncode(_horariosCoyhaique));

      debugPrint('Horarios guardados correctamente');
    } catch (e) {
      debugPrint('Error al guardar horarios: $e');
    }
  }

  // Cargar horarios desde SharedPreferences
  Future<void> cargarHorarios() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (prefs.containsKey(_keyHorariosAysen)) {
        final String horariosAysenJson = prefs.getString(_keyHorariosAysen) ?? '';
        if (horariosAysenJson.isNotEmpty) {
          final Map<String, dynamic> decodedData = jsonDecode(horariosAysenJson);
          _horariosAysen = {
            for (var key in decodedData.keys)
              key: List<String>.from(decodedData[key])
          };
        }
      }

      if (prefs.containsKey(_keyHorariosCoyhaique)) {
        final String horariosCoyhaiquesJson = prefs.getString(_keyHorariosCoyhaique) ?? '';
        if (horariosCoyhaiquesJson.isNotEmpty) {
          final Map<String, dynamic> decodedData = jsonDecode(horariosCoyhaiquesJson);
          _horariosCoyhaique = {
            for (var key in decodedData.keys)
              key: List<String>.from(decodedData[key])
          };
        }
      }

      // Cargar y limpiar salidas extras
      await _cargarSalidasExtras();
      await limpiarSalidasExtrasPasadas();

      debugPrint('Horarios cargados correctamente');
    } catch (e) {
      debugPrint('Error al cargar horarios: $e');
    }
  }

  // Actualizar horarios de Aysén
  Future<void> actualizarHorariosAysen(String categoria, List<String> horarios) async {
    _horariosAysen[categoria] = horarios;
    await guardarHorarios();
  }

  // Actualizar horarios de Coyhaique
  Future<void> actualizarHorariosCoyhaique(String categoria, List<String> horarios) async {
    _horariosCoyhaique[categoria] = horarios;
    await guardarHorarios();
  }

  // Restaurar a valores por defecto
  Future<void> restaurarValoresPorDefecto() async {
    _horariosAysen = {
      'LunesViernes': [
        '06:55', '08:30', '09:45', '11:05', '12:10', '12:50', '14:05',
        '15:30', '16:40', '17:30', '18:00', '19:20'
      ],
      'Sabados': [
        '08:40', '09:50', '11:10', '12:30', '14:10', '15:40',
        '17:15', '18:25'
      ],
      'DomingosFeriados': [
        '08:40', '10:15', '12:30', '14:00']
    };

    _horariosCoyhaique = {
      'LunesViernes': [
        '06:50', '08:30', '09:45', '11:00', '12:00', '13:10', '14:10',
        '15:40', '17:00', '17:30', '18:10', '19:50'
      ],
      'Sabados': [
        '08:40', '10:00', '11:20', '12:50', '14:00', '15:40',
        '17:15', '18:30'
      ],
      'DomingosFeriados': [
        '10:25', '12:00', '13:45', '15:45']
    };

    await guardarHorarios();
  }
}