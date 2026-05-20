import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/support_service.dart';
import '../theme/app_colors.dart';
import 'support_chat_screen.dart';

class AdminSupportListScreen extends StatefulWidget {
  const AdminSupportListScreen({super.key});

  @override
  State<AdminSupportListScreen> createState() => _AdminSupportListScreenState();
}

class _AdminSupportListScreenState extends State<AdminSupportListScreen> {
  List<SupportConversation> _conversations = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = SupportService.subscribeAll(() {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    final convs = await SupportService.getConversationList();
    if (!mounted) return;
    setState(() {
      _conversations = convs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      appBar: AppBar(
        backgroundColor: AppColors.sentryNavy,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.sentryCyan,
              child: Icon(Icons.support_agent_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Soporte',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
                Text(
                  _loading
                      ? 'Cargando...'
                      : '${_conversations.length} conversacion${_conversations.length == 1 ? '' : 'es'}',
                  style: GoogleFonts.outfit(
                      color: AppColors.sentryCyan, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.sentryBlue))
          : _conversations.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.sentryBlue,
                  child: ListView.separated(
                    itemCount: _conversations.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 72, endIndent: 16),
                    itemBuilder: (_, i) => _buildTile(_conversations[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, size: 64, color: AppColors.sentryGrey),
            const SizedBox(height: 12),
            Text(
              'Sin conversaciones',
              style: GoogleFonts.outfit(
                  color: AppColors.sentryGrey,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Aquí aparecerán los mensajes de los usuarios.',
              style: GoogleFonts.outfit(
                  color: AppColors.sentryGrey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildTile(SupportConversation conv) {
    final initial = conv.nombreUsuario.isNotEmpty
        ? conv.nombreUsuario[0].toUpperCase()
        : '?';

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.sentryCyan.withValues(alpha: 0.15),
        child: Text(
          initial,
          style: GoogleFonts.outfit(
              color: AppColors.sentryBlue,
              fontWeight: FontWeight.w700,
              fontSize: 18),
        ),
      ),
      title: Text(
        conv.nombreUsuario,
        style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.sentryNavy),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          conv.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
              fontSize: 13,
              color: conv.lastIsAdmin
                  ? AppColors.sentryGrey
                  : AppColors.sentryNavy.withValues(alpha: 0.75)),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(conv.lastAt),
            style: GoogleFonts.outfit(
                fontSize: 11, color: AppColors.sentryGrey),
          ),
          if (!conv.lastIsAdmin) ...[
            const SizedBox(height: 4),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.sentryCyan,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SupportChatScreen(
            isAdmin: true,
            conversacionUsuarioId: conv.usuarioId,
            studentName: conv.nombreUsuario,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
    if (isToday) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final isThisYear = dt.year == now.year;
    return isThisYear
        ? '${dt.day}/${dt.month}'
        : '${dt.day}/${dt.month}/${dt.year}';
  }
}
