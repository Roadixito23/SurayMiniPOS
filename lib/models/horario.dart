import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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