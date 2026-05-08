import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class UploadPaymentScreen extends StatefulWidget {
  const UploadPaymentScreen({super.key});

  @override
  State<UploadPaymentScreen> createState() => _UploadPaymentScreenState();
}

class _UploadPaymentScreenState extends State<UploadPaymentScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sentryBg, // Fondo claro
      appBar: AppBar(
        backgroundColor: AppColors.sentryNavy, // Azul oscuro
        elevation: 0,
        title: const Text('Comprobante de Pago',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sube tu comprobante',
                style: TextStyle(color: AppColors.sentryNavy, fontWeight: FontWeight.bold, fontSize: 18)),
            const Text('Adjunta la imagen para validar tu entrada al evento.',
                style: TextStyle(color: AppColors.sentryGrey, fontSize: 14)),

            const SizedBox(height: 25),

            // Tarjeta de Instrucciones
            _buildInstructionsCard(),

            const SizedBox(height: 25),

            // Área de Carga (Dashed Border)
            _buildUploadArea(),

            const SizedBox(height: 25),

            // Notas adicionales
            const Text('Notas adicionales (opcional)',
                style: TextStyle(color: AppColors.sentryNavy, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ej: Transferencia realizada desde Banco Pichincha...',
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: AppColors.sentryGrey.withOpacity(0.3)),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Botón de Envío
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                label: const Text('Enviar comprobante',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sentryBlue, // Azul medio
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sentryNavy.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.sentryNavy.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.sentryNavy),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Instrucciones de pago',
                    style: TextStyle(color: AppColors.sentryNavy, fontWeight: FontWeight.bold)),
                Text('Depósito o transferencia: \$5.00\nBanco: BancoEstado Cta. 1234567890',
                    style: TextStyle(color: AppColors.sentryNavy, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.sentryBlue.withOpacity(0.3),
          style: BorderStyle.solid, // Nota: Para borde punteado real usa el package 'dotted_border'
          width: 2,
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_upload_outlined, size: 50, color: AppColors.sentryCyan),
          const SizedBox(height: 15),
          const Text('Toca para seleccionar archivo',
              style: TextStyle(color: AppColors.sentryNavy, fontWeight: FontWeight.bold)),
          const Text('JPG, PNG o PDF (Máx. 10 MB)',
              style: TextStyle(color: AppColors.sentryGrey, fontSize: 12)),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _uploadOption(Icons.camera_alt, 'Cámara'),
              const SizedBox(width: 10),
              _uploadOption(Icons.photo_library, 'Galería'),
              const SizedBox(width: 10),
              _uploadOption(Icons.description, 'Archivo'),
            ],
          )
        ],
      ),
    );
  }

  Widget _uploadOption(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.sentryBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.sentryBlue),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.sentryNavy)),
        ],
      ),
    );
  }
}