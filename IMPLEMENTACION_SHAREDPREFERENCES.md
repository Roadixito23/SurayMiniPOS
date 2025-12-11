# Implementación de Persistencia de Datos con SharedPreferences

## Resumen General

Se ha implementado un sistema completo de persistencia de datos utilizando `SharedPreferences` en la aplicación SurayMiniPOS. Esto permite que la aplicación recuerde la sesión del usuario y otras configuraciones importantes entre reinicios de la aplicación.

## Cambios Realizados

### 1. **Nuevo Servicio: PreferencesManager** (`lib/services/preferences_manager.dart`)

Gestor centralizado que encapsula todas las operaciones con SharedPreferences:

#### Características principales:

- **Singleton Pattern**: Una única instancia durante la ejecución
- **Inicialización centralizada**: `PreferencesManager.initialize()` llamada en `main()`
- **Métodos específicos para sesión de usuario**:
  - `saveUserSession()`: Guarda credenciales y datos del usuario
  - `isAuthenticated()`: Verifica si existe sesión activa
  - `getUsername()`, `getPassword()`, `getUserId()`, etc.: Recupera datos del usuario
  - `clearUserSession()`: Limpia toda la sesión al logout

- **Métodos genéricos**:
  - `setString()`, `getString()`
  - `setInt()`, `getInt()`
  - `setBool()`, `getBool()`
  - `setDouble()`, `getDouble()`
  - `remove()`, `clear()`

### 2. **AuthProvider Actualizado** (`lib/models/auth_provider.dart`)

Mejoras en el gestor de autenticación:

```dart
// Nuevo método para restaurar sesión
Future<bool> restoreSessionFromPreferences() async {
  // Restaura usuario, rol, ID secretario, sucursal, etc.
}

// Login actualizado para guardar sesión
Future<bool> login(String username, String password) async {
  // ... validación en BD ...
  await PreferencesManager().saveUserSession(...);
}

// Logout actualizado para limpiar sesión
Future<void> logout() async {
  // ... limpieza de datos ...
  await PreferencesManager().clearUserSession();
}

// setSucursalActual actualizado
void setSucursalActual(String sucursal) {
  await PreferencesManager().setSucursalActual(sucursal);
}
```

### 3. **LoginScreen Mejorado** (`lib/screens/login_screen.dart`)

Nuevas características:

- **Checkbox "Recordar usuario"**: El usuario puede optar por recordar sus credenciales
- **Carga automática de credenciales guardadas**: Al iniciar, si se marcó "recordar", los campos se rellenan
- **Persistencia de preferencias**: Al hacer login con "recordar" activo, se guardan las credenciales

```dart
// Nuevo checkbox en el formulario
CheckboxListTile(
  value: _rememberUser,
  onChanged: (value) {
    setState(() => _rememberUser = value ?? false);
  },
  title: const Text('Recordar usuario'),
)

// Carga de credenciales guardadas
Future<void> _loadSavedCredentials() async {
  final prefs = PreferencesManager();
  if (prefs.isRememberUser()) {
    _usernameController.text = prefs.getUsername() ?? '';
    _passwordController.text = prefs.getPassword() ?? '';
  }
}
```

### 4. **SplashScreen Mejorado** (`lib/screens/splash.dart`)

Flujo de navegación automático:

- **Restauración automática de sesión**: Intenta restaurar la sesión al iniciar la app
- **Redirección inteligente**:
  - Si existe sesión persistente → navega a `/home`
  - Si no existe sesión → navega a `/login`

```dart
Future<void> _navigationFlow() async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  
  // Intentar restaurar sesión
  final sesionRestaurada = await authProvider.restoreSessionFromPreferences();
  
  if (sesionRestaurada) {
    Navigator.pushReplacementNamed(context, '/home');
  } else {
    Navigator.pushReplacementNamed(context, '/login');
  }
}
```

### 5. **main.dart Actualizado**

Inicialización de SharedPreferences al arrancar:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar SharedPreferences PRIMERO
  await PreferencesManager.initialize();
  
  // ... resto de inicializaciones ...
}
```

## Claves de Persistencia

Las siguientes claves se utilizan en SharedPreferences:

| Clave | Tipo | Propósito |
|-------|------|----------|
| `username` | String | Nombre de usuario guardado |
| `password` | String | Contraseña guardada (si "recordar" está activo) |
| `user_id` | int | ID del usuario en la BD |
| `user_role` | String | Rol del usuario (Administrador, Secretaria) |
| `id_secretario` | String | ID de secretario del usuario |
| `sucursal_origen` | String | Sucursal asignada al usuario |
| `sucursal_actual` | String | Sucursal seleccionada en la sesión actual |
| `is_authenticated` | bool | Indica si existe sesión activa |
| `remember_user` | bool | Indica si se debe recordar el usuario |
| `last_login_time` | String | Timestamp del último login |
| `receipt_number` | int | Número del próximo comprobante |
| `config_origen` | String | Configuración de origen |

## Flujo de Sesión

### Al Iniciar la Aplicación:

```
1. main() → PreferencesManager.initialize()
2. SplashScreen se muestra
3. SplashScreen llama a _navigationFlow()
4. authProvider.restoreSessionFromPreferences()
   - Si existe sesión guardada → AuthProvider se carga con datos
   - Si no existe → AuthProvider permanece desautenticado
5. Navegación a /home (si sesión) o /login (si no sesión)
```

### Al Hacer Login:

```
1. Usuario ingresa credenciales
2. Se valida contra la BD
3. Si es válido:
   - AuthProvider se carga con datos del usuario
   - Se guarda la sesión en PreferencesManager
   - Se guarda la preferencia "recordar" si está marcada
4. Se selecciona sucursal
5. Se navega a /home
```

### Al Hacer Logout:

```
1. Usuario presiona "Cerrar Sesión"
2. authProvider.logout()
   - Limpia AuthProvider
   - Limpia PreferencesManager.clearUserSession()
3. Se navega a /login
4. La próxima vez que inicie, irá a /login (no hay sesión guardada)
```

## Beneficios

✅ **Experiencia de usuario mejorada**: No necesita ingresar credenciales cada vez  
✅ **Persistencia automática**: La sesión se mantiene entre reinicios  
✅ **Seguridad**: El usuario controla si se guardan las credenciales  
✅ **Facilidad de desarrollo**: Gestor centralizado `PreferencesManager`  
✅ **Escalabilidad**: Fácil agregar más datos persistentes  
✅ **Limpieza de datos**: Logout limpia completamente la sesión  

## Uso Futuro

Para guardar datos persistentes adicionales en otras partes de la aplicación:

```dart
// Guardar datos
await PreferencesManager().setString('mi_clave', 'valor');
await PreferencesManager().setInt('mi_numero', 42);

// Recuperar datos
final valor = PreferencesManager().getString('mi_clave');
final numero = PreferencesManager().getInt('mi_numero');

// Eliminar un dato
await PreferencesManager().remove('mi_clave');
```

## Consideraciones de Seguridad

⚠️ **IMPORTANTE**: Las contraseñas se guardan en `SharedPreferences` (almacenamiento local). Esto es suficiente para aplicaciones de escritorio local, pero:

- No se deben guardar tokens de acceso sensibles aquí
- Para aplicaciones con backend remoto, considerar usar tokens de actualización
- Los datos en SharedPreferences son accesibles a través del sistema de archivos

Para aplicaciones más seguras, considerar usar `flutter_secure_storage` para datos sensibles.

---

**Fecha de implementación**: 9 de diciembre de 2025  
**Responsable**: Asistente IA GitHub Copilot
