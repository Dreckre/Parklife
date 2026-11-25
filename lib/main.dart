import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'porter_screen.dart';

// Archivo generado por: flutterfire configure
import 'firebase_options.dart';
import 'admin_parkings.dart' show AdminParkingsScreen, AdminService;

const Color kOrange = Color(0xFFFF6B00);
const Color kGreen = Color(0xFF7DF05A);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
      home: const AuthGate(),
    );
  }
}

// ============================================================
// AUTENTICACIÓN
// ============================================================

/// Decide qué pantalla mostrar según haya o no una sesión iniciada.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: kOrange,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        if (snapshot.hasData) return const HomeScreen();
        return const AuthScreen();
      },
    );
  }
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<void> register(
    String name,
    String email,
    String password,
  ) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(name);

    // Perfil del usuario en Firestore (si falla, la cuenta igual queda creada).
    try {
      await _db.collection('users').doc(user.uid).set({
        'nombre': name,
        'email': email,
        'creado': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('No se pudo guardar el perfil: $e');
    }
    await user.reload();
  }

  static Future<void> resetPassword(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  static Future<void> signOut() => _auth.signOut();

  static String errorText(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El correo no tiene un formato válido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 6 caracteres).';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento e intenta de nuevo.';
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      case 'operation-not-allowed':
        return 'El inicio de sesión con correo no está habilitado en Firebase.';
      default:
        return 'Error de autenticación (${e.code}).';
    }
  }
}




class VehicleService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // Colección: vehiculos/{id} -> { uid, placa, marca, modelo, color }
  static CollectionReference<Map<String, dynamic>> get _vehiculos =>
      _db.collection('vehiculos');

  // Escucha los vehículos del usuario en tiempo real
  static Stream<List<Vehicle>> watchMyVehicles() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _vehiculos
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
      final data = d.data();
      return Vehicle(
        id: d.id,
        plate: data['placa'] ?? '',
        brand: data['marca'] ?? '',
        model: data['modelo'] ?? '',
        color: data['color'] ?? '',
      );
    }).toList());
  }

  // Guarda un vehículo nuevo
  static Future<void> addVehicle({
    required String plate,
    required String brand,
    required String model,
    required String color,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('No hay usuario logueado');

    await _vehiculos.add({
      'uid': uid,
      'placa': plate.toUpperCase(),
      'marca': brand.toUpperCase(),
      'modelo': model,
      'color': color.toUpperCase(),
      'creado': FieldValue.serverTimestamp(),
    });
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const Color _fieldColor = Color(0xFFDCDCDC);
  static const Color _greyText = Color(0xFF555555);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;
      if (_isLogin) {
        await AuthService.signIn(email, pass);
      } else {
        await AuthService.register(_nameCtrl.text.trim(), email, pass);
      }
      // Al iniciar sesión, AuthGate cambia solo a la pantalla de inicio.
    } on FirebaseAuthException catch (e) {
      _msg(AuthService.errorText(e));
    } catch (_) {
      _msg('Ocurrió un error. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgot() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _msg('Escribe tu correo arriba para enviarte el enlace.');
      return;
    }
    try {
      await AuthService.resetPassword(email);
      _msg('Te enviamos un correo para restablecer tu contraseña.');
    } on FirebaseAuthException catch (e) {
      _msg(AuthService.errorText(e));
    } catch (_) {
      _msg('No se pudo enviar el correo.');
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
    });
  }

  OutlineInputBorder _outline([Color? color, double width = 2]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: color == null
          ? BorderSide.none
          : BorderSide(color: color, width: width),
    );
  }

  // Campo gris en forma de píldora, con ícono a la izquierda.
  Widget _pill({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? type,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      textCapitalization: capitalization,
      validator: validator,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF666666),
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: _greyText, size: 26),
        filled: true,
        fillColor: _fieldColor,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 20,
        ),
        errorStyle: const TextStyle(fontWeight: FontWeight.bold),
        border: _outline(),
        enabledBorder: _outline(),
        focusedBorder: _outline(kOrange),
        errorBorder: _outline(Colors.red, 1.5),
        focusedErrorBorder: _outline(Colors.red, 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOrange,
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          // Alto mínimo para que el formulario nunca se aplaste;
          // si el teclado reduce la pantalla, se puede deslizar.
          final h = max(c.maxHeight, 700.0);
          // La maqueta mide 414 x 896: todo se escala a partir de ahí.
          final s = w / 414;

          Widget dot(double cx, double cy, double d, Color color) {
            return Positioned(
              left: cx * s - d * s / 2,
              top: cy / 896 * h - d * s / 2,
              width: d * s,
              height: d * s,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            );
          }

          return SingleChildScrollView(
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: [
                  // Óvalo blanco grande del centro
                  Positioned(
                    left: -0.338 * w,
                    top: 0.16 * h,
                    width: 1.676 * w,
                    height: 0.757 * h,
                    child: const ClipOval(child: ColoredBox(color: Colors.white)),
                  ),

                  // Círculos blancos sobre el fondo naranja
                  dot(41, 100, 112, Colors.white),
                  dot(170, 17, 27, Colors.white),
                  dot(379, 70, 28, Colors.white),
                  dot(372, 858, 118, Colors.white),
                  dot(205, 854, 28, Colors.white),

                  // Círculos naranjas sobre el óvalo blanco
                  dot(292, 195, 28, kOrange),
                  dot(30, 375, 28, kOrange),
                  dot(387, 481, 28, kOrange),
                  dot(47, 751, 28, kOrange),

                  // Formulario
                  Positioned(
                    left: 0.09 * w,
                    right: 0.09 * w,
                    top: (_isLogin ? 0.37 : 0.27) * h,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Text(
                            _isLogin ? '¡Bienvenido!' : 'Crea tu cuenta',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 26),
                          if (!_isLogin) ...[
                            _pill(
                              controller: _nameCtrl,
                              hint: 'Nombre',
                              icon: Icons.person,
                              capitalization: TextCapitalization.words,
                              validator: (v) =>
                                  (v == null || v.trim().length < 2)
                                  ? 'Escribe tu nombre'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                          ],
                          _pill(
                            controller: _emailCtrl,
                            hint: 'Correo',
                            icon: Icons.mail,
                            type: TextInputType.emailAddress,
                            validator: (v) {
                              final t = v?.trim() ?? '';
                              if (t.isEmpty) return 'Escribe tu correo';
                              if (!t.contains('@') || !t.contains('.')) {
                                return 'Correo no válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _pill(
                            controller: _passCtrl,
                            hint: 'Contraseña',
                            icon: Icons.vpn_key,
                            obscure: true,
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Mínimo 6 caracteres'
                                : null,
                          ),
                          if (!_isLogin) ...[
                            const SizedBox(height: 16),
                            _pill(
                              controller: _pass2Ctrl,
                              hint: 'Confirmar contraseña',
                              icon: Icons.vpn_key,
                              obscure: true,
                              validator: (v) => v != _passCtrl.text
                                  ? 'Las contraseñas no coinciden'
                                  : null,
                            ),
                          ],
                          if (_isLogin)
                            TextButton(
                              onPressed: _loading ? null : _forgot,
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                  color: _greyText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 10),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kOrange,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: const StadiumBorder(),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Text(
                                      _isLogin ? 'Iniciar sesión' : 'Registrarme',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Enlace de abajo
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0.855 * h - 16,
                    child: Center(
                      child: TextButton(
                        onPressed: _loading ? null : _toggleMode,
                        child: Text(
                          _isLogin
                              ? '¿Aún no tienes una cuenta? Únete aquí'
                              : '¿Ya tienes cuenta? Inicia sesión',
                          style: const TextStyle(
                            color: _greyText,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// PARQUEADEROS Y RESERVAS EN TIEMPO REAL (Firestore)
//
//  parkings/{id}  -> name, total, ocupados, lat, lng
//  reservas/{uid} -> reserva activa del usuario (un doc por usuario,
//                    así es imposible tener dos reservas a la vez)
//  users/{uid}    -> nombre, email
// ============================================================

class ParkingException implements Exception {
  final String message;
  ParkingException(this.message);
}

class Parking {
  final String id;
  final String name;
  final int total;
  final int ocupados;
  final LatLng point;

  const Parking({
    required this.id,
    required this.name,
    required this.total,
    required this.ocupados,
    required this.point,
  });

  int get disponibles => max(0, total - ocupados);
  bool get lleno => disponibles <= 0;

  factory Parking.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};
    return Parking(
      id: d.id,
      name: (data['name'] ?? 'Parqueadero') as String,
      total: ((data['total'] ?? 0) as num).toInt(),
      ocupados: ((data['ocupados'] ?? 0) as num).toInt(),
      point: LatLng(
        ((data['lat'] ?? 0) as num).toDouble(),
        ((data['lng'] ?? 0) as num).toDouble(),
      ),
    );
  }
}

class Reserva {
  final String parkingId;
  final String parkingName;
  final String plate;

  const Reserva({
    required this.parkingId,
    required this.parkingName,
    required this.plate,
  });

  factory Reserva.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};
    return Reserva(
      parkingId: (data['parkingId'] ?? '') as String,
      parkingName: (data['parkingName'] ?? '') as String,
      plate: (data['placa'] ?? '') as String,
    );
  }
}

class ParkingService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _parkings =>
      _db.collection('parkings');

  static DocumentReference<Map<String, dynamic>> _reservaRef(String uid) =>
      _db.collection('reservas').doc(uid);

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // Datos iniciales (los mismos de ejemplo que tenía la app).
  static const List<Map<String, dynamic>> _seed = [
    {
      'id': 'parqueadero1',
      'name': 'Parqueadero 1',
      'total': 100,
      'ocupados': 80,
      'lat': 7.103941,
      'lng': -73.122502,
    },
    {
      'id': 'parqueadero2',
      'name': 'Parqueadero 2',
      'total': 100,
      'ocupados': 55,
      'lat': 7.105799,
      'lng': -73.123264,
    },
    {
      'id': 'parqueadero3',
      'name': 'Parqueadero 3',
      'total': 100,
      'ocupados': 92,
      'lat': 7.107119,
      'lng': -73.122615,
    },
  ];

  /// Crea los parqueaderos de ejemplo UNA sola vez (config/parkings_seed).
  /// Sin esta marca, los parqueaderos que el administrador elimine se
  /// volverían a crear cada vez que alguien abre la pantalla de parqueaderos.
  static Future<void> seedIfNeeded() async {
    try {
      final marker = _db.collection('config').doc('parkings_seed');
      if ((await marker.get()).exists) return;

      for (final p in _seed) {
        final ref = _parkings.doc(p['id'] as String);
        await _db.runTransaction((tx) async {
          final snap = await tx.get(ref);
          if (!snap.exists) {
            tx.set(ref, {
              'name': p['name'],
              'total': p['total'],
              'ocupados': p['ocupados'],
              'lat': p['lat'],
              'lng': p['lng'],
            });
          }
        });
      }
      await marker.set({'hecho': true, 'creado': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('No se pudieron crear los parqueaderos: $e');
    }
  }

  /// Lista de parqueaderos que se actualiza sola en todos los celulares.
  static Stream<List<Parking>> watchParkings() {
    return _parkings.snapshots().map((snap) {
      final list = snap.docs.map(Parking.fromDoc).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  /// Reserva activa del usuario actual (null si no tiene).
  static Stream<Reserva?> watchMyReserva() {
    final uid = _uid;
    if (uid == null) return const Stream<Reserva?>.empty();
    return _reservaRef(
      uid,
    ).snapshots().map((d) => d.exists ? Reserva.fromDoc(d) : null);
  }

  /// Reserva un cupo. Usa una transacción: si dos personas piden el último
  /// cupo al mismo tiempo, solo una lo consigue.
  static Future<void> reserve({
    required String parkingId,
    required String plate,
  }) async {
    final uid = _uid;
    if (uid == null) throw ParkingException('Debes iniciar sesión.');

    final pRef = _parkings.doc(parkingId);
    final rRef = _reservaRef(uid);

    await _db.runTransaction((tx) async {
      final pSnap = await tx.get(pRef);
      final rSnap = await tx.get(rRef);

      if (!pSnap.exists) throw ParkingException('El parqueadero no existe.');
      if (rSnap.exists) {
        throw ParkingException(
          'Ya tienes una reserva activa. Cancélala para hacer otra.',
        );
      }

      final data = pSnap.data()!;
      final total = ((data['total'] ?? 0) as num).toInt();
      final ocupados = ((data['ocupados'] ?? 0) as num).toInt();
      if (ocupados >= total) {
        throw ParkingException('Este parqueadero está ocupado (sin cupos).');
      }

      tx.update(pRef, {'ocupados': ocupados + 1});
      tx.set(rRef, {
        'uid': uid,
        'parkingId': parkingId,
        'parkingName': data['name'],
        'placa': plate,
        'codigo': '',
        'creada': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Cancela la reserva del usuario y libera el cupo para todos.
  static Future<void> release() async {
    final uid = _uid;
    if (uid == null) return;
    final rRef = _reservaRef(uid);

    await _db.runTransaction((tx) async {
      final rSnap = await tx.get(rRef);
      if (!rSnap.exists) return;

      final pRef = _parkings.doc(rSnap.data()!['parkingId'] as String);
      final pSnap = await tx.get(pRef);

      if (pSnap.exists) {
        final ocupados = ((pSnap.data()!['ocupados'] ?? 0) as num).toInt();
        tx.update(pRef, {'ocupados': ocupados > 0 ? ocupados - 1 : 0});
      }
      tx.delete(rRef);
    });
  }

  /// Lee una sola vez la reserva activa del usuario (null si no tiene).
  static Future<Reserva?> getMyReserva() async {
    final uid = _uid;
    if (uid == null) return null;
    final d = await _reservaRef(uid).get();
    return d.exists ? Reserva.fromDoc(d) : null;
  }

  /// Guarda el último código QR generado en la reserva.
  static Future<void> saveCode(String code, DateTime expiresAt) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _reservaRef(
        uid,
      ).update({'codigo': code, 'vence': Timestamp.fromDate(expiresAt)});
    } catch (e) {
      debugPrint('No se pudo guardar el código: $e');
    }
  }
}

// ============================================================
// PANTALLAS
// ============================================================

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
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
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
                StreamBuilder<Reserva?>(
                  stream: ParkingService.watchMyReserva(),
                  builder: (context, reservaSnap) {
                    final reserva = reservaSnap.data;

                    return StreamBuilder<String?>(
                      stream: AdminService.watchRole(), // Nueva función que veremos en el Paso 3
                      builder: (context, roleSnap) {
                        final role = roleSnap.data;

                        // 1. VISTA DEL PORTERO
                        if (role == 'portero') {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              children: [
                                const Icon(Icons.security, size: 64, color: kOrange),
                                const SizedBox(height: 16),
                                const Text('Modo Portero', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PorterScreen())),
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: const Text('Escanear QR de Estudiante'),
                                  style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.black),
                                )
                              ],
                            ),
                          );
                        }

                        // 2. VISTA DEL ADMIN (Para que no reserve)
                        if (role == 'admin') {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                            child: const Column(
                              children: [
                                Icon(Icons.admin_panel_settings, size: 64, color: kOrange),
                                SizedBox(height: 16),
                                Text('Modo Administrador', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                SizedBox(height: 8),
                                Text('Usa el menú de ajustes para gestionar los parqueaderos.', textAlign: TextAlign.center),
                              ],
                            ),
                          );
                        }

                        // 3. VISTA DEL ESTUDIANTE (Normal)
                        return Column(
                          children: [
                            _ReserveCard(
                              onTap: () {
                                if (reserva != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Ya tienes una reserva activa. Cancélala para hacer otra.')),
                                  );
                                  return;
                                }
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const VehiclesScreen()));
                              },
                            ),
                            if (reserva != null) ...[
                              const SizedBox(height: 16),
                              _ActiveReservaCard(reserva: reserva),
                            ],
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    );
                  },
                ),
                  ],
                ),
              ),
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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final email = user?.email ?? '';
        final name = (user?.displayName?.isNotEmpty ?? false)
            ? user!.displayName!
            : (email.isNotEmpty ? email.split('@').first : 'Usuario');

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // La opción de administrador solo aparece si users/{uid}.rol == 'admin'.
              StreamBuilder<bool>(
                stream: AdminService.watchIsAdmin(),
                initialData: false,
                builder: (context, adminSnap) {
                  final isAdmin = adminSnap.data == true;
                  return PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'logout') AuthService.signOut();
                      if (value == 'admin') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminParkingsScreen(),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      if (isAdmin)
                        const PopupMenuItem(
                          value: 'admin',
                          child: Text('Administrar parqueaderos'),
                        ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Text('Cerrar sesión'),
                      ),
                    ],
                    child: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.settings, color: kOrange, size: 20),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
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

class _ActiveReservaCard extends StatelessWidget {
  final Reserva reserva;
  const _ActiveReservaCard({required this.reserva});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QrScreen(
              parkingId: reserva.parkingId,
              parkingName: reserva.parkingName,
              plate: reserva.plate,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.qr_code_2, size: 44, color: kOrange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reserva activa',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text('${reserva.parkingName} · ${reserva.plate}'),
                  const Text(
                    'Toca para ver tu código QR',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int selected;
  const _BottomBar({this.selected = 0});

  static const List<IconData> _icons = [
    Icons.home,
    Icons.person_outline,
    Icons.location_on,
    Icons.notifications,
  ];

  // Reemplaza la pila de pantallas: queda Inicio + la pantalla elegida.
  void _open(NavigatorState nav, Widget page) {
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => page),
      (route) => route.isFirst,
    );
  }

  Future<void> _go(BuildContext context, int index) async {
    if (index == selected) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    switch (index) {
      case 0: // Inicio
        nav.popUntil((route) => route.isFirst);
        break;
      case 1: // Mis vehículos
        _open(nav, const VehiclesScreen());
        break;
      case 2: // Parqueaderos
        _open(nav, const SelectParkingScreen());
        break;
      case 3: // Mi reserva (código QR)
        try {
          final reserva = await ParkingService.getMyReserva();
          if (reserva == null) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('No tienes una reserva activa.')),
              );
            return;
          }
          _open(
            nav,
            QrScreen(
              parkingId: reserva.parkingId,
              parkingName: reserva.parkingName,
              plate: reserva.plate,
            ),
          );
        } catch (_) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('No se pudo cargar tu reserva.')),
            );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.elliptical(200, 50)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i = 0; i < _icons.length; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _go(context, i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Icon(
                      _icons[i],
                      size: 36,
                      color: i == selected ? Colors.black : kOrange,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SelectParkingScreen extends StatefulWidget {
  final String? plate; // null = se entró desde la barra de abajo
  const SelectParkingScreen({super.key, this.plate});

  @override
  State<SelectParkingScreen> createState() => _SelectParkingScreenState();
}

class _SelectParkingScreenState extends State<SelectParkingScreen> {
  String? _selectedId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ParkingService.seedIfNeeded();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _reserve(Parking p) async {
    final plate = widget.plate;
    if (plate == null) {
      // Sin vehículo elegido: primero hay que escoger uno.
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const VehiclesScreen()),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ParkingService.reserve(parkingId: p.id, plate: plate);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QrScreen(
            parkingId: p.id,
            parkingName: p.name,
            plate: plate,
          ),
        ),
      );
    } on ParkingException catch (e) {
      _snack(e.message);
    } on FirebaseException catch (e) {
      _snack('No se pudo reservar (${e.code}).');
    } catch (_) {
      _snack('No se pudo reservar. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
              StreamBuilder<List<Parking>>(
                stream: ParkingService.watchParkings(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          'No se pudieron cargar los parqueaderos.\n'
                          'Revisa tu conexión y las reglas de Firestore.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    );
                  }
                  final list = snapshot.data;
                  if (list == null || list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  }

                  final selected = list.firstWhere(
                    (p) => p.id == _selectedId,
                    orElse: () => list.first,
                  );
                  final selectedIndex = list.indexOf(selected);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final p in list) ...[
                        _ParkingPill(
                          parking: p,
                          selected: p.id == selected.id,
                          onTap: () => setState(() => _selectedId = p.id),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 12),
                      _MapPreview(parkings: list, selected: selectedIndex),
                      const SizedBox(height: 32),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: selected.lleno
                                ? const Color(0xFFFFD6D6)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            selected.lleno
                                ? 'PARQUEADERO OCUPADO\n0/${selected.total}'
                                : 'Cupos disponibles\n'
                                      '${selected.disponibles}/${selected.total}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: selected.lleno
                                  ? Colors.red.shade900
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: (!selected.lleno && !_busy)
                              ? () => _reserve(selected)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreen,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                            shape: const StadiumBorder(
                              side: BorderSide(color: Colors.black),
                            ),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  widget.plate == null
                                      ? 'Elegir vehículo y reservar'
                                      : 'Seleccionar parqueadero',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParkingPill extends StatelessWidget {
  final Parking parking;
  final bool selected;
  final VoidCallback onTap;

  const _ParkingPill({
    required this.parking,
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
              parking.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: parking.lleno ? Colors.red : kGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                parking.lleno ? 'OCUPADO' : '${parking.disponibles} libres',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: parking.lleno ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  final List<Parking> parkings;
  final int selected;

  const _MapPreview({required this.parkings, required this.selected});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: FlutterMap(
          key: ValueKey(parkings[selected].id),
          options: MapOptions(
            initialCenter: parkings[selected].point,
            initialZoom: 16,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.parklife',
            ),
            MarkerLayer(
              markers: [
                for (int i = 0; i < parkings.length; i++)
                  Marker(
                    point: parkings[i].point,
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.location_on,
                      size: 44,
                      color: parkings[i].lleno
                          ? Colors.red.shade900
                          : (i == selected ? Colors.red : Colors.black54),
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
  final String id;
  final String plate;
  final String brand;
  final String model;
  final String color;

  const Vehicle({
    required this.id,
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
  int _selectedIndex = 0;
  bool _isAdding = false;

  final _formKey = GlobalKey<FormState>();
  final _plateCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _plateCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await VehicleService.addVehicle(
        plate: _plateCtrl.text.trim(),
        brand: _brandCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        color: _colorCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _isAdding = false;
          _saving = false;
          _plateCtrl.clear();
          _brandCtrl.clear();
          _modelCtrl.clear();
          _colorCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehículo agregado con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOrange,
      bottomNavigationBar: const _BottomBar(selected: 1),
      body: SafeArea(
        child: StreamBuilder<List<Vehicle>>(
          stream: VehicleService.watchMyVehicles(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final vehicles = snapshot.data ?? [];

            if (_isAdding) {
              return _buildAddForm();
            }

            if (vehicles.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_car, size: 80, color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      'No tienes vehículos registrados',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _isAdding = true),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar mi vehículo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: const StadiumBorder(side: BorderSide(color: Colors.black)),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (_selectedIndex >= vehicles.length) _selectedIndex = 0;
            final v = vehicles[_selectedIndex];

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
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
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.white),
                          onPressed: () => setState(() => _isAdding = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedIndex,
                        isExpanded: true,
                        icon: const CircleAvatar(
                          radius: 11,
                          backgroundColor: Colors.black,
                          child: Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white),
                        ),
                        style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
                        items: [
                          for (int i = 0; i < vehicles.length; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text('Vehículo ${i + 1} (${vehicles[i].plate})'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _selectedIndex = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                                    builder: (context) => SelectParkingScreen(plate: v.plate),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                decoration: BoxDecoration(
                                  color: kGreen,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.black),
                                ),
                                child: const Text(
                                  'RESERVAR',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAddForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => setState(() => _isAdding = false),
                    child: const Icon(Icons.arrow_back, color: Colors.black),
                  ),
                ),
                const Text(
                  'Nuevo vehículo',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _plateCtrl,
                    decoration: const InputDecoration(labelText: 'Placa'),
                    validator: (v) => v!.isEmpty ? 'Escribe la placa' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _brandCtrl,
                    decoration: const InputDecoration(labelText: 'Marca'),
                    validator: (v) => v!.isEmpty ? 'Escribe la marca' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _modelCtrl,
                    decoration: const InputDecoration(labelText: 'Modelo (Opcional)'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _colorCtrl,
                    decoration: const InputDecoration(labelText: 'Color'),
                    validator: (v) => v!.isEmpty ? 'Escribe el color' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _saveVehicle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 48),
                      shape: const StadiumBorder(side: BorderSide(color: Colors.black)),
                    ),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text('Guardar vehículo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
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
  final String parkingId;
  final String parkingName;
  final String plate;

  const QrScreen({
    super.key,
    required this.parkingId,
    required this.parkingName,
    required this.plate,
  });

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  static const Duration _validity = Duration(minutes: 30);

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

  // Crea un código nuevo, lo guarda en la reserva y reinicia la cuenta regresiva.
  void _generate() {
    _timer?.cancel();
    final rnd = Random.secure();
    _code = List.generate(
      8,
      (_) => rnd.nextInt(16).toRadixString(16),
    ).join().toUpperCase();
    _expiresAt = DateTime.now().add(_validity);
    _remaining = _validity;

    ParkingService.saveCode(_code, _expiresAt);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final left = _expiresAt.difference(DateTime.now());
      if (left <= Duration.zero) {
        _timer?.cancel();
        setState(() => _remaining = Duration.zero);

        // Si el tiempo expira, liberamos el cupo automáticamente
        await ParkingService.release();
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
    'uid': FirebaseAuth.instance.currentUser?.uid,
    'parqueadero': widget.parkingName,
    'placa': widget.plate,
    'vence': _expiresAt.toIso8601String(),
  });

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: Text('Se liberará tu cupo en ${widget.parkingName}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await ParkingService.release();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cancelar la reserva.')),
      );
    }
  }

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
                '${widget.parkingName} · ${widget.plate}',
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
              OutlinedButton.icon(
                onPressed: _cancel,
                icon: const Icon(Icons.close),
                label: const Text('Cancelar reserva'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  shape: const StadiumBorder(),
                ),
              ),
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