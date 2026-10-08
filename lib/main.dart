import 'package:flutter/material.dart'; // Importa la biblioteca Flutter.

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navigation Basics',
      debugShowCheckedModeBanner: false,
      home: FirstRoute(),
    );
  }
}

class FirstRoute extends StatelessWidget {
  // Define una clase llamada FirstRoute que extiende StatelessWidget.
  @override
  Widget build(BuildContext context) {
    // Método build que construye la interfaz de usuario.
    return Scaffold(
      // Utiliza el widget Scaffold para establecer la estructura de la página.
      appBar: AppBar(
        // Agrega una barra de aplicaciones en la parte superior.
        title: Text(
          'Primera pantalla',
        ), // Establece el título de la barra de aplicaciones.
      ),
      body: Column(
        children: [
          Center(
            // Centra el contenido en la pantalla.
            child: ElevatedButton(
              // Agrega un botón elevado.
              child: Text('Segunda pantalla'), // Establece el texto del botón.
              onPressed: () {
                // Define una función que se ejecuta cuando se presiona el botón.
                Navigator.push(
                  // Utiliza el Navigator para navegar a otra pantalla.
                  context,
                  MaterialPageRoute(
                    builder: (context) => SecondRoute(),
                  ), // Construye la ruta a SecondRoute.
                );
              },
            ),
          ),
          Center(child: SizedBox(height: 20)),
          Center(
            child: ElevatedButton(
              child: Text('Tercera pantalla'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ThirdRoute()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SecondRoute extends StatelessWidget {
  // Define una clase llamada SecondRoute que extiende StatelessWidget.
  @override
  Widget build(BuildContext context) {
    // Método build que construye la interfaz de usuario.
    return Scaffold(
      // Utiliza el widget Scaffold para establecer la estructura de la página.
      appBar: AppBar(
        // Agrega una barra de aplicaciones en la parte superior.
        title: Text(
          'Segunda pantalla',
        ), // Establece el título de la barra de aplicaciones.
      ),
      body: Column(
        children: [
          Center(
            // Centra el contenido en la pantalla.
            child: ElevatedButton(
              // Agrega un botón elevado.
              child: Text('Primera pantalla'), // Establece el texto del botón.
              onPressed: () {
                // Define una función que se ejecuta cuando se presiona el botón.
                Navigator.pop(context);
              },
            ),
          ),
          Center(child: SizedBox(height: 20)),
          Center(
            child: ElevatedButton(
              child: Text('Tercera pantalla'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ThirdRoute()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ThirdRoute extends StatelessWidget {
  // Define una clase llamada ThirdRoute que extiende StatelessWidget.
  @override
  Widget build(BuildContext context) {
    // Método build que construye la interfaz de usuario.
    return Scaffold(
      // Utiliza el widget Scaffold para establecer la estructura de la página.
      appBar: AppBar(
        // Agrega una barra de aplicaciones en la parte superior.
        title: Text(
          'Tercera pantalla',
        ), // Establece el título de la barra de aplicaciones.
      ),
      body: Column(
        children: [
          Center(
            // Centra el contenido en la pantalla.
            child: ElevatedButton(
              // Agrega un botón elevado.
              child: Text('Primera pantalla'), // Establece el texto del botón.
              onPressed: () {
                // Define una función que se ejecuta cuando se presiona el botón.
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FirstRoute()),
                );
              },
            ),
          ),
          Center(child: SizedBox(height: 20)),
          Center(
            child: ElevatedButton(
              child: Text('Segunda pantalla'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SecondRoute()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
