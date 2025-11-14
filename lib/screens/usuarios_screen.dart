import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../models/auth_provider.dart';

class UsuariosScreen extends StatefulWidget {
  @override
  _UsuariosScreenState createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  List<Map<String, dynamic>> _usuarios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _isLoading = true);
    try {
      final usuarios = await AppDatabase.instance.getAllUsuarios();
      setState(() {
        _usuarios = usuarios;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar usuarios: $e');
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
    );
  }

  Future<void> _agregarUsuario() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAdmin) {
      _mostrarError('Solo los administradores pueden agregar usuarios');
      return;
    }

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _FormularioUsuarioDialog(),
    );

    if (resultado != null) {
      try {
        // Validar ID de secretario único por sucursal
        final idDisponible = await AppDatabase.instance.idSecretarioDisponible(
          resultado['id_secretario'],
          resultado['sucursal_origen'],
        );

        if (!idDisponible) {
          _mostrarError('El ID de secretario ${resultado['id_secretario']} ya está en uso en la sucursal ${resultado['sucursal_origen']}');
          return;
        }

        await AppDatabase.instance.insertUsuario({
          'username': resultado['username'],
          'password': resultado['password'],
          'rol': resultado['rol'],
          'activo': 1,
          'fecha_creacion': DateTime.now().toIso8601String(),
          'id_secretario': resultado['id_secretario'],
          'sucursal_origen': resultado['sucursal_origen'],
        });
        _mostrarExito('Usuario creado exitosamente');
        _cargarUsuarios();
      } catch (e) {
        _mostrarError('Error al crear usuario: $e');
      }
    }
  }

  Future<void> _editarUsuario(Map<String, dynamic> usuario) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAdmin) {
      _mostrarError('Solo los administradores pueden editar usuarios');
      return;
    }

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _FormularioUsuarioDialog(usuario: usuario),
    );

    if (resultado != null) {
      try {
        // Validar ID de secretario único por sucursal
        final idDisponible = await AppDatabase.instance.idSecretarioDisponible(
          resultado['id_secretario'],
          resultado['sucursal_origen'],
          excluyendoUsuarioId: usuario['id'],
        );

        if (!idDisponible) {
          _mostrarError('El ID de secretario ${resultado['id_secretario']} ya está en uso en la sucursal ${resultado['sucursal_origen']}');
          return;
        }

        await AppDatabase.instance.updateUsuario(
          usuario['id'],
          {
            'username': resultado['username'],
            'password': resultado['password'],
            'rol': resultado['rol'],
            'id_secretario': resultado['id_secretario'],
            'sucursal_origen': resultado['sucursal_origen'],
          },
        );
        _mostrarExito('Usuario actualizado exitosamente');
        _cargarUsuarios();
      } catch (e) {
        _mostrarError('Error al actualizar usuario: $e');
      }
    }
  }

  Future<void> _cambiarEstadoUsuario(Map<String, dynamic> usuario) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAdmin) {
      _mostrarError('Solo los administradores pueden cambiar el estado de usuarios');
      return;
    }

    final nuevoEstado = usuario['activo'] == 1 ? 0 : 1;
    final accion = nuevoEstado == 1 ? 'activar' : 'desactivar';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar acción'),
        content: Text('¿Desea $accion al usuario ${usuario['username']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirmar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: nuevoEstado == 1 ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await AppDatabase.instance.updateUsuario(
          usuario['id'],
          {'activo': nuevoEstado},
        );
        _mostrarExito('Usuario ${nuevoEstado == 1 ? "activado" : "desactivado"} exitosamente');
        _cargarUsuarios();
      } catch (e) {
        _mostrarError('Error al cambiar estado del usuario: $e');
      }
    }
  }

  Future<void> _eliminarUsuario(Map<String, dynamic> usuario) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAdmin) {
      _mostrarError('Solo los administradores pueden eliminar usuarios');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Eliminar Usuario'),
          ],
        ),
        content: Text(
          '¿Está seguro que desea eliminar permanentemente al usuario ${usuario['username']}?\n\nEsta acción no se puede deshacer.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await AppDatabase.instance.eliminarUsuarioPermanente(usuario['id']);
        _mostrarExito('Usuario eliminado exitosamente');
        _cargarUsuarios();
      } catch (e) {
        _mostrarError('Error al eliminar usuario: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Gestión de Usuarios'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Acceso Denegado',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Solo los administradores pueden acceder a esta sección',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de Usuarios'),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Usuario: ${authProvider.username} (${authProvider.rol})',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Estadísticas
                Container(
                  color: Colors.blue.shade50,
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.people,
                          label: 'Total Usuarios',
                          value: '${_usuarios.length}',
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_circle,
                          label: 'Activos',
                          value: '${_usuarios.where((u) => u['activo'] == 1).length}',
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.admin_panel_settings,
                          label: 'Administradores',
                          value: '${_usuarios.where((u) => u['rol'] == 'Administrador' && u['activo'] == 1).length}',
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de usuarios
                Expanded(
                  child: _usuarios.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No hay usuarios registrados',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _usuarios.length,
                          itemBuilder: (context, index) {
                            final usuario = _usuarios[index];
                            return _UserCard(
                              usuario: usuario,
                              onEdit: () => _editarUsuario(usuario),
                              onToggleStatus: () => _cambiarEstadoUsuario(usuario),
                              onDelete: () => _eliminarUsuario(usuario),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarUsuario,
        icon: Icon(Icons.person_add),
        label: Text('Agregar Usuario'),
        backgroundColor: Colors.blue.shade600,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  const _UserCard({
    required this.usuario,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = usuario['activo'] == 1;
    final isAdmin = usuario['rol'] == 'Administrador';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: isActive
              ? (isAdmin ? Colors.orange.shade100 : Colors.blue.shade100)
              : Colors.grey.shade200,
          child: Icon(
            isAdmin ? Icons.admin_panel_settings : Icons.person,
            color: isActive
                ? (isAdmin ? Colors.orange.shade700 : Colors.blue.shade700)
                : Colors.grey.shade500,
          ),
        ),
        title: Text(
          usuario['username'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            decoration: isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.badge, size: 14, color: Colors.grey.shade600),
                SizedBox(width: 4),
                Text(
                  usuario['rol'],
                  style: TextStyle(
                    color: isAdmin ? Colors.orange.shade700 : Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 16),
                Icon(
                  isActive ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: isActive ? Colors.green : Colors.red,
                ),
                SizedBox(width: 4),
                Text(
                  isActive ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.numbers, size: 14, color: Colors.grey.shade600),
                SizedBox(width: 4),
                Text(
                  'ID: ${usuario['id_secretario'] ?? 'N/A'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                SizedBox(width: 16),
                Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                SizedBox(width: 4),
                Text(
                  usuario['sucursal_origen'] ?? 'N/A',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue.shade600),
              onPressed: onEdit,
              tooltip: 'Editar usuario',
            ),
            IconButton(
              icon: Icon(
                isActive ? Icons.block : Icons.check_circle,
                color: isActive ? Colors.red.shade600 : Colors.green.shade600,
              ),
              onPressed: onToggleStatus,
              tooltip: isActive ? 'Desactivar' : 'Activar',
            ),
            IconButton(
              icon: Icon(Icons.delete_forever, color: Colors.red.shade700),
              onPressed: onDelete,
              tooltip: 'Eliminar usuario',
            ),
          ],
        ),
      ),
    );
  }
}

class _FormularioUsuarioDialog extends StatefulWidget {
  final Map<String, dynamic>? usuario;

  const _FormularioUsuarioDialog({this.usuario});

  @override
  _FormularioUsuarioDialogState createState() => _FormularioUsuarioDialogState();
}

class _FormularioUsuarioDialogState extends State<_FormularioUsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _idSecretarioController;
  String _rolSeleccionado = 'Secretaria';
  String _sucursalSeleccionada = 'AYS';
  bool _mostrarPassword = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.usuario?['username'] ?? '',
    );
    _passwordController = TextEditingController(
      text: widget.usuario?['password'] ?? '',
    );
    _idSecretarioController = TextEditingController(
      text: widget.usuario?['id_secretario'] ?? '01',
    );
    _rolSeleccionado = widget.usuario?['rol'] ?? 'Secretaria';
    _sucursalSeleccionada = widget.usuario?['sucursal_origen'] ?? 'AYS';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _idSecretarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.usuario != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit : Icons.person_add,
            color: Colors.blue,
          ),
          SizedBox(width: 12),
          Text(isEditing ? 'Editar Usuario' : 'Nuevo Usuario'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Campo de nombre de usuario
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Nombre de Usuario',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingrese un nombre de usuario';
                  }
                  if (value.length < 3) {
                    return 'Mínimo 3 caracteres';
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // Campo de contraseña
              TextFormField(
                controller: _passwordController,
                obscureText: !_mostrarPassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _mostrarPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _mostrarPassword = !_mostrarPassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese una contraseña';
                  }
                  if (value.length < 4) {
                    return 'Mínimo 4 caracteres';
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // Campo de ID de Secretario
              TextFormField(
                controller: _idSecretarioController,
                decoration: InputDecoration(
                  labelText: 'ID de Secretario (01-99)',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: 'Número único por sucursal',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingrese un ID de secretario';
                  }
                  final id = int.tryParse(value);
                  if (id == null || id < 1 || id > 99) {
                    return 'Ingrese un número entre 01 y 99';
                  }
                  return null;
                },
                onChanged: (value) {
                  // Formatear automáticamente a dos dígitos
                  final id = int.tryParse(value);
                  if (id != null && id >= 1 && id <= 99) {
                    final formatted = id.toString().padLeft(2, '0');
                    if (value != formatted) {
                      _idSecretarioController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  }
                },
              ),

              SizedBox(height: 16),

              // Selector de Sucursal de Origen
              DropdownButtonFormField<String>(
                value: _sucursalSeleccionada,
                decoration: InputDecoration(
                  labelText: 'Sucursal de Origen',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'AYS',
                    child: Row(
                      children: [
                        Icon(Icons.location_city, color: Colors.purple, size: 20),
                        SizedBox(width: 8),
                        Text('Aysén (AYS)'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'COY',
                    child: Row(
                      children: [
                        Icon(Icons.location_city, color: Colors.teal, size: 20),
                        SizedBox(width: 8),
                        Text('Coyhaique (COY)'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _sucursalSeleccionada = value!);
                },
              ),

              SizedBox(height: 16),

              // Selector de rol
              DropdownButtonFormField<String>(
                value: _rolSeleccionado,
                decoration: InputDecoration(
                  labelText: 'Rol del Usuario',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Administrador',
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text('Administrador'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Secretaria',
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('Secretaria'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _rolSeleccionado = value!);
                },
              ),

              SizedBox(height: 16),

              // Información sobre permisos
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _rolSeleccionado == 'Administrador'
                      ? Colors.orange.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _rolSeleccionado == 'Administrador'
                        ? Colors.orange.shade200
                        : Colors.blue.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: _rolSeleccionado == 'Administrador'
                              ? Colors.orange.shade700
                              : Colors.blue.shade700,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Permisos del rol:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _rolSeleccionado == 'Administrador'
                                ? Colors.orange.shade700
                                : Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    if (_rolSeleccionado == 'Administrador') ...[
                      _PermisoItem('Acceso completo al sistema'),
                      _PermisoItem('Puede usar teclado de valor personalizado'),
                      _PermisoItem('Gestión de usuarios'),
                      _PermisoItem('Configuración del sistema'),
                    ] else ...[
                      _PermisoItem('Venta de boletos y carga'),
                      _PermisoItem('Solo categorías de tarifa predefinidas'),
                      _PermisoItem('Sin acceso a valores personalizados'),
                      _PermisoItem('Consultas de historial'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              // Formatear ID de secretario a dos dígitos
              final id = int.tryParse(_idSecretarioController.text);
              final idFormatted = id?.toString().padLeft(2, '0') ?? '01';

              Navigator.pop(context, {
                'username': _usernameController.text.trim(),
                'password': _passwordController.text,
                'rol': _rolSeleccionado,
                'id_secretario': idFormatted,
                'sucursal_origen': _sucursalSeleccionada,
              });
            }
          },
          icon: Icon(Icons.check),
          label: Text(isEditing ? 'Actualizar' : 'Crear'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
          ),
        ),
      ],
    );
  }
}

class _PermisoItem extends StatelessWidget {
  final String texto;

  const _PermisoItem(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.check, size: 14, color: Colors.green),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
