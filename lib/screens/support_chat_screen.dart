import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
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
  bool _uploadingFile = false;
  PlatformFile? _selectedFile;
  RealtimeChannel? _channel;
  late final String _convUserId;
  String _userName = '';

  static const _storageBucket = 'comprobantes';

  // ── Parsear mensaje: si es adjunto devuelve el mapa, si no null ────────────
  static Map<String, dynamic>? _parseAttachment(String mensaje) {
    if (!mensaje.startsWith('{')) return null;
    try {
      final map = jsonDecode(mensaje) as Map<String, dynamic>;
      if (map['_sentry_attachment'] == true) return map;
    } catch (_) {}
    return null;
  }

  // ── Seleccionar archivo sin enviar automáticamente ─────────────────────────
  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() {
      _selectedFile = file;
    });
  }

  // ── Construir vista previa del adjunto seleccionado ────────────────────────
  Widget _buildAttachmentPreview() {
    if (_selectedFile == null) return const SizedBox.shrink();

    final ext = _selectedFile!.extension?.toLowerCase() ?? '';
    final isImage = ['jpg', 'jpeg', 'png'].contains(ext);

    return Container(
      margin: EdgeInsets.only(bottom: 8.h, left: 4.w, right: 4.w),
      padding: EdgeInsets.all(8.r),
      decoration: BoxDecoration(
        color: AppColors.sentryBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.sentryGrey.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: AppColors.sentryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: isImage && _selectedFile!.path != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.file(
                      File(_selectedFile!.path!),
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(
                    Icons.insert_drive_file_rounded,
                    color: AppColors.sentryBlue,
                    size: 20,
                  ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedFile!.name,
                  style: GoogleFonts.outfit(
                    color: AppColors.sentryNavy,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB · Listo para enviar',
                  style: GoogleFonts.outfit(
                    color: AppColors.success,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _selectedFile = null),
            child: const Icon(
              Icons.close_rounded,
              color: AppColors.sentryGrey,
              size: 20,
            ),
          ),
          SizedBox(width: 4.w),
        ],
      ),
    );
  }

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
    if ((text.isEmpty && _selectedFile == null) || _sending || _convUserId.isEmpty) return;

    setState(() => _sending = true);

    try {
      // 1. Si hay un archivo seleccionado, subirlo y enviarlo primero
      if (_selectedFile != null) {
        setState(() => _uploadingFile = true);
        final file = _selectedFile!;
        final bytes = await File(file.path!).readAsBytes();
        final ext = file.extension?.toLowerCase() ?? 'bin';
        final mime = (ext == 'pdf') ? 'application/pdf' : 'image/$ext';
        final isImage = mime.startsWith('image/');
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storagePath = 'soporte/$_convUserId/${timestamp}_${file.name}';

        await SupabaseService.client.storage
            .from(_storageBucket)
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(contentType: mime, upsert: false),
            );

        final url = SupabaseService.client.storage
            .from(_storageBucket)
            .getPublicUrl(storagePath);

        final attachmentMsg = jsonEncode({
          '_sentry_attachment': true,
          'url': url,
          'name': file.name,
          'mime': mime,
          'is_image': isImage,
        });

        await SupportService.sendMessage(
          mensaje: attachmentMsg,
          esAdmin: widget.isAdmin,
          convUserId: _convUserId,
        );

        setState(() {
          _selectedFile = null;
          _uploadingFile = false;
        });
      }

      // 2. Si hay texto, enviarlo después
      if (text.isNotEmpty) {
        _msgCtrl.clear();
        await SupportService.sendMessage(
          mensaje: text,
          esAdmin: widget.isAdmin,
          convUserId: _convUserId,
        );
      }

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
      if (mounted) {
        setState(() {
          _sending = false;
          _uploadingFile = false;
        });
      }
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

    // Estudiante: AppBar con botón de regreso + logout
    return AppBar(
      backgroundColor: AppColors.sentryNavy,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: Navigator.canPop(context)
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.pop(context),
            )
          : null,
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
    final isMe =
        widget.isAdmin ? msg.esAdmin : (msg.usuarioId == _convUserId);
    final isAdminMsg = msg.esAdmin;
    final attachment = _parseAttachment(msg.mensaje);

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
                child: attachment != null
                    ? _buildAttachmentBubble(attachment, isMe)
                    : Container(
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
                            color:
                                isMe ? Colors.white : AppColors.sentryNavy,
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

  Widget _buildAttachmentBubble(Map<String, dynamic> att, bool isMe) {
    final url = att['url'] as String? ?? '';
    final name = att['name'] as String? ?? 'Archivo';
    final isImage = att['is_image'] == true;

    final bubbleColor = isMe ? AppColors.sentryBlue : Colors.white;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );

    if (isImage) {
      return ClipRRect(
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 220.w, maxHeight: 200.h),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : Container(
                    width: 220.w,
                    height: 120.h,
                    color: AppColors.sentryBg,
                    child: const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.sentryBlue, strokeWidth: 2),
                    ),
                  ),
            errorBuilder: (_, _, _) => _fileFallback(name, isMe, radius, bubbleColor),
          ),
        ),
      );
    }

    return _fileFallback(name, isMe, radius, bubbleColor);
  }

  Widget _fileFallback(
      String name, bool isMe, BorderRadius radius, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: radius,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_rounded,
              color: isMe ? Colors.white70 : AppColors.sentryBlue, size: 22.sp),
          SizedBox(width: 8.w),
          Flexible(
            child: Text(
              name,
              style: GoogleFonts.outfit(
                  fontSize: 13.sp,
                  color: isMe ? Colors.white : AppColors.sentryNavy,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() => Container(
        padding: EdgeInsets.fromLTRB(8.w, 10.h, 12.w, 16.h),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAttachmentPreview(),
            Row(
              children: [
                // Botón adjunto
                GestureDetector(
                  onTap: (_sending || _uploadingFile) ? null : _pickFile,
                  child: Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: AppColors.sentryBg,
                      shape: BoxShape.circle,
                    ),
                    child: _uploadingFile
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                color: AppColors.sentryBlue, strokeWidth: 2),
                          )
                        : Icon(Icons.attach_file_rounded,
                            color: AppColors.sentryGrey, size: 20.sp),
                  ),
                ),
                SizedBox(width: 6.w),
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
                SizedBox(width: 8.w),
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
          ],
        ),
      );

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
