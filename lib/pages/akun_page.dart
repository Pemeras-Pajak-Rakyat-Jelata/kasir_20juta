import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AkunPage extends StatefulWidget {
  const AkunPage({super.key});

  @override
  State<AkunPage> createState() => _AkunPageState();
}

class _AkunPageState extends State<AkunPage> {
  Map<String, dynamic>? _profil;
  XFile? _pickedImage;
  final _formKey = GlobalKey<FormState>();
  final bool _uploadingImage = false;
  bool _loading = true;
  bool _isAdmin = false;
  bool _editMode = false;
  bool _saving = false;

  final _namaCtrl = TextEditingController();
  final _telpCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getProfil(),
        SupabaseService.isAdmin(),
      ]);
      if (mounted) {
        final p = results[0] as Map<String, dynamic>?;
        final admin = results[1] as bool;
        setState(() {
          _profil = p;
          _isAdmin = admin;
          _loading = false;
        });
        if (p != null) {
          _namaCtrl.text = p['nama'] ?? '';
          _telpCtrl.text = p['telepon'] ?? '';
          _alamatCtrl.text = p['alamat'] ?? '';
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  Future<void> _pickImage() async {
  final picker = ImagePicker();

  final image = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 70,
  );

  if (image == null) return;

  setState(() {
    _pickedImage = image;
  });

  _showSnack('Gambar dipilih');
}

  Future<void> _simpan() async {
    final valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      _showSnack('Periksa nomor telepon', isError: true);
      return;
    }

    setState(() => _saving = true);

    try {
      await SupabaseService.updateProfil({
        'nama': _namaCtrl.text.trim(),
        'telepon': _telpCtrl.text.trim(),
        'alamat': _alamatCtrl.text.trim(),
      });

      await _load();

      if (mounted) {
        setState(() => _editMode = false);
        _showSnack('Profil berhasil diperbarui');
      }
    } catch (e) {
      _showSnack('Gagal: $e', isError: true);
    }

    if (mounted) {
      setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final konfirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: const Text('Yakin ingin keluar dari akun?',
            style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(fontFamily: 'Poppins'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.merahError),
            child: const Text('Keluar', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
    if (konfirm == true) await SupabaseService.signOut();
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: isError ? AppTheme.merahError : AppTheme.hijauEmerald,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    return Scaffold(
      backgroundColor: AppTheme.kremGelap,
      appBar: AppBar(
        title: const Text('Akun'),
        backgroundColor: AppTheme.hijauEmerald,
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _editMode
                  ? () => setState(() => _editMode = false)
                  : () => setState(() => _editMode = true),
              child: Text(
                _editMode ? 'Batal' : 'Edit',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.hijauEmerald))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── Profile Header ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.hijauEmerald, Color(0xFF0D4A33)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        Opacity(
                          opacity: 0.07,
                          child: CustomPaint(
                            size: const Size(double.infinity, 100),
                            painter: IslamicPatternPainter(color: AppTheme.emas),
                          ),
                        ),
                        Column(
                          children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.emasTerang,
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: _pickedImage != null
                                    ? kIsWeb
                                        ? Image.network(
                                            _pickedImage!.path,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.file(
                                            File(_pickedImage!.path),
                                            fit: BoxFit.cover,
                                          )
                                    : const Icon(
                                        Icons.person_rounded,
                                        color: Colors.white,
                                        size: 44,
                                      ),
                              ),
                            ),
                          ),
                            const SizedBox(height: 12),
                            Text(
                              _profil?['nama'] ?? 'Pengguna',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Badge admin
                            if (_isAdmin)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.emas.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppTheme.emasTerang.withOpacity(0.6)),
                                ),
                                child: const Text(
                                  '👑 Admin',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.emasTerang,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              user?.email ?? '',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: AppTheme.emasTerang,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Info / Form Profil ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Informasi Profil',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.hitamLembut)),
                        const SizedBox(height: 16),
                        if (_editMode) ...[
                            Form(
                            key: _formKey,
                            child: Column(
                              children: [
                          _editField(_namaCtrl, 'Nama Lengkap', Icons.person_outline),
                          const SizedBox(height: 12),
                          _editField(
                          _telpCtrl,
                          'Nomor Telepon',
                          Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          maxLength: 13,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                          final value = v?.trim() ?? '';

                          if (value.isEmpty) {
                            return 'Nomor telepon wajib diisi';
                          }

                          if (value.length < 10) {
                            return 'Minimal 10 digit';
                          }

                          if (value.length > 13) {
                            return 'Maksimal 13 digit';
                          }

                          return null;
                        },
                        ),
                              
                          const SizedBox(height: 12),
                          _editField(_alamatCtrl, 'Alamat', Icons.location_on_outlined,
                              maxLines: 2),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _simpan,
                              child: _saving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2.5))
                                  : const Text('Simpan Perubahan',
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15)),
                            ),
                          ),
                          ],
                          ),
                        ),
                        ] else ...[
                          _infoRow(Icons.person_outline, 'Nama',
                              _profil?['nama'] ?? '-'),
                          _infoRow(Icons.email_outlined, 'Email',
                              user?.email ?? '-'),
                          _infoRow(Icons.phone_outlined, 'Telepon',
                              _profil?['telepon'] ?? '-'),
                          _infoRow(Icons.location_on_outlined, 'Alamat',
                              _profil?['alamat'] ?? '-'),
                        
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Kelola User (Admin Only) ──
                  if (_isAdmin) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppTheme.emas.withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.emas.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.manage_accounts_rounded,
                                    color: AppTheme.coklat, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text('Kelola User',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.hitamLembut)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: () => _showFormBuatUser(),
                              icon: const Icon(Icons.person_add_rounded, size: 18),
                              label: const Text('Buat Akun User Baru',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.emas,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: () => _showDaftarUser(),
                              icon: const Icon(Icons.people_outline_rounded,
                                  size: 18, color: AppTheme.coklat),
                              label: const Text('Lihat Daftar User',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppTheme.coklat)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: AppTheme.emas.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Logout ──
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AppTheme.merahError,
                      ),
                      label: const Text(
                        'Keluar',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          color: AppTheme.merahError,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppTheme.merahError,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),
                  const SizedBox(height: 8),
                  Text(
                    'Kasir Barokah · بَارَكَ اللهُ',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: AppTheme.abuAbu.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ── Form Buat User Baru ──
  void _showFormBuatUser() {
    final _formKey = GlobalKey<FormState>();
    final namaCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool saving = false;
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Buat Akun User Baru',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.hitamLembut)),
              const SizedBox(height: 4),
              const Text('User yang dibuat tidak bisa mengakses halaman ini',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppTheme.abuAbu)),
              const SizedBox(height: 20),
              TextFormField(
                controller: namaCtrl,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: Icon(Icons.person_outline,
                      color: AppTheme.hijauEmerald, size: 20),
                ),
                validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Nama wajib diisi';
                }
                return null;
              },
              ),
              const SizedBox(height: 12),
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: AppTheme.hijauEmerald,
                  size: 20,
                ),
              ),
              validator: (v) {
                final value = v?.trim() ?? '';

                if (value.isEmpty) {
                  return 'Email wajib diisi';
                }

                final emailRegex = RegExp(
                  r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                );

                if (!emailRegex.hasMatch(value)) {
                  return 'Format email tidak valid';
                }

                return null;
              },
            ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passCtrl,
                obscureText: obscure,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline,
                      color: AppTheme.hijauEmerald, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppTheme.abuAbu,
                      size: 20,
                    ),
                    onPressed: () => setStateModal(() => obscure = !obscure),
                  ),
                ),
                validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Password wajib diisi';
                }
                if (v.length < 6) {
                  return 'Minimal 6 karakter';
                }
                return null;
              },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (namaCtrl.text.trim().isEmpty ||
                              emailCtrl.text.trim().isEmpty ||
                              passCtrl.text.isEmpty) {
                            _showSnack('Semua field wajib diisi', isError: true);
                            return;
                          }
                          if (passCtrl.text.length < 6) {
                            _showSnack('Password minimal 6 karakter', isError: true);
                            return;
                          }
                          setStateModal(() => saving = true);
                          try {
                            await SupabaseService.buatUser(
                              emailCtrl.text.trim(),
                              passCtrl.text,
                              namaCtrl.text.trim(),
                            );
                            if (mounted) {
                              Navigator.pop(ctx);
                              _showSnack(
                                  'Akun untuk ${namaCtrl.text.trim()} berhasil dibuat');
                            }
                          } catch (e) {
                            _showSnack('Gagal: $e', isError: true);
                            setStateModal(() => saving = false);
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Buat Akun',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // ── Daftar User ──
  void _showDaftarUser() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Daftar User',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.hitamLembut)),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: SupabaseService.getDaftarUser(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.hijauEmerald));
                  }
                  final users = snap.data ?? [];
                  if (users.isEmpty) {
                    return const Center(
                      child: Text('Belum ada user',
                          style: TextStyle(
                              fontFamily: 'Poppins', color: AppTheme.abuAbu)),
                    );
                  }
                  return ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final u = users[i];
                      final isCurrentUser =
                          u['id'] == SupabaseService.currentUser?.id;
                      final isAdminUser = u['is_admin'] == true;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.kremGelap,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isCurrentUser
                                  ? AppTheme.hijauEmerald.withOpacity(0.4)
                                  : const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isAdminUser
                                    ? AppTheme.emas.withOpacity(0.15)
                                    : AppTheme.hijauEmerald.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isAdminUser
                                    ? Icons.shield_rounded
                                    : Icons.person_rounded,
                                color: isAdminUser
                                    ? AppTheme.coklat
                                    : AppTheme.hijauEmerald,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        u['nama'] ?? '-',
                                        style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: AppTheme.hitamLembut),
                                      ),
                                      if (isCurrentUser) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.hijauEmerald
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text('Kamu',
                                              style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 10,
                                                  color: AppTheme.hijauEmerald,
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    isAdminUser ? 'Admin' : 'User',
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        color: AppTheme.abuAbu),
                                  ),
                                ],
                              ),
                            ),
                            // Tombol hapus — tidak bisa hapus diri sendiri atau admin lain
                            if (!isCurrentUser && !isAdminUser)
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppTheme.merahError, size: 20),
                                onPressed: () async {
                                  final konfirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      title: const Text('Hapus User',
                                          style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w700)),
                                      content: Text(
                                          'Hapus akun "${u['nama']}"?',
                                          style: const TextStyle(
                                              fontFamily: 'Poppins')),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Batal')),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.merahError),
                                          child: const Text('Hapus'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (konfirm == true) {
                                    try {
                                      await SupabaseService.hapusUser(u['id']);
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      _showSnack('User berhasil dihapus');
                                    } catch (e) {
                                      _showSnack('Gagal hapus: $e',
                                          isError: true);
                                    }
                                  }
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      maxLength: maxLength,
      inputFormatters: inputFormatters, 
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.hijauEmerald, size: 20),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.hijauEmerald, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppTheme.abuAbu)),
                Text(value,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.hitamLembut)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}