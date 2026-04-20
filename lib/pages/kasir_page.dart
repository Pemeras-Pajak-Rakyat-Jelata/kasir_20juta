import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import 'main_page.dart';

class KasirPage extends StatefulWidget {
  const KasirPage({super.key});

  @override
  State<KasirPage> createState() => KasirPageState();
}

class KasirPageState extends State<KasirPage> {
  List<Map<String, dynamic>> _produk = [];
  List<Map<String, dynamic>> _filtered = [];
  final Map<int, int> _keranjang = {}; // produkId -> qty
  bool _loading = true;
  String _query = '';
  String _metodeBayar = 'Tunai';
  final _fmt = NumberFormat('#,##0', 'id_ID');

  void reload() {
  _loadProduk();
}

  @override
  void initState() {
    super.initState();
    _loadProduk();
  }

  @override
void didChangeDependencies() {
  super.didChangeDependencies();
  _loadProduk();
}

  Future<void> _loadProduk() async {
  setState(() => _loading = true);

  try {
    final data = await SupabaseService.getProduk();

    if (!mounted) return;

    setState(() {
      _produk = data;
      _filter();
      _loading = false;
    });
  } catch (e) {
    if (mounted) {
      setState(() => _loading = false);
    }
  }
}

  void _filter() {
    final q = _query.toLowerCase();
    _filtered = q.isEmpty
        ? List.from(_produk)
        : _produk.where((p) => p['nama'].toLowerCase().contains(q)).toList();
  }

  void _tambahKeranjang(Map<String, dynamic> produk) {
    final id = produk['id'] as int;
    final stok = produk['stok'] as int;
    final sudahAda = _keranjang[id] ?? 0;
    if (sudahAda >= stok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Stok tidak mencukupi',
            style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppTheme.merahError,
        duration: Duration(seconds: 1),
      ));
      return;
    }
    setState(() => _keranjang[id] = sudahAda + 1);
  }

  void _kurangKeranjang(int produkId) {
    final ada = _keranjang[produkId] ?? 0;
    if (ada <= 1) {
      setState(() => _keranjang.remove(produkId));
    } else {
      setState(() => _keranjang[produkId] = ada - 1);
    }
  }

  double get _subtotal {
    double total = 0;
    for (final entry in _keranjang.entries) {
      final produk = _produk.firstWhere((p) => p['id'] == entry.key,
          orElse: () => {});
      if (produk.isNotEmpty) {
        total += (produk['harga'] as num) * entry.value;
      }
    }
    return total;
  }

  int get _totalItem =>
      _keranjang.values.fold(0, (sum, qty) => sum + qty);

  Future<void> _bayar() async {
    if (_keranjang.isEmpty) return;
    final konfirm = await _showKonfirmasiBayar();
    if (konfirm != true) return;

    setState(() => _loading = true);
    try {
      // 1. Simpan transaksi
      final transaksiId = await SupabaseService.tambahTransaksi({
        'total': _subtotal,
        'metode_bayar': _metodeBayar,
        'user_id': SupabaseService.currentUser?.id,
      });

      // 2. Simpan detail
      final details = <Map<String, dynamic>>[];
      for (final entry in _keranjang.entries) {
        final produk =
        _produk.firstWhere((p) => p['id'] == entry.key);
        details.add({
          'transaksi_id': transaksiId,
          'produk_id': entry.key,
          'nama_produk': produk['nama'],
          'qty': entry.value,
          'harga_satuan': produk['harga'],
          'subtotal': (produk['harga'] as num) * entry.value,
        });
      }
      await SupabaseService.tambahDetailTransaksi(details);

      // 3. Update stok (via RPC atau manual)
      for (final entry in _keranjang.entries) {
        try {
          await SupabaseService.updateStokProduk(entry.key, entry.value);
        } catch (_) {
          // fallback: update manual
          final produk = _produk.firstWhere((p) => p['id'] == entry.key);
          final newStok = (produk['stok'] as int) - entry.value;
          await SupabaseService.updateProduk(
              entry.key, {'stok': newStok < 0 ? 0 : newStok});
        }
      }

      setState(() {
        _keranjang.clear();
        _loading = false;
      });
      await _loadProduk();

      if (mounted) {
        dashboardKey.currentState?.reload();
        laporanKey.currentState?.reload();
        _showSukses(transaksiId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menyimpan transaksi: $e'),
          backgroundColor: AppTheme.merahError,
        ));
      }
    }
  }

  Future<bool?> _showKonfirmasiBayar() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Pembayaran',
            style: TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: Rp ${_fmt.format(_subtotal)}',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.hijauEmerald)),
            const SizedBox(height: 6),
            Text('Metode: $_metodeBayar',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
            Text('$_totalItem item',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppTheme.abuAbu)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal',
                  style: TextStyle(fontFamily: 'Poppins'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showSukses(int transaksiId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.hijauEmerald.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.hijauEmerald, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Alhamdulillah!',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.hijauEmerald)),
            const SizedBox(height: 4),
            Text('Transaksi #$transaksiId berhasil disimpan',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppTheme.abuAbu),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Selesai',
                  style: TextStyle(
                      fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kremGelap,
      appBar: AppBar(
        title: const Text('Kasir'),
        backgroundColor: AppTheme.hijauEmerald,
        actions: [
          if (_keranjang.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _keranjang.clear()),
              icon: const Icon(Icons.clear_all, color: Colors.white, size: 20),
              label: const Text('Reset',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 13)),
            ),
        ],
      ),
      body: _loading
          ? const Center(
          child:
          CircularProgressIndicator(color: AppTheme.hijauEmerald))
          : Column(
        children: [
          // ── Search ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() {
                _query = v;
                _filter();
              }),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari produk...',
                hintStyle: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 14),
                prefixIcon:
                const Icon(Icons.search, color: AppTheme.abuAbu),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // ── Produk Grid ──
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                child: Text('Produk tidak ditemukan',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppTheme.abuAbu)))
                : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final p = _filtered[i];
                final id = p['id'] as int;
                final qty = _keranjang[id] ?? 0;
                final stok = p['stok'] as int;
                final habis = stok == 0;
                return GestureDetector(
                  onTap: habis
                      ? null
                      : () => _tambahKeranjang(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: qty > 0
                            ? AppTheme.hijauEmerald
                            : const Color(0xFFE5E7EB),
                        width: qty > 0 ? 2 : 1,
                      ),
                      boxShadow: qty > 0
                          ? [
                        BoxShadow(
                          color: AppTheme.hijauEmerald
                              .withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                          : null,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [

                          // GAMBAR PRODUK
                          Container(
                            height: 70,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.grey.shade100,
                            ),
                            child: p['gambar'] != null && p['gambar'].toString().isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      p['gambar'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image),
                                    ),
                                  )
                                : const Icon(
                                    Icons.image_outlined,
                                    size: 30,
                                    color: Colors.grey,
                                  ),
                          ),

                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  p['nama'],
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: habis
                                      ? AppTheme.abuAbu
                                      : AppTheme.hitamLembut,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (qty > 0)
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppTheme.hijauEmerald,
                                  borderRadius:
                                  BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    '$qty',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Rp ${_fmt.format(p['harga'])}',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: habis
                                    ? AppTheme.abuAbu
                                    : AppTheme.hijauEmerald,
                              ),
                            ),
                            Text(
                              habis ? 'Habis' : 'Stok: $stok',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                color: habis
                                    ? AppTheme.merahError
                                    : AppTheme.abuAbu,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Keranjang Panel ──
          if (_keranjang.isNotEmpty)
  SafeArea(
    top: false,
    child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Items
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      shrinkWrap: true,
                      children: _keranjang.entries.map((entry) {
                        final produk = _produk.firstWhere(
                                (p) => p['id'] == entry.key,
                            orElse: () => {});
                        if (produk.isEmpty) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(produk['nama'],
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                              ),
                              Row(children: [
                                _qtyBtn(
                                  Icons.remove,
                                      () => _kurangKeranjang(entry.key),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: Text('${entry.value}',
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                ),
                                _qtyBtn(
                                  Icons.add,
                                      () => _tambahKeranjang(produk),
                                ),
                              ]),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  'Rp ${_fmt.format((produk['harga'] as num) * entry.value)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: AppTheme.hijauEmerald),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(height: 24),

                  // Metode bayar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: ['Tunai', 'Transfer', 'QRIS']
                          .map((m) => Padding(
                        padding:
                        const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(m,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12)),
                          selected: _metodeBayar == m,
                          selectedColor: AppTheme.hijauEmerald
                              .withOpacity(0.15),
                          onSelected: (_) => setState(
                                  () => _metodeBayar = m),
                        ),
                      ))
                          .toList(),
                    ),
                  ),

                  // Total & Bayar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$_totalItem item',
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color: AppTheme.abuAbu)),
                              Text(
                                'Rp ${_fmt.format(_subtotal)}',
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.hitamLembut),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _bayar,
                          icon: const Icon(Icons.check_circle_outline,
                              size: 20),
                          label: const Text('Bayar',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.kremGelap,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Icon(icon, size: 16, color: AppTheme.hitamLembut),
      ),
    );
  }
}