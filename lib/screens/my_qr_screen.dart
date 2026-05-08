import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MyQrScreen extends StatelessWidget {
  const MyQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Mi Código QR',
                        style: TextStyle(color: AppColors.sentryNavy, fontWeight: FontWeight.bold, fontSize: 24)),
                    Text('RF5 · Entrada al evento',
                        style: TextStyle(color: AppColors.sentryGrey, fontSize: 14)),
                  ],
                ),
                _statusBadge('En línea', Colors.green),
              ],
            ),

            const SizedBox(height: 25),

            // Tarjeta del Usuario y QR
            _buildQrMainCard(),

            const SizedBox(height: 25),

            // Botones de Acción
            Row(
              children: [
                Expanded(child: _actionButton('Descargar', Icons.download_rounded, AppColors.sentryBlue)),
                const SizedBox(width: 15),
                Expanded(child: _actionButton('Compartir', Icons.share_rounded, AppColors.sentryGrey)),
              ],
            ),

            const SizedBox(height: 25),

            // Información de uso único
            _buildInfoNotice(),

            const SizedBox(height: 25),

            // Instrucciones
            const Text('¿Cómo usarlo?',
                style: TextStyle(color: AppColors.sentryNavy, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),
            _stepItem(1, 'Llega al punto de ingreso del evento'),
            _stepItem(2, 'Muestra esta pantalla al guardia'),
            _stepItem(3, 'El guardia escaneará el código con Sentry'),
            _stepItem(4, 'Recibirás confirmación de acceso'),
          ],
        ),
      ),
    );
  }

  Widget _buildQrMainCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundImage: NetworkImage('https://via.placeholder.com/150'), // Aquí irá tu foto
            ),
            title: const Text('Iván Alejandro Daqui',
                style: TextStyle(color: AppColors.sentryNavy, fontWeight: FontWeight.bold)),
            subtitle: const Text('FIE - Estudiante', style: TextStyle(fontSize: 12)),
            trailing: _statusBadge('Válido', AppColors.sentryBlue),
          ),
          const Divider(height: 30),
          // Simulación de QR (puedes usar el package qr_flutter luego)
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.sentryBg, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Image.network(
              'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=SENTRY-USR-4821',
              height: 200,
              width: 200,
            ),
          ),
          const SizedBox(height: 15),
          const Text('Toca para ampliar',
              style: TextStyle(color: AppColors.sentryGrey, fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          _qrDataRow('Código único', 'SENTRY-QR-2026-ID'),
          _qrDataRow('Válido para', '20 Jun 2026 · 1 uso'),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _qrDataRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.sentryGrey, fontSize: 13)),
          Text(val, style: const TextStyle(color: AppColors.sentryNavy, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color) {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildInfoNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sentryNavy.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.sentryNavy.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.shield_outlined, color: AppColors.sentryNavy, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Este QR es personal e intransferible. El sistema detecta y rechaza usos duplicados automáticamente.',
              style: TextStyle(color: AppColors.sentryNavy, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepItem(int num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.sentryBlue,
            child: Text('$num', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: AppColors.sentryNavy, fontSize: 14)),
        ],
      ),
    );
  }
}