import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    SearchPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Inicio' : _currentIndex == 1 ? 'Horarios' : 'Datos Carga'),
        centerTitle: true,
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Horarios',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mail),
            label: 'Datos Carga',
          ),
        ],
      ),
    );
  }
}

// Páginas para cada sección del BottomNavigationBar
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home, size: 80.0, color: Colors.blue),
          SizedBox(height: 20.0),
          Text(
            'Página de Inicio',
            style: TextStyle(fontSize: 24.0),
          ),
          SizedBox(height: 30.0),
          ElevatedButton(
            onPressed: () {
              // Navegar a la pantalla de venta de bus
              Navigator.pushNamed(context, '/venta_bus');
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              minimumSize: Size(250, 50),
            ),
            child: Text('Generar Venta Bus', style: TextStyle(fontSize: 16)),
          ),
          SizedBox(height: 20.0),
          ElevatedButton(
            onPressed: () {
              // Navegar a la pantalla de venta de cargo
              Navigator.pushNamed(context, '/venta_cargo');
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              minimumSize: Size(250, 50),
              backgroundColor: Colors.orange,
            ),
            child: Text('Generar Venta Cargo', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  // Controlador para las pestañas
  late TabController _tabController;

  // Lista de horarios de salida de buses
  List<Map<String, String>> horarios = [];

  // Controladores para los campos de texto
  final TextEditingController horaController = TextEditingController();

  // Indicador de carga
  bool isLoading = true;
  bool mostrarFormulario = false;

  @override
  void initState() {
    super.initState();
    // Inicializar el controlador de pestañas con 2 pestañas (Aysen y Coyhaique)
    _tabController = TabController(length: 2, vsync: this);

    // Cargar horarios guardados cuando se inicializa el estado
    cargarHorarios();
  }

  @override
  void dispose() {
    _tabController.dispose();
    horaController.dispose();
    super.dispose();
  }

  // Método para obtener la ruta del archivo local
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Método para obtener el archivo local
  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/horarios.json');
  }

  // Método para guardar horarios en el archivo local
  Future<void> guardarHorarios() async {
    try {
      final file = await _localFile;
      String data = jsonEncode(horarios);
      await file.writeAsString(data);

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Horarios guardados correctamente'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar horarios: $e')),
      );
    }
  }

  // Método para cargar horarios desde el archivo local
  Future<void> cargarHorarios() async {
    setState(() {
      isLoading = true;
    });

    try {
      final file = await _localFile;

      // Verificar si el archivo existe
      if (await file.exists()) {
        String contents = await file.readAsString();
        List<dynamic> data = jsonDecode(contents);

        // Convertir los datos JSON a la lista de horarios
        List<Map<String, String>> horariosTemp = [];
        for (var item in data) {
          horariosTemp.add({
            'hora': item['hora'] ?? '',
            'destino': item['destino'] ?? '',
          });
        }

        setState(() {
          horarios = horariosTemp;
          isLoading = false;
        });
      } else {
        // Si el archivo no existe, inicializar con algunos valores predeterminados
        setState(() {
          horarios = [
            {'hora': '08:00', 'destino': 'Aysen'},
            {'hora': '10:30', 'destino': 'Coyhaique'},
            {'hora': '13:45', 'destino': 'Aysen'},
            {'hora': '15:30', 'destino': 'Coyhaique'},
            {'hora': '18:00', 'destino': 'Aysen'},
          ];
          isLoading = false;
        });

        // Guardar estos valores predeterminados
        await guardarHorarios();
      }
    } catch (e) {
      // En caso de error, inicializar con valores predeterminados
      setState(() {
        horarios = [
          {'hora': '08:00', 'destino': 'Aysen'},
          {'hora': '10:30', 'destino': 'Coyhaique'},
          {'hora': '13:45', 'destino': 'Aysen'},
          {'hora': '15:30', 'destino': 'Coyhaique'},
          {'hora': '18:00', 'destino': 'Aysen'},
        ];
        isLoading = false;
      });

      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar horarios: $e')),
      );
    }
  }

  // Filtrar horarios por destino
  List<Map<String, String>> obtenerHorariosPorDestino(String destino) {
    return horarios.where((horario) => horario['destino'] == destino).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TabBar para seleccionar entre Aysen y Coyhaique
        Material(
          elevation: 4.0,
          color: Colors.blue,
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                text: 'Desde Aysen',
                icon: Icon(Icons.directions_bus),
              ),
              Tab(
                text: 'Desde Coyhaique',
                icon: Icon(Icons.directions_bus),
              ),
            ],
          ),
        ),

        // Contenido principal
        Expanded(
          child: isLoading
              ? Center(child: CircularProgressIndicator())
              : TabBarView(
            controller: _tabController,
            children: [
              // Pestaña de Aysen
              _construirTabContenido('Aysen'),

              // Pestaña de Coyhaique
              _construirTabContenido('Coyhaique'),
            ],
          ),
        ),
      ],
    );
  }

  // Construir el contenido de cada pestaña
  Widget _construirTabContenido(String destino) {
    List<Map<String, String>> horariosFiltrados = obtenerHorariosPorDestino(destino);

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de herramientas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.blue),
                    tooltip: 'Recargar horarios',
                    onPressed: () {
                      cargarHorarios();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.save, color: Colors.blue),
                    tooltip: 'Guardar horarios',
                    onPressed: () {
                      guardarHorarios();
                    },
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: Icon(mostrarFormulario ? Icons.close : Icons.add),
                label: Text(mostrarFormulario ? 'Cerrar' : 'Nuevo horario'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mostrarFormulario ? Colors.red : Colors.green,
                  minimumSize: Size(50, 36),
                ),
                onPressed: () {
                  setState(() {
                    mostrarFormulario = !mostrarFormulario;
                    if (!mostrarFormulario) {
                      horaController.clear();
                    }
                  });
                },
              ),
            ],
          ),

          // Formulario compacto para agregar un nuevo horario (visible/oculto)
          if (mostrarFormulario)
            Card(
              elevation: 3.0,
              margin: EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: horaController,
                        decoration: InputDecoration(
                          labelText: 'Hora (HH:MM)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        keyboardType: TextInputType.datetime,
                      ),
                    ),
                    SizedBox(width: 10.0),
                    ElevatedButton(
                      onPressed: () {
                        // Agregar nuevo horario
                        if (horaController.text.isNotEmpty) {
                          setState(() {
                            horarios.add({
                              'hora': horaController.text,
                              'destino': destino,
                            });
                            // Limpiar campo
                            horaController.clear();
                            // Ocultar formulario después de agregar
                            mostrarFormulario = false;
                          });

                          // Guardar los cambios en el archivo local
                          guardarHorarios();
                        } else {
                          // Mostrar mensaje de error si faltan datos
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Por favor ingrese la hora')),
                          );
                        }
                      },
                      child: Text('Agregar'),
                    ),
                  ],
                ),
              ),
            ),

          // Título y conteo de horarios
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Horarios disponibles (${horariosFiltrados.length})',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                if (horariosFiltrados.isNotEmpty)
                  Text(
                    'Última salida: ${horariosFiltrados.map((h) => h['hora']).reduce((a, b) => a!.compareTo(b!) > 0 ? a : b)}',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.blue.shade700,
                    ),
                  ),
              ],
            ),
          ),

          // Lista de horarios
          Expanded(
            child: horariosFiltrados.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule_outlined, size: 50, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'No hay horarios registrados para $destino',
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('Agregar primero'),
                    onPressed: () {
                      setState(() {
                        mostrarFormulario = true;
                      });
                    },
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: horariosFiltrados.length,
              itemBuilder: (context, index) {
                return Card(
                  elevation: 2.0,
                  margin: EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      'Salida: ${horariosFiltrados[index]['hora']!}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Destino: $destino'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botón para editar horario
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'Editar horario',
                          onPressed: () {
                            // Encontrar el índice real en la lista general
                            int indiceReal = horarios.indexWhere((h) =>
                            h['hora'] == horariosFiltrados[index]['hora'] &&
                                h['destino'] == horariosFiltrados[index]['destino']);

                            if (indiceReal != -1) {
                              _mostrarDialogoEdicion(context, indiceReal);
                            }
                          },
                        ),
                        // Botón para eliminar horario
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Eliminar horario',
                          onPressed: () {
                            // Mostrar diálogo de confirmación
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text("Confirmar eliminación"),
                                  content: Text("¿Está seguro que desea eliminar este horario?"),
                                  actions: [
                                    TextButton(
                                      child: Text("Cancelar"),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                    TextButton(
                                      child: Text("Eliminar"),
                                      onPressed: () {
                                        // Encontrar el índice real en la lista general
                                        int indiceReal = horarios.indexWhere((h) =>
                                        h['hora'] == horariosFiltrados[index]['hora'] &&
                                            h['destino'] == horariosFiltrados[index]['destino']);

                                        if (indiceReal != -1) {
                                          setState(() {
                                            horarios.removeAt(indiceReal);
                                          });
                                          // Guardar los cambios
                                          guardarHorarios();
                                        }
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Método para mostrar diálogo de edición de horario
  void _mostrarDialogoEdicion(BuildContext context, int index) {
    // Controladores para el diálogo
    TextEditingController editHoraController = TextEditingController(
        text: horarios[index]['hora']
    );
    // Destino actual
    String destinoActual = horarios[index]['destino']!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Editar Horario"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Destino: $destinoActual',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              SizedBox(height: 15),
              TextField(
                controller: editHoraController,
                decoration: InputDecoration(
                  labelText: 'Hora (HH:MM)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time),
                ),
                keyboardType: TextInputType.datetime,
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: Icon(Icons.cancel, color: Colors.red),
              label: Text("Cancelar"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton.icon(
              icon: Icon(Icons.save, color: Colors.green),
              label: Text("Guardar"),
              onPressed: () {
                if (editHoraController.text.isNotEmpty) {
                  setState(() {
                    horarios[index] = {
                      'hora': editHoraController.text,
                      'destino': destinoActual, // Mantener el destino actual
                    };
                  });
                  // Guardar los cambios
                  guardarHorarios();
                  Navigator.of(context).pop();
                } else {
                  // Mostrar mensaje de error si faltan datos
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Por favor ingrese la hora')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.mail,
                  size: 80.0,
                  color: Colors.blue,
                ),
                SizedBox(height: 15.0),
                Text(
                  'Datos Carga',
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 30.0),
          Card(
            elevation: 4.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Información de Envío',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 20.0),
                  buildInfoRow('Remitente:', 'Completar información'),
                  buildInfoRow('Destinatario:', 'Completar información'),
                  buildInfoRow('Origen:', 'Seleccionar ciudad'),
                  buildInfoRow('Destino:', 'Seleccionar ciudad'),
                  buildInfoRow('Tipo de Carga:', 'Seleccionar tipo'),
                  buildInfoRow('Peso (kg):', 'Ingresar peso'),
                ],
              ),
            ),
          ),
          SizedBox(height: 20.0),
          Card(
            elevation: 4.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historial de Envíos',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10.0),
                  Text('No hay envíos recientes'),
                ],
              ),
            ),
          ),
          Spacer(),
          Center(
            child: ElevatedButton(
              onPressed: () {
                // Acción para registrar nuevo envío
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Registrando nuevo envío...')),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                minimumSize: Size(250, 50),
              ),
              child: Text('Registrar Nuevo Envío', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // Función auxiliar para construir filas de información
  Widget buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}