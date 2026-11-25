import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'main.dart' show kOrange, kGreen, ParkingService;

class PorterScreen extends StatefulWidget {
  const PorterScreen({super.key});

  @override
  State<PorterScreen> createState() => _PorterScreenState();
}

class _PorterScreenState extends State<PorterScreen> {
  bool _scanning = true;
  String _mensaje = 'Apunta la cámara al código QR del estudiante';

  Future<void> _procesarQR(String data) async {
    setState(() {
      _scanning = false;
      _mensaje = 'Verificando...';
    });

    try {
      // Buscamos la reserva por el código escaneado (asumiendo que el QR trae el código)
      final reservas = await FirebaseFirestore.instance
          .collection('reservas')
          .where('codigo', isEqualTo: data)
          .get();

      if (reservas.docs.isEmpty) {
        setState(() => _mensaje = '❌ Código no válido o ya expiró');
        return;
      }

      final reservaDoc = reservas.docs.first;
      final reservaData = reservaDoc.data();

      // Validar que no se haya usado
      if (reservaData['usado'] == true) {
        setState(() => _mensaje = '⚠️ Este código ya fue usado');
        return;
      }

      // Marcar como usado y poner cronómetro de 2 horas
      final horaSalida = DateTime.now().add(const Duration(hours: 2));
      await reservaDoc.reference.update({
        'usado': true,
        'entrada': FieldValue.serverTimestamp(),
        'salidaEstimada': Timestamp.fromDate(horaSalida),
      });

      setState(() => _mensaje = '✅ ¡Acceso Permitido!\nSe libera a las ${horaSalida.hour}:${horaSalida.minute.toString().padLeft(2, '0')}');

      // Opcional: Un sonido o vibración aquí sería ideal

    } catch (e) {
      setState(() => _mensaje = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOrange,
      appBar: AppBar(
        title: const Text('Control de Acceso'),
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            color: Colors.white,
            child: Text(
              _mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _scanning
                ? MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _procesarQR(barcode.rawValue!);
                    break; // Solo procesamos el primero
                  }
                }
              },
            )
                : Center(
              child: ElevatedButton.icon(
                onPressed: () => setState(() {
                  _scanning = true;
                  _mensaje = 'Apunta la cámara al código QR del estudiante';
                }),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear otro'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}