import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const Color kOrange = Color(0xFFFF6B00);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkLyfe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kOrange),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOrange,
      bottomNavigationBar: const _BottomBar(),
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            const SizedBox(height: 32),
            const Text(
              'Bienvenido!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Genera tu reserva',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),
            _ReserveCard(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SelectParkingScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, color: kOrange, size: 32),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alba Castro',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Alba@uts.edu.co',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {},
            customBorder: const CircleBorder(),
            child: const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: Icon(Icons.settings, color: kOrange, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReserveCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ReserveCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: const BoxDecoration(
                color: kOrange,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 100,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reservar',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int selected;
  const _BottomBar({this.selected = 0});

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.home,
      Icons.person_outline,
      Icons.location_on,
      Icons.notifications,
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.elliptical(200, 50)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i = 0; i < icons.length; i++)
                Icon(
                  icons[i],
                  size: 36,
                  color: i == selected ? Colors.black : kOrange,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Pantalla temporal para probar la navegación.
class SelectParkingScreen extends StatefulWidget {
  const SelectParkingScreen({super.key});

  @override
  State<SelectParkingScreen> createState() => _SelectParkingScreenState();
}

class _SelectParkingScreenState extends State<SelectParkingScreen> {
  // Datos de ejemplo; luego vendrán de una base de datos o API.
  final List<String> _names = [
    'Parqueadero 1',
    'Parqueadero 2',
    'Parqueadero 3',
  ];
  final List<int> _available = [20, 45, 8];
  final List<LatLng> _points = [
    LatLng(7.1193, -73.1227),
    LatLng(7.1254, -73.1198),
    LatLng(7.1301, -73.1150),
  ];
  static const int _total = 100;
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOrange,
      bottomNavigationBar: const _BottomBar(selected: 2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                customBorder: const CircleBorder(),
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.chevron_left, color: kOrange, size: 24),
                ),
              ),
              const SizedBox(height: 24),
              for (int i = 0; i < _names.length; i++) ...[
                _ParkingPill(
                  label: _names[i],
                  selected: i == _selected,
                  onTap: () => setState(() => _selected = i),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              _MapPreview(points: _points, selected: _selected),
              const SizedBox(height: 32),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Cupos disponibles\n${_available[_selected]}/$_total',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParkingPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ParkingPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.black : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 9,
              backgroundColor: Colors.black,
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  final List<LatLng> points;
  final int selected;

  const _MapPreview({required this.points, required this.selected});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: FlutterMap(
          key: ValueKey(selected),
          options: MapOptions(initialCenter: points[selected], initialZoom: 16),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.proyecto_app',
            ),
            MarkerLayer(
              markers: [
                for (int i = 0; i < points.length; i++)
                  Marker(
                    point: points[i],
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.location_on,
                      size: 44,
                      color: i == selected ? Colors.red : Colors.black54,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
