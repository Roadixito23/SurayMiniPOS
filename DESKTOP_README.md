# Suray POS OFICINA - Aplicación de Escritorio

## 🖥️ Plataformas Soportadas

Esta aplicación está optimizada para ejecutarse en:
- **Linux** (Ubuntu, Debian, Arch, etc.)
- **Windows** (Windows 10/11)
- **macOS** (Big Sur y superiores)

## 🚀 Ejecución de la Aplicación

### Linux
```bash
flutter run -d linux
```

### Windows
```bash
flutter run -d windows
```

### macOS
```bash
flutter run -d macos
```

## 📦 Compilación para Distribución

### Linux
```bash
flutter build linux --release
```
El ejecutable estará en: `build/linux/x64/release/bundle/`

### Windows
```bash
flutter build windows --release
```
El ejecutable estará en: `build/windows/x64/runner/Release/`

### macOS
```bash
flutter build macos --release
```
La aplicación estará en: `build/macos/Build/Products/Release/`

## 🔧 Configuración de Ventana

La aplicación está configurada con:
- **Tamaño inicial**: 1280x800 píxeles
- **Tamaño mínimo**: 1024x600 píxeles
- **Inicio centrado** en la pantalla
- **Título**: Suray POS OFICINA

## 🗄️ Base de Datos

La aplicación utiliza SQLite mediante `sqflite_common_ffi` para almacenamiento local en escritorio.

**Ubicación de datos:**
- **Linux**: `~/.local/share/suray_pos_office/`
- **Windows**: `%APPDATA%\suray_pos_office\`
- **macOS**: `~/Library/Application Support/suray_pos_office/`

## 📋 Requisitos del Sistema

### Linux
- Ubuntu 18.04 o superior / Distribución equivalente
- GTK3 instalado
- Clang/LLVM

Para instalar dependencias en Ubuntu/Debian:
```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

### Windows
- Windows 10 versión 1809 o superior
- Visual Studio 2019 o 2022 con cargas de trabajo de desarrollo de escritorio de C++

### macOS
- macOS 10.14 (Mojave) o superior
- Xcode 13 o superior

## 🔑 Características de Escritorio

1. **Gestión de Ventanas**: Usando `window_manager` para control completo de la ventana
2. **Base de Datos Local**: SQLite para almacenamiento persistente
3. **Selección de Archivos**: Integración nativa con el sistema de archivos
4. **Impresión**: Soporte completo para impresión de tickets y reportes
5. **Sincronización Cloud**: Opcional, con modo offline completo

## 🐛 Solución de Problemas

### La aplicación aparece en blanco

**Causa común**: Ejecutando en web en lugar de escritorio

**Solución**:
```bash
# NO usar:
flutter run -d web

# USAR:
flutter run -d linux    # Para Linux
flutter run -d windows  # Para Windows
flutter run -d macos    # Para macOS
```

### Error de compilación en Linux

**Solución**:
```bash
flutter clean
flutter pub get
flutter run -d linux
```

### Advertencias de GTK/Atk en Linux

Estos warnings son normales y no afectan la funcionalidad:
```
(app): Atk-CRITICAL **: atk_socket_embed: assertion 'plug_id != NULL' failed
Gdk-Message: Unable to load from the cursor theme
```

## 📱 Diferencias con la Versión Móvil

Esta es una aplicación de **escritorio nativa**, no es una aplicación web. Características específicas:

- ✅ Ventanas redimensionables
- ✅ Atajos de teclado completos
- ✅ Integración con el sistema operativo
- ✅ Gestión de archivos nativa
- ✅ Impresión directa sin navegador
- ✅ Mejor rendimiento que web
- ✅ Funciona completamente offline

## 🔄 Actualizaciones

Para actualizar la aplicación:
```bash
git pull
flutter pub get
flutter run -d <plataforma>
```

## 📞 Soporte

Para problemas técnicos o consultas, consulte la documentación principal en el `README.md`.
