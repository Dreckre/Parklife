import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:qr_flutter/qr_flutter.dart';

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
                    builder: (context) => const VehiclesScreen(),
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
    LatLng(7.103941, -73.122502),
    LatLng(7.105799, -73.123264),
    LatLng(7.107119, -73.122615),
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
              Center(
                child: ElevatedButton(
                  onPressed: _available[_selected] > 0
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  QrScreen(parkingName: _names[_selected]),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7DF05A),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                    shape: const StadiumBorder(
                      side: BorderSide(color: Colors.black),
                    ),
                  ),
                  child: const Text(
                    'Seleccionar parqueadero',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

class Vehicle {
  final String plate;
  final String brand;
  final String model;
  final String color;

  const Vehicle({
    required this.plate,
    required this.brand,
    required this.model,
    required this.color,
  });
}

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  // Datos de ejemplo; luego vendrán de una base de datos o API.
  static const List<Vehicle> _vehicles = [
    Vehicle(plate: 'XDE 32H', brand: 'APACHE', model: '2026', color: 'NEGRO'),
    Vehicle(plate: 'ABC 12D', brand: 'PULSAR', model: '2024', color: 'ROJO'),
  ];
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final v = _vehicles[_selected];

    return Scaffold(
      backgroundColor: kOrange,
      bottomNavigationBar: const _BottomBar(selected: 1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              // Encabezado: flecha de volver + título centrado
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back, color: Colors.black),
                    ),
                  ),
                  const Text(
                    'Tus vehículos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Selector de vehículo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selected,
                    isExpanded: true,
                    icon: const CircleAvatar(
                      radius: 11,
                      backgroundColor: Colors.black,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    selectedItemBuilder: (context) => [
                      for (int i = 0; i < _vehicles.length; i++)
                        Center(child: Text('Vehículo ${i + 1}')),
                    ],
                    items: [
                      for (int i = 0; i < _vehicles.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text('Vehículo ${i + 1}'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _selected = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tarjeta con la información
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Información del vehículo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _InfoLine(label: 'PLACA', value: v.plate),
                    _InfoLine(label: 'MARCA', value: v.brand),
                    _InfoLine(label: 'MODELO', value: v.model),
                    _InfoLine(label: 'COLOR', value: v.color),
                    const SizedBox(height: 48),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SelectParkingScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7DF05A),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.black),
                            ),
                            child: const Text(
                              'RESERVAR',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black),
                            ),
                            child: const Icon(Icons.close, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ],
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

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class QrScreen extends StatefulWidget {
  final String parkingName;
  const QrScreen({super.key, required this.parkingName});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  static const Duration _validity = Duration(seconds: 15);

  Timer? _timer;
  late String _code;
  late DateTime _expiresAt;
  Duration _remaining = _validity;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Crea un código nuevo y reinicia la cuenta regresiva.
  void _generate() {
    _timer?.cancel();
    final rnd = Random.secure();
    _code = List.generate(
      8,
      (_) => rnd.nextInt(16).toRadixString(16),
    ).join().toUpperCase();
    _expiresAt = DateTime.now().add(_validity);
    _remaining = _validity;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _expiresAt.difference(DateTime.now());
      if (left <= Duration.zero) {
        _timer?.cancel();
        setState(() => _remaining = Duration.zero);
      } else {
        setState(() => _remaining = left);
      }
    });
  }

  bool get _expired => _remaining <= Duration.zero;

  String get _timeText {
    final total = (_remaining.inMilliseconds / 1000).ceil();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get _qrData => jsonEncode({
    'reserva': _code,
    'parqueadero': widget.parkingName,
    'vence': _expiresAt.toIso8601String(),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOrange,
      bottomNavigationBar: const _BottomBar(selected: 3),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: Colors.black),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Este es tu código\npara tu parklife',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 26),
              ),
              const SizedBox(height: 8),
              Text(
                widget.parkingName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _expired ? _expiredBox() : _qrBox(),
              const SizedBox(height: 24),
              Text(
                _expired ? 'Código vencido' : 'Tiempo de espera\n$_timeText',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 26),
              ),
              if (_expired) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(_generate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Generar nuevo código'),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qrBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: QrImageView(
        data: _qrData,
        version: QrVersions.auto,
        size: 200,
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _expiredBox() {
    return Container(
      width: 224,
      height: 224,
      color: Colors.white,
      child: const Icon(Icons.timer_off, size: 90, color: Colors.black38),
    );
  }
}
