import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PaymentStatusScreen extends StatelessWidget {
  const PaymentStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estado del Pago',
                style: TextStyle(color: AppColors.sentryNavy, fontWeight: FontWeight.bold, fontSize: 24)),
            const Text('RF4 · Seguimiento de tu comprobante',
                style: TextStyle(color: AppColors.sentryGrey, fontSize: 14)),

            const SizedBox(height: 25),

            // Banner de Estado (Aprobado)
            _buildStatusBanner(),

            const SizedBox(height: 25),

            // Detalles del comprobante
            _buildSectionTitle('Detalles del comprobante'),
            _buildDetailsCard(),

            const SizedBox(height: 25),

            // Línea de tiempo / Seguimiento
            _buildSectionTitle('Seguimiento del proceso'),
            _buildTimeline(),

            const SizedBox(height: 30),

            // Botón de Acción Final
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                label: const Text('Ver mi código QR',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B), // Verde éxito del prototipo
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9), // Verde muy claro
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00897B).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF00897B),
            child: Icon(Icons.check, color: Colors.white),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Pago Aprobado',
                    style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Tu pago fue verificado. Tu código QR está disponible.',
                    style: TextStyle(color: Color(0xFF00695C), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _detailRow('Evento', 'Gala FIE 2026'),
          _detailRow('Monto', '\$5.00'),
          _detailRow('Método', 'Transferencia bancaria'),
          _detailRow('Referencia', '#TRF-20260614-0931'),
          _detailRow('Enviado', '14 Jun 2026, 10:32', isLast: true),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _timelineItem('Comprobante enviado', '14 Jun 2026, 10:32', true),
          _timelineItem('En revisión por administrador', '14 Jun 2026, 11:00', true),
          _timelineItem('Pago aprobado', '14 Jun 2026, 14:15', true),
          _timelineItem('QR generado y disponible', '14 Jun 2026, 14:16', true, isLast: true),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title, style: const TextStyle(color: AppColors.sentryNavy, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _detailRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.sentryGrey, fontSize: 14)),
          Text(value, style: const TextStyle(color: AppColors.sentryNavy, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _timelineItem(String title, String subtitle, bool isDone, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(Icons.check_circle, color: isDone ? const Color(0xFF00897B) : AppColors.sentryGrey, size: 20),
            if (!isLast)
              Container(width: 2, height: 30, color: isDone ? const Color(0xFF00897B) : AppColors.sentryGrey.withOpacity(0.3)),
          ],
        ),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: AppColors.sentryNavy, fontWeight: isDone ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
            Text(subtitle, style: const TextStyle(color: AppColors.sentryGrey, fontSize: 12)),
            const SizedBox(height: 15),
          ],
        ),
      ],
    );
  }
}