import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'main.dart' show kOrange, kGreen;

class PorterScreen extends StatefulWidget {
  const PorterScreen({super.key});

  @override
  State<PorterScreen> createState() => _PorterScreenState();
}

class _PorterScreenState extends State<PorterScreen> {
  bool _scanning = true;
  bool _procesando = false; // Evita escanear el mismo QR muchas veces seguidas
  String _mensaje = 'Apunta la cámara al código QR del estudiante';

  Future<void> _procesarQR(String data) async {
    if (_procesando) return;

    setState(() {
      _procesando = true;
      _scanning = false;
      _mensaje = 'Verificando...';
    });

    try {
      final Map<String, dynamic> qrData = jsonDecode(data);
      final String? codigo = qrData['reserva'];
      final String? tipo = qrData['tipo'];

      if (codigo == null || codigo.isEmpty) {
        setState(() => _mensaje = '❌ QR inválido');
        return;
      }

      // ==========================================
      // 🟢 CASO 1: ES UN QR DE SALIDA
      // ==========================================
      if (tipo == 'salida' || codigo.startsWith('SALIDA-')) {
        final String uid = qrData['uid'];
        final rRef = FirebaseFirestore.instance.collection('reservas').doc(uid);

        await FirebaseFirestore.instance.runTransaction((tx) async {
          final rSnap = await tx.get(rRef);
          if (rSnap.exists) {
            final parkingId = rSnap.data()!['parkingId'];
            final pRef = FirebaseFirestore.instance.collection('parkings').doc(parkingId);
            final pSnap = await tx.get(pRef);

            if (pSnap.exists) {
              final ocupados = ((pSnap.data()!['ocupados'] ?? 0) as num).toInt();
              // Liberamos el cupo sumando 1 al disponible
              tx.update(pRef, {'ocupados': ocupados > 0 ? ocupados - 1 : 0});
            }
            // Borramos la reserva para que el estudiante pueda volver a usar la app
            tx.delete(rRef);
          }
        });

        setState(() => _mensaje = '✅ Salida exitosa.\nEl cupo ha sido liberado.');
        return;
      }

      // ==========================================
      // 🔵 CASO 2: ES UN QR DE ENTRADA
      // ==========================================
      final reservas = await FirebaseFirestore.instance
          .collection('reservas')
          .where('codigo', isEqualTo: codigo)
          .get();

      if (reservas.docs.isEmpty) {
        setState(() => _mensaje = '❌ Código no válido o no existe en la base de datos');
        return;
      }

      final reservaDoc = reservas.docs.first;
      final reservaData = reservaDoc.data();

      if (reservaData['usado'] == true) {
        setState(() => _mensaje = '⚠️ Este código ya fue usado (el carro ya está adentro)');
        return;
      }

      final Timestamp? venceTs = reservaData['vence'];
      if (venceTs != null && venceTs.toDate().isBefore(DateTime.now())) {
        setState(() => _mensaje = '❌ Código expirado');
        return;
      }

      // Marcar entrada y poner cronómetro de 2 horas
      final horaSalida = DateTime.now().add(const Duration(hours: 2));
      await reservaDoc.reference.update({
        'usado': true,
        'entrada': FieldValue.serverTimestamp(),
        'salidaEstimada': Timestamp.fromDate(horaSalida),
      });

      setState(() {
        _mensaje = '✅ ¡Acceso Permitido!\nSe libera a las ${horaSalida.hour}:${horaSalida.minute.toString().padLeft(2, '0')}';
      });

    } catch (e) {
      setState(() => _mensaje = 'Error al leer QR: $e');
    } finally {
      // Esperamos 3 segundos antes de permitir escanear de nuevo
      await Future.delayed(const Duration(seconds: 3));
      setState(() => _procesando = false);
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