import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// main.dart y este archivo se importan entre sí (Dart lo permite): aquí se
// reutilizan los colores, el modelo Parking y el servicio de lectura.
import 'main.dart'
    show kOrange, kGreen, Parking, ParkingException, ParkingService;

// ============================================================
// ADMINISTRADOR · GESTIÓN DE PARQUEADEROS (CRUD en Firestore)
//
//  users/{uid}.rol == 'admin'  -> el usuario es administrador
//  parkings/{id}               -> name, total, ocupados, lat, lng, creado
//
// La lectura en tiempo real reutiliza ParkingService.watchParkings():
// cualquier alta, edición o baja se refleja sola en la lista.
// ============================================================

class AdminService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _parkings =>
      _db.collection('parkings');

  /// true si el usuario actual tiene `rol: 'admin'` en users/{uid}.
  static Stream<bool> watchIsAdmin() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream<bool>.value(false);
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((d) => d.data()?['rol'] == 'admin');
  }

  /// Agrega un parqueadero nuevo (empieza con 0 cupos ocupados).
  static Future<void> create({
    required String name,
    required int total,
    required double lat,
    required double lng,
  }) async {
    await _parkings.add({
      'name': name,
      'total': total,
      'ocupados': 0,
      'lat': lat,
      'lng': lng,
      'creado': FieldValue.serverTimestamp(),
    });
  }

  /// Edita un parqueadero. Usa una transacción para comprobar que el nuevo
  /// total no sea menor que los cupos ocupados en ese momento.
  static Future<void> update({
    required String id,
    required String name,
    required int total,
    required double lat,
    required double lng,
  }) async {
    final ref = _parkings.doc(id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw ParkingException('Este parqueadero ya no existe.');
      }
      final ocupados = ((snap.data()!['ocupados'] ?? 0) as num).toInt();
      if (total < ocupados) {
        throw ParkingException(
          'El total no puede ser menor que los cupos ocupados ($ocupados).',
        );
      }
      tx.update(ref, {'name': name, 'total': total, 'lat': lat, 'lng': lng});
    });
  }

  /// Elimina un parqueadero. No se permite si tiene cupos ocupados o
  /// reservas activas, para no dejar reservas apuntando a un documento que
  /// ya no existe.
  static Future<void> delete(String id) async {
    final ref = _parkings.doc(id);
    final snap = await ref.get();
    if (!snap.exists) throw ParkingException('Este parqueadero ya no existe.');

    final ocupados = ((snap.data()!['ocupados'] ?? 0) as num).toInt();
    if (ocupados > 0) {
      throw ParkingException(
        'No se puede eliminar: tiene $ocupados cupo(s) ocupado(s).',
      );
    }

    final reservas = await _db
        .collection('reservas')
        .where('parkingId', isEqualTo: id)
        .limit(1)
        .get();
    if (reservas.docs.isNotEmpty) {
      throw ParkingException('No se puede eliminar: tiene reservas activas.');
    }

    await ref.delete();
  }

  static String errorText(Object e) {
    if (e is ParkingException) return e.message;
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'No tienes permisos de administrador para hacer esto.';
        case 'unavailable':
          return 'Sin conexión a internet.';
        default:
          return 'Error de Firebase (${e.code}).';
      }
    }
    return 'Ocurrió un error. Intenta de nuevo.';
  }
}

/// Muestra un mensaje de éxito (verde) o de error (rojo).
void _adminSnack(ScaffoldMessengerState m, String text, {bool error = false}) {
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: error ? Colors.red.shade700 : kGreen,
        content: Text(
          text,
          style: TextStyle(
            color: error ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
}

// ------------------------------------------------------------
// Lista de parqueaderos (pantalla principal del administrador)
// ------------------------------------------------------------

class AdminParkingsScreen extends StatefulWidget {
  const AdminParkingsScreen({super.key});

  @override
  State<AdminParkingsScreen> createState() => _AdminParkingsScreenState();
}

class _AdminParkingsScreenState extends State<AdminParkingsScreen> {
  bool _busy = false;

  void _openForm(List<Parking> all, [Parking? parking]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AdminParkingFormScreen(parking: parking, existing: all),
      ),
    );
  }

  Future<void> _delete(Parking p) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar parqueadero'),
        content: Text('Se eliminará "${p.name}". Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await AdminService.delete(p.id);
      _adminSnack(messenger, 'Parqueadero "${p.name}" eliminado.');
    } catch (e) {
      _adminSnack(messenger, AdminService.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOrange,
      body: SafeArea(
        child: StreamBuilder<bool>(
          stream: AdminService.watchIsAdmin(),
          builder: (context, adminSnap) {
            if (adminSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            if (adminSnap.data != true) return const _NotAdminView();
            return _buildList();
          },
        ),
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<List<Parking>>(
      stream: ParkingService.watchParkings(),
      builder: (context, snapshot) {
        final list = snapshot.data;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    'Parqueaderos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  onPressed: (list == null || _busy)
                      ? null
                      : () => _openForm(list),
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Agregar parqueadero',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
                ),
              ),
              const SizedBox(height: 24),
              if (snapshot.hasError)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'No se pudieron cargar los parqueaderos.\n'
                      'Revisa tu conexión y las reglas de Firestore.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                )
              else if (list == null)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              else if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'Aún no hay parqueaderos.\nAgrega el primero.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                )
              else
                for (final p in list) ...[
                  _AdminParkingCard(
                    parking: p,
                    enabled: !_busy,
                    onEdit: () => _openForm(list, p),
                    onDelete: () => _delete(p),
                  ),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _NotAdminView extends StatelessWidget {
  const _NotAdminView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.black),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Acceso restringido.\nSolo los administradores pueden '
                'gestionar los parqueaderos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminParkingCard extends StatelessWidget {
  final Parking parking;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminParkingCard({
    required this.parking,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = parking;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: p.lleno ? Colors.red : kGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    p.lleno
                        ? 'OCUPADO ${p.ocupados}/${p.total}'
                        : '${p.disponibles} libres · ${p.ocupados}/${p.total} ocupados',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: p.lleno ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Lat ${p.point.latitude.toStringAsFixed(6)} · '
                  'Lng ${p.point.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar',
            onPressed: enabled ? onEdit : null,
            icon: const Icon(Icons.edit, color: kOrange),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: enabled ? onDelete : null,
            icon: Icon(Icons.delete, color: Colors.red.shade700),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Formulario (sirve para agregar y para editar)
// ------------------------------------------------------------

class AdminParkingFormScreen extends StatefulWidget {
  /// null = agregar uno nuevo.
  final Parking? parking;

  /// Lista actual, para evitar nombres repetidos.
  final List<Parking> existing;

  const AdminParkingFormScreen({
    super.key,
    this.parking,
    required this.existing,
  });

  @override
  State<AdminParkingFormScreen> createState() =>
      _AdminParkingFormScreenState();
}

class _AdminParkingFormScreenState extends State<AdminParkingFormScreen> {
  static const Color _fieldColor = Color(0xFFDCDCDC);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _totalCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  bool _saving = false;

  bool get _isEdit => widget.parking != null;

  @override
  void initState() {
    super.initState();
    final p = widget.parking;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _totalCtrl = TextEditingController(text: p == null ? '' : '${p.total}');
    _latCtrl = TextEditingController(text: p == null ? '' : '${p.point.latitude}');
    _lngCtrl = TextEditingController(text: p == null ? '' : '${p.point.longitude}');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _totalCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  double? _parseDouble(String? v) =>
      double.tryParse((v ?? '').trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final name = _nameCtrl.text.trim();
    final total = int.parse(_totalCtrl.text.trim());
    final lat = _parseDouble(_latCtrl.text)!;
    final lng = _parseDouble(_lngCtrl.text)!;

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await AdminService.update(
          id: widget.parking!.id,
          name: name,
          total: total,
          lat: lat,
          lng: lng,
        );
      } else {
        await AdminService.create(name: name, total: total, lat: lat, lng: lng);
      }
      _adminSnack(
        messenger,
        _isEdit
            ? 'Parqueadero "$name" actualizado.'
            : 'Parqueadero "$name" agregado.',
      );
      nav.pop();
    } catch (e) {
      _adminSnack(messenger, AdminService.errorText(e), error: true);
      if (mounted) setState(() => _saving = false);
    }
  }

  OutlineInputBorder _outline([Color? color, double width = 2]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: color == null
          ? BorderSide.none
          : BorderSide(color: color, width: width),
    );
  }

  // Mismo estilo de campo en píldora gris de la pantalla de inicio de sesión.
  Widget _pill({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? type,
    List<TextInputFormatter>? formatters,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      inputFormatters: formatters,
      textCapitalization: capitalization,
      validator: validator,
      enabled: !_saving,
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
        prefixIcon: Icon(icon, color: const Color(0xFF555555), size: 26),
        filled: true,
        fillColor: _fieldColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        errorStyle: const TextStyle(fontWeight: FontWeight.bold),
        border: _outline(),
        enabledBorder: _outline(),
        focusedBorder: _outline(kOrange),
        errorBorder: _outline(Colors.red, 1.5),
        focusedErrorBorder: _outline(Colors.red, 2),
      ),
    );
  }

  static final _decimalFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9\-\.,]'),
  );

  @override
  Widget build(BuildContext context) {
    final p = widget.parking;

    return Scaffold(
      backgroundColor: kOrange,
      body: SafeArea(
        child: SingleChildScrollView(
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
                        onTap: _saving ? null : () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, color: Colors.black),
                      ),
                    ),
                    Text(
                      _isEdit ? 'Editar parqueadero' : 'Nuevo parqueadero',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
                    children: [
                      _pill(
                        controller: _nameCtrl,
                        hint: 'Nombre',
                        icon: Icons.local_parking,
                        capitalization: TextCapitalization.words,
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'Escribe el nombre';
                          if (t.length < 3) return 'Mínimo 3 caracteres';
                          if (t.length > 40) return 'Máximo 40 caracteres';
                          final repeated = widget.existing.any(
                            (o) =>
                                o.id != p?.id &&
                                o.name.trim().toLowerCase() == t.toLowerCase(),
                          );
                          if (repeated) return 'Ya existe un parqueadero así';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _pill(
                        controller: _totalCtrl,
                        hint: 'Total de espacios',
                        icon: Icons.grid_view,
                        type: TextInputType.number,
                        formatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null) return 'Escribe el total de espacios';
                          if (n < 1) return 'Debe ser al menos 1';
                          if (n > 10000) return 'Máximo 10000';
                          if (p != null && n < p.ocupados) {
                            return 'No puede ser menor a los ocupados (${p.ocupados})';
                          }
                          return null;
                        },
                      ),
                      if (p != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Ocupados ahora: ${p.ocupados}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _pill(
                        controller: _latCtrl,
                        hint: 'Latitud (ej. 7.103941)',
                        icon: Icons.location_on,
                        type: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        formatters: [_decimalFormatter],
                        validator: (v) {
                          final d = _parseDouble(v);
                          if (d == null) return 'Escribe la latitud';
                          if (d < -90 || d > 90) return 'Debe estar entre -90 y 90';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _pill(
                        controller: _lngCtrl,
                        hint: 'Longitud (ej. -73.122502)',
                        icon: Icons.location_on_outlined,
                        type: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        formatters: [_decimalFormatter],
                        validator: (v) {
                          final d = _parseDouble(v);
                          if (d == null) return 'Escribe la longitud';
                          if (d < -180 || d > 180) {
                            return 'Debe estar entre -180 y 180';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreen,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: const StadiumBorder(
                              side: BorderSide(color: Colors.black),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  _isEdit ? 'Guardar cambios' : 'Agregar',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
