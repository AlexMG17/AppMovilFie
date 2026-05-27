import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/event_service.dart';
import '../services/support_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

class SupportChatScreen extends StatefulWidget {
  final bool isAdmin;
  /// Para el admin: UUID del estudiante dueño de la conversación.
  final String? conversacionUsuarioId;
  /// Para el admin: nombre a mostrar en el AppBar.
  final String? studentName;

  const SupportChatScreen({
    super.key,
    this.isAdmin = false,
    this.conversacionUsuarioId,
    this.studentName,
  });

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<SupportMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;
  late final String _convUserId;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _convUserId = widget.isAdmin
        ? (widget.conversacionUsuarioId ?? '')
        : (SupabaseService.currentUser?.id ?? '');
    _loadMessages();
    _loadUserName();
    _channel = SupportService.subscribeConversation(_convUserId, () {
      if (mounted) _loadMessages(scroll: true);
    });
  }

  Future<void> _loadUserName() async {
    final name = await EventService.getCurrentUserName();
    if (mounted) {
      setState(() =>
          _userName = name ?? SupabaseService.currentUser?.email ?? '');
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool scroll = false}) async {
    if (_convUserId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final msgs = await SupportService.getConversationMessages(_convUserId);
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _loading = false;
    });
    if (scroll || msgs.isNotEmpty) _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending || _convUserId.isEmpty) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await SupportService.sendMessage(
        mensaje: text,
        esAdmin: widget.isAdmin,
        convUserId: _convUserId,
      );
      await _loadMessages(scroll: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.sentryBlue))
                : _messages.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _buildBubble(_messages[i]),
                      ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (widget.isAdmin) {
      final initial = (widget.studentName?.isNotEmpty == true)
          ? widget.studentName![0].toUpperCase()
          : '?';
      return AppBar(
        backgroundColor: AppColors.sentryNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 17.r,
              backgroundColor: AppColors.sentryCyan.withValues(alpha: 0.25),
              child: Text(
                initial,
                style: TextStyle(
                    color: AppColors.sentryCyan,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.sp),
              ),
            ),
            SizedBox(width: 10.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName ?? 'Usuario',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16.sp),
                ),
                Text(
                  'Conversación privada',
                  style: GoogleFonts.outfit(
                      color: AppColors.sentryCyan, fontSize: 11.sp),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => _loadMessages(scroll: true),
          ),
        ],
      );
    }

    // Estudiante: AppBar original con logout
    return AppBar(
      backgroundColor: AppColors.sentryNavy,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18.r,
            backgroundColor: AppColors.sentryCyan,
            child: Icon(Icons.support_agent_rounded,
                color: Colors.white, size: 20.sp),
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Soporte Técnico',
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16.sp),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () => _loadMessages(scroll: true),
        ),
        PopupMenuButton<String>(
          offset: const Offset(0, 44),
          onSelected: (value) async {
            if (value == 'logout') {
              final nav = Navigator.of(context);
              await SupabaseService.signOut();
              nav.pushReplacementNamed('/login');
            }
          },
          child: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.sentryCyan,
              child:
                  Icon(Icons.person_rounded, color: Colors.white, size: 18),
            ),
          ),
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.black87),
                  ),
                  Text(
                    SupabaseService.currentUser?.email ?? '',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Cerrar sesión',
                      style: TextStyle(color: Colors.red, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 56, color: AppColors.sentryGrey),
            const SizedBox(height: 12),
            Text(
              'Sin mensajes aún',
              style: GoogleFonts.outfit(
                  color: AppColors.sentryGrey, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isAdmin
                  ? 'El usuario aún no ha enviado mensajes.'
                  : 'Escribe tu consulta y te responderemos pronto.',
              style: GoogleFonts.outfit(
                  color: AppColors.sentryGrey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildBubble(SupportMessage msg) {
    // Admin: sus mensajes (es_admin=true) van a la derecha.
    // Estudiante: sus propios mensajes (usuarioId == convUserId) van a la derecha.
    final isMe =
        widget.isAdmin ? msg.esAdmin : (msg.usuarioId == _convUserId);
    final isAdminMsg = msg.esAdmin;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                isAdminMsg
                    ? '${msg.nombreUsuario} (Admin)'
                    : msg.nombreUsuario,
                style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: isAdminMsg
                        ? AppColors.sentryCyan
                        : AppColors.sentryGrey),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe)
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isAdminMsg
                      ? AppColors.sentryCyan.withValues(alpha: 0.2)
                      : AppColors.sentryBg,
                  child: Icon(
                    isAdminMsg
                        ? Icons.support_agent_rounded
                        : Icons.person_rounded,
                    size: 16,
                    color: isAdminMsg
                        ? AppColors.sentryCyan
                        : AppColors.sentryGrey,
                  ),
                ),
              if (!isMe) const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.sentryBlue : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.mensaje,
                    style: GoogleFonts.outfit(
                      fontSize: 14.sp,
                      color: isMe ? Colors.white : AppColors.sentryNavy,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Text(
              _formatTime(msg.createdAt),
              style: GoogleFonts.outfit(
                  fontSize: 10, color: AppColors.sentryGrey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() => Container(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Escribe tu mensaje...',
                  hintStyle: GoogleFonts.outfit(
                      color: AppColors.sentryGrey, fontSize: 14.sp),
                  filled: true,
                  fillColor: AppColors.sentryBg,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w, vertical: 12.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.r),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: GoogleFonts.outfit(fontSize: 14.sp),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 46.w,
                height: 46.w,
                decoration: const BoxDecoration(
                  color: AppColors.sentryBlue,
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      );

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
