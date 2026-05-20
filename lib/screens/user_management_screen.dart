import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/event_service.dart';
import '../services/supabase_service.dart';
import '../services/user_management_service.dart';
import '../theme/app_colors.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<AppUser> _allUsers = [];
  List<RoleOption> _roles = [];
  List<AppUser> _filtered = [];
  String _search = '';
  String _roleFilter = 'todos';
  bool _loading = true;
  String? _error;
  String _userName = '';

  final _searchController = TextEditingController();
  final _currentEmail = SupabaseService.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await EventService.getCurrentUserName();
    if (mounted) setState(() => _userName = name ?? SupabaseService.currentUser?.email ?? '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        UserManagementService.getAllUsers(),
        UserManagementService.getAllRoles(),
      ]);
      _allUsers = results[0] as List<AppUser>;
      _roles = results[1] as List<RoleOption>;
      _applyFilter();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _search.toLowerCase();
    setState(() {
      _filtered = _allUsers.where((u) {
        final matchesSearch = q.isEmpty ||
            u.nombre.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q);
        final matchesRole = _roleFilter == 'todos' ||
            u.rolNombre == _roleFilter;
        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  void _onSearch(String value) {
    _search = value;
    _applyFilter();
  }

  void _onRoleFilter(String role) {
    _roleFilter = role;
    _applyFilter();
  }

  int _countByRole(String role) =>
      _allUsers.where((u) => u.rolNombre == role).length;

  Future<void> _showChangeRoleDialog(AppUser user) async {
    if (user.email == _currentEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes cambiar tu propio rol.')),
      );
      return;
    }

    RoleOption? selected = _roles.firstWhere(
      (r) => r.id == user.idRol,
      orElse: () => _roles.first,
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangeRoleSheet(
        user: user,
        roles: _roles,
        initialRole: selected,
        onConfirm: (newRole) async {
          try {
            await UserManagementService.updateUserRole(user.id, newRole.id);
            final idx = _allUsers.indexWhere((u) => u.id == user.id);
            if (idx != -1) {
              _allUsers[idx] = user.copyWith(
                idRol: newRole.id,
                rolNombre: newRole.nombre.toLowerCase().trim(),
              );
            }
            _applyFilter();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Rol de ${user.nombre} actualizado a ${newRole.nombre}.',
                  ),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al actualizar: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminCount = _countByRole('admin') + _countByRole('administrador');
    final guardCount = _countByRole('validador');
    final studentCount = _countByRole('estudiante') + _countByRole('externo');

    final filterRoles = [
      ('todos', 'Todos', _allUsers.length),
      ('admin', 'Admin', adminCount),
      ('validador', 'Validador', guardCount),
      ('estudiante', 'Estudiante', studentCount),
      ('externo', 'Externo', _countByRole('externo')),
    ];

    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.sentryBlue,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.sentryBlue),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(
                        'Error al cargar usuarios',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sentryNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: _buildStatsRow(adminCount, guardCount, studentCount),
              ),
              SliverToBoxAdapter(child: _buildSearchBar()),
              SliverToBoxAdapter(
                child: _buildFilterChips(filterRoles),
              ),
              SliverToBoxAdapter(child: _buildColumnHeaders()),
              if (_filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 48,
                            color: AppColors.sentryGrey.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'Sin resultados',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.sentryGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final user = _filtered[i];
                      return _UserRow(
                        user: user,
                        isCurrentUser: user.email == _currentEmail,
                        onEdit: () => _showChangeRoleDialog(user),
                      );
                    },
                    childCount: _filtered.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 100,
      backgroundColor: AppColors.sentryNavy,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestión de Usuarios',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              'Asignación de roles',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          offset: const Offset(0, 44),
          onSelected: (value) async {
            if (value == 'logout') {
              final nav = Navigator.of(context);
              await SupabaseService.signOut();
              nav.pushReplacementNamed('/login');
            }
          },
          child: const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.sentryCyan,
            child: Icon(Icons.person_rounded, color: Colors.white, size: 18),
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
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _load,
          tooltip: 'Recargar',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStatsRow(int admins, int guardias, int estudiantes) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _StatTile(
            label: 'Total',
            value: _allUsers.length,
            color: AppColors.sentryBlue,
          ),
          const SizedBox(width: 10),
          _StatTile(
            label: 'Admins',
            value: admins,
            color: AppColors.sentryNavy,
          ),
          const SizedBox(width: 10),
          _StatTile(
            label: 'Validadores',
            value: guardias,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          _StatTile(
            label: 'Estudiantes',
            value: estudiantes,
            color: AppColors.sentryCyan,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearch,
          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.sentryNavy),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o correo...',
            hintStyle: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.sentryGrey,
            ),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.sentryGrey, size: 20),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded,
                        color: AppColors.sentryGrey, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _onSearch('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(
      List<(String, String, int)> filterRoles) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        itemCount: filterRoles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (key, label, count) = filterRoles[i];
          final selected = _roleFilter == key;
          return GestureDetector(
            onTap: () => _onRoleFilter(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.sentryBlue
                    : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppColors.sentryBlue
                      : AppColors.cardBorder,
                ),
              ),
              child: Text(
                '$label ($count)',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.sentryGrey,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildColumnHeaders() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Usuario',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.sentryGrey,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'Rol',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.sentryGrey,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

// ── User row ──────────────────────────────────────────────────────────────────

class _UserRow extends StatelessWidget {
  final AppUser user;
  final bool isCurrentUser;
  final VoidCallback onEdit;

  const _UserRow({
    required this.user,
    required this.isCurrentUser,
    required this.onEdit,
  });

  Color _avatarColor() {
    const colors = [
      Color(0xFF1565C0),
      Color(0xFF00838F),
      Color(0xFF6A1B9A),
      Color(0xFFAD1457),
      Color(0xFF2E7D32),
      Color(0xFFE65100),
    ];
    return colors[user.nombre.isNotEmpty
        ? user.nombre.codeUnitAt(0) % colors.length
        : 0];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _avatarColor(),
              child: Text(
                user.nombre.isNotEmpty
                    ? user.nombre[0].toUpperCase()
                    : '?',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.nombre,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.sentryNavy,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.sentryCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Tú',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.sentryBlue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    user.email,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.sentryGrey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: Center(child: _RoleChip(rolNombre: user.rolNombre)),
            ),
            IconButton(
              icon: Icon(
                Icons.edit_rounded,
                size: 18,
                color: isCurrentUser
                    ? AppColors.sentryGrey.withValues(alpha: 0.4)
                    : AppColors.sentryBlue,
              ),
              onPressed: isCurrentUser ? null : onEdit,
              tooltip: isCurrentUser ? 'No puedes editar tu propio rol' : 'Cambiar rol',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Role chip ─────────────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  final String rolNombre;

  const _RoleChip({required this.rolNombre});

  _RoleStyle _style() {
    switch (rolNombre) {
      case 'admin':
      case 'administrador':
        return _RoleStyle(
          bg: const Color(0xFFE8EAF6),
          fg: AppColors.sentryNavy,
          label: 'Admin',
          icon: Icons.admin_panel_settings_rounded,
        );
      case 'validador':
        return _RoleStyle(
          bg: const Color(0xFFFFF3E0),
          fg: const Color(0xFFE65100),
          label: 'Validador',
          icon: Icons.security_rounded,
        );
      case 'externo':
        return _RoleStyle(
          bg: const Color(0xFFF3E5F5),
          fg: const Color(0xFF6A1B9A),
          label: 'Externo',
          icon: Icons.person_outline_rounded,
        );
      default:
        return _RoleStyle(
          bg: const Color(0xFFE1F5FE),
          fg: AppColors.sentryBlue,
          label: 'Estudiante',
          icon: Icons.school_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 12, color: s.fg),
          const SizedBox(width: 4),
          Text(
            s.label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: s.fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleStyle {
  final Color bg;
  final Color fg;
  final String label;
  final IconData icon;

  const _RoleStyle({
    required this.bg,
    required this.fg,
    required this.label,
    required this.icon,
  });
}

// ── Stat tile ─────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.sentryGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Change role bottom sheet ───────────────────────────────────────────────────

class _ChangeRoleSheet extends StatefulWidget {
  final AppUser user;
  final List<RoleOption> roles;
  final RoleOption initialRole;
  final Future<void> Function(RoleOption) onConfirm;

  const _ChangeRoleSheet({
    required this.user,
    required this.roles,
    required this.initialRole,
    required this.onConfirm,
  });

  @override
  State<_ChangeRoleSheet> createState() => _ChangeRoleSheetState();
}

class _ChangeRoleSheetState extends State<_ChangeRoleSheet> {
  late RoleOption _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialRole;
  }

  Future<void> _save() async {
    if (_selected.id == widget.user.idRol) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    await widget.onConfirm(_selected);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Cambiar rol',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.sentryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.user.nombre,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.sentryGrey,
            ),
          ),
          Text(
            widget.user.email,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.sentryGrey,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Selecciona un rol',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.sentryNavy,
            ),
          ),
          const SizedBox(height: 12),
          ...widget.roles.map((role) {
            final isSelected = _selected.id == role.id;
            return GestureDetector(
              onTap: () => setState(() => _selected = role),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.sentryBlue.withValues(alpha: 0.07)
                      : AppColors.sentryBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.sentryBlue
                        : AppColors.cardBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    _RoleChip(rolNombre: role.nombre.toLowerCase().trim()),
                    const Spacer(),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.sentryBlue, size: 20),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sentryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Guardar cambios',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
