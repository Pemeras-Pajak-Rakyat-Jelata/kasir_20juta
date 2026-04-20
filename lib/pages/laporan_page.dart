import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});

  @override
  State<LaporanPage> createState() => LaporanPageState();
}

class LaporanPageState extends State<LaporanPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _transaksiHarian = [];
  Map<String, dynamic> _ringkasanBulan = {};
  bool _loading = false;
  final _fmt = NumberFormat('#,##0', 'id_ID');
  final _fmtTgl = DateFormat('d MMMM yyyy', 'id_ID');
  final _fmtBulan = DateFormat('MMMM yyyy', 'id_ID');


  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _loadHarian();
    _loadBulanan();
  }

  void reload() {
  _loadHarian();
  _loadBulanan();
}

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHarian() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getLaporanHarian(_selectedDate);
      if (mounted) setState(() => _transaksiHarian = data);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadBulanan() async {
    try {
      final data = await SupabaseService.getRingkasanBulan(
          _selectedDate.month, _selectedDate.year);
      if (mounted) setState(() => _ringkasanBulan = data);
    } catch (_) {}
  }
  Future<void> exportCsv() async {
  try {
    final totalBulan = (_ringkasanBulan['total'] ?? 0) as num;
    final totalTransaksi =
        (_ringkasanBulan['jumlah_transaksi'] ?? 0) as num;
    final rataHari =
        (_ringkasanBulan['rata_per_hari'] ?? 0) as num;

    final buffer = StringBuffer();
    buffer.writeln('KASIR BAROKAH');
    buffer.writeln('LAPORAN BULANAN');
    buffer.writeln(
      'Periode;${DateFormat('MMMM yyyy', 'id_ID').format(_selectedDate)}',
    );
    buffer.writeln(
      'Dicetak;${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
    );
    buffer.writeln('');
    buffer.writeln('Keterangan;Nilai');
    buffer.writeln(
      'Total Omzet;Rp ${_fmt.format(totalBulan)}',
    );
    buffer.writeln(
      'Jumlah Transaksi;${_fmt.format(totalTransaksi)}',
    );
    buffer.writeln(
      'Rata-rata per Hari;Rp ${_fmt.format(rataHari)}',
    );

    buffer.writeln('');
    buffer.writeln('Semoga Allah memberkahi usaha ini');
    buffer.writeln('');
    buffer.writeln('Owner,');
    buffer.writeln('');
    buffer.writeln('');
    buffer.writeln('(____________________)');

    final bytes = Uint8List.fromList(
      utf8.encode(buffer.toString()),
    );

    final fileName =
        'Laporan_Bulanan_${DateFormat('yyyy_MM').format(_selectedDate)}.csv';

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType: 'text/csv',
          name: fileName,
        ),
      ],
      text: 'Laporan Bulanan Kasir Barokah',
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export bulanan gagal: $e'),
      ),
    );
  }
}

  Future<void> _pilihTanggal() async {
    final tgl = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.hijauEmerald,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (tgl != null) {
      setState(() => _selectedDate = tgl);
      _loadHarian();
      _loadBulanan();
    }
  }

  void _showExportMenu() {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Export PDF',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),

              ListTile(
                leading: const Icon(Icons.receipt_long,
                    color: AppTheme.hijauEmerald),
                title: const Text(
                  'Laporan Harian',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _exportPdfHarian();
                },
              ),

              ListTile(
                leading: const Icon(Icons.bar_chart,
                    color: AppTheme.emas),
                title: const Text(
                  'Laporan Bulanan',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _exportPdfBulanan();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}


Future<void> _exportPdfHarian() async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.green800,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Kasir Barokah',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Laporan Harian',
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 16),

        pw.Text(
          'Tanggal : ${_fmtTgl.format(_selectedDate)}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),

        pw.SizedBox(height: 10),

        pw.Text('Total Omzet : Rp ${_fmt.format(_totalHarian)}'),
        pw.Text('Jumlah Transaksi : ${_transaksiHarian.length}'),

        pw.SizedBox(height: 20),

        pw.Table.fromTextArray(
          headers: ['ID', 'Jam', 'Metode', 'Total'],
          data: _transaksiHarian.map((t) {
            final waktu =
                DateTime.parse(t['created_at']).toLocal();

            return [
              '${t['id']}',
              DateFormat('HH:mm').format(waktu),
              '${t['metode_bayar'] ?? '-'}',
              'Rp ${_fmt.format(t['total'])}',
            ];
          }).toList(),
        ),
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
  );
}

Future<void> _exportPdfBulanan() async {
  final totalBulan = (_ringkasanBulan['total'] ?? 0) as num;
  final transaksi = (_ringkasanBulan['jumlah_transaksi'] ?? 0) as num;
  final rataHari = (_ringkasanBulan['rata_per_hari'] ?? 0) as num;

  final persen1 = transaksi == 0 ? 0 : 70;
  final persen2 = transaksi == 0 ? 0 : 30;

  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
            color: PdfColors.green800,
            borderRadius: pw.BorderRadius.circular(14),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Kasir Barokah',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Laporan Bulanan',
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 18),

        pw.Text(
          'Periode : ${_fmtBulan.format(_selectedDate)}',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 16,
          ),
        ),

        pw.SizedBox(height: 14),

        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            children: [
              _pdfRow('Total Omzet', 'Rp ${_fmt.format(totalBulan)}'),
              _pdfRow('Jumlah Transaksi', '$transaksi'),
              _pdfRow('Rata-rata / Hari', 'Rp ${_fmt.format(rataHari)}'),
            ],
          ),
        ),

        pw.SizedBox(height: 24),

        pw.Text(
          'Visual Ringkasan',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 15,
          ),
        ),

        pw.SizedBox(height: 12),

        pw.Row(
          children: [
            pw.Container(
              width: 120,
              height: 120,
              child: pw.Stack(
                alignment: pw.Alignment.center,
                children: [
                  pw.CircularProgressIndicator(
                    value: persen1 / 100,
                    strokeWidth: 16,
                    color: PdfColors.green,
                    backgroundColor: PdfColors.orange100,
                  ),
                  pw.Text(
                    '$persen1%',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(width: 20),

            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Hijau : Performa utama'),
                pw.SizedBox(height: 6),
                pw.Text('Sisa : Potensi growth'),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 24),

        pw.Text(
          'Catatan:',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),

        pw.Text(
          'Usaha menunjukkan performa baik pada periode ini. '
          'Tetap jaga kualitas layanan dan stok barang.',
        ),
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
  );
}

pw.Widget _pdfRow(String kiri, String kanan) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(kiri),
        pw.Text(
          kanan,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

  double get _totalHarian =>
      _transaksiHarian.fold(0, (s, t) => s + (t['total'] as num));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kremGelap,
      appBar: AppBar(
        title: const Text('Laporan'),
        backgroundColor: AppTheme.hijauEmerald,
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
          onPressed: _showExportMenu,
        ),
        IconButton(
          onPressed: exportCsv,
          icon: const Icon(Icons.table_view_rounded),
        ),
        IconButton(
          icon: const Icon(Icons.calendar_today_rounded, color: Colors.white),
          onPressed: _pilihTanggal,
        ),
      ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.emasTerang,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 13),
          tabs: const [
            Tab(text: 'Harian'),
            Tab(text: 'Bulanan'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.hijauEmerald))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _HarianTab(
                  tanggal: _selectedDate,
                  transaksi: _transaksiHarian,
                  total: _totalHarian,
                  fmt: _fmt,
                  fmtTgl: _fmtTgl,
                  onRefresh: _loadHarian,
                ),
                _BulananTab(
                  tanggal: _selectedDate,
                  ringkasan: _ringkasanBulan,
                  fmt: _fmt,
                  fmtBulan: _fmtBulan,
                  onRefresh: _loadBulanan,
                ),
              ],
            ),
    );
  }
}

List<BarChartGroupData> _buildBarGroups(
    List<Map<String, dynamic>> transaksi) {
  final Map<int, double> data = {};

  for (var t in transaksi) {
    final waktu =
        DateTime.parse(t['created_at']).toLocal();

    final jam = waktu.hour;

    data[jam] =
        (data[jam] ?? 0) +
        (t['total'] as num).toDouble();
  }

  return data.entries.map((e) {
    return BarChartGroupData(
      x: e.key,
      barRods: [
        BarChartRodData(
          toY: e.value,
          width: 14,
          color: AppTheme.hijauEmerald,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }).toList();
}

class _HarianTab extends StatelessWidget {
  final DateTime tanggal;
  final List<Map<String, dynamic>> transaksi;
  final double total;
  final NumberFormat fmt;
  final DateFormat fmtTgl;
  final VoidCallback onRefresh;

  const _HarianTab({
    required this.tanggal,
    required this.transaksi,
    required this.total,
    required this.fmt,
    required this.fmtTgl,
    required this.onRefresh,
  });

  Map<int, double> get dataPerJam {
    final Map<int, double> hasil = {};

    for (var t in transaksi) {
      final waktu =
          DateTime.parse(t['created_at']).toLocal();

      final jam = waktu.hour;

      hasil[jam] =
          (hasil[jam] ?? 0) +
          (t['total'] as num).toDouble();
    }

    return hasil;
  }

  List<BarChartGroupData> _buildBarGroups() {
    return dataPerJam.entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value,
            width: 14,
            color: AppTheme.hijauEmerald,
            borderRadius:
                BorderRadius.circular(5),
          ),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.hijauEmerald,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Badge tanggal
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme
                          .hijauEmerald
                          .withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(
                              20),
                    ),
                    child: Text(
                      fmtTgl.format(tanggal),
                      style:
                          const TextStyle(
                        fontFamily:
                            'Poppins',
                        fontWeight:
                            FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme
                            .hijauEmerald,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // CARD
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label:
                              'Total Omzet',
                          value:
                              'Rp ${fmt.format(total)}',
                          icon: Icons
                              .payments_rounded,
                          color: AppTheme
                              .hijauEmerald,
                        ),
                      ),
                      const SizedBox(
                          width: 12),
                      Expanded(
                        child: _StatCard(
                          label:
                              'Transaksi',
                          value:
                              '${transaksi.length}x',
                          icon: Icons
                              .receipt_long_rounded,
                          color:
                              AppTheme.emas,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // GRAFIK
                  Container(
                    padding:
                        const EdgeInsets.all(
                            18),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white,
                      borderRadius:
                          BorderRadius
                              .circular(
                                  18),
                      border:
                          Border.all(
                        color: const Color(
                            0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'Statistik Penjualan per Jam',
                          style:
                              TextStyle(
                            fontFamily:
                                'Poppins',
                            fontWeight:
                                FontWeight
                                    .w700,
                            fontSize:
                                14,
                          ),
                        ),

                        const SizedBox(
                            height: 18),

                        SizedBox(
                          height: 250,
                          child:
                              BarChart(
                            BarChartData(
                              alignment:
                                  BarChartAlignment
                                      .spaceAround,
                              borderData:
                                  FlBorderData(
                                      show:
                                          false),
                              gridData:
                                  FlGridData(
                                      show:
                                          true),
                              titlesData:
                                  FlTitlesData(
                                topTitles:
                                    AxisTitles(
                                  sideTitles:
                                      SideTitles(
                                          showTitles:
                                              false),
                                ),
                                rightTitles:
                                    AxisTitles(
                                  sideTitles:
                                      SideTitles(
                                          showTitles:
                                              false),
                                ),
                                leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 42,
                                  interval: total <= 10000
                                      ? 2000
                                      : total <= 50000
                                          ? 10000
                                          : 20000,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0) {
                                      return const Text(
                                        '0',
                                        style: TextStyle(fontSize: 10),
                                      );
                                    }

                                    return Text(
                                      '${(value / 1000).toStringAsFixed(0)}K',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'Poppins',
                                        color: AppTheme.abuAbu,
                                      ),
                                    );
                                  },
                                ),
                              ),
                                bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                    getTitlesWidget:
                                        (value,
                                            meta) {
                                      return Text(
                                        '${value.toInt()}',
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              10,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              barGroups:
                                  _buildBarGroups(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (transaksi.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      Icons
                          .receipt_long_outlined,
                      size: 56,
                      color: AppTheme
                          .abuAbu
                          .withOpacity(
                              0.4),
                    ),
                    const SizedBox(
                        height: 12),
                    const Text(
                      'Tidak ada transaksi pada tanggal ini',
                      style: TextStyle(
                        fontFamily:
                            'Poppins',
                        color: AppTheme
                            .abuAbu,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding:
                  const EdgeInsets.fromLTRB(
                      16, 0, 16, 24),
              sliver: SliverList(
                delegate:
                    SliverChildBuilderDelegate(
                  (ctx, i) {
                    final t =
                        transaksi[i];

                    final waktu =
                        DateTime.parse(
                                t[
                                    'created_at'])
                            .toLocal();

                    final detail =
                        (t['detail_transaksi']
                                as List?) ??
                            [];

                    return Container(
                      margin:
                          const EdgeInsets
                              .only(
                              bottom:
                                  10),
                      decoration:
                          BoxDecoration(
                        color: Colors
                            .white,
                        borderRadius:
                            BorderRadius
                                .circular(
                                    14),
                        border:
                            Border.all(
                          color: const Color(
                              0xFFE5E7EB),
                        ),
                      ),
                      child:
                          ExpansionTile(
                        tilePadding:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              16,
                          vertical:
                              4,
                        ),
                        title: Text(
                          'Transaksi #${t['id']}',
                        ),
                        subtitle: Text(
                          '${DateFormat('HH:mm').format(waktu)} · ${t['metode_bayar'] ?? '-'}',
                        ),
                        trailing:
                            Text(
                          'Rp ${fmt.format(t['total'])}',
                        ),
                        children: detail
                            .map<Widget>(
                                (d) {
                          final nama = d[
                                      'produk']
                                  ?[
                                  'nama'] ??
                              '-';

                          return Padding(
                            padding:
                                const EdgeInsets
                                    .all(
                                        12),
                            child:
                                Row(
                              children: [
                                Expanded(
                                  child:
                                      Text(
                                    '$nama x${d['qty']}',
                                  ),
                                ),
                                Text(
                                  'Rp ${fmt.format(d['subtotal'])}',
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                  childCount:
                      transaksi.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
class _BulananTab extends StatelessWidget {
  final DateTime tanggal;
  final Map<String, dynamic> ringkasan;
  final NumberFormat fmt;
  final DateFormat fmtBulan;
  final VoidCallback onRefresh;

  const _BulananTab({
    required this.tanggal,
    required this.ringkasan,
    required this.fmt,
    required this.fmtBulan,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final totalBulan = (ringkasan['total'] ?? 0) as num;
    final totalTransaksi = (ringkasan['jumlah_transaksi'] ?? 0) as num;
    final rataHari = (ringkasan['rata_per_hari'] ?? 0) as num;

    final tunai = (ringkasan['tunai'] ?? 0) as num;
    final qris = (ringkasan['qris'] ?? 0) as num;
    final transfer = (ringkasan['transfer'] ?? 0) as num;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.hijauEmerald,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppTheme.emas.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                fmtBulan.format(tanggal),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.coklat,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // CARD TOTAL
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppTheme.hijauEmerald,
                  Color(0xFF0D4A33),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Omzet Bulan Ini',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rp ${fmt.format(totalBulan)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Transaksi',
                  value: '${totalTransaksi}x',
                  icon: Icons.receipt_long_rounded,
                  color: AppTheme.emas,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Rata-rata/Hari',
                  value: 'Rp ${fmt.format(rataHari)}',
                  icon: Icons.trending_up,
                  color: AppTheme.birInfo,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // PIE CHART
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Statistik Metode Pembayaran',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 42,
                      sectionsSpace: 3,
                      sections: [
                        PieChartSectionData(
                          value: tunai.toDouble(),
                          color: Colors.green,
                          radius: 55,
                          title: 'Tunai',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        PieChartSectionData(
                          value: qris.toDouble(),
                          color: Colors.blue,
                          radius: 55,
                          title: 'QRIS',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        PieChartSectionData(
                          value: transfer.toDouble(),
                          color: Colors.orange,
                          radius: 55,
                          title: 'Transfer',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                _legend('Tunai', Colors.green, tunai, fmt),
                _legend('QRIS', Colors.blue, qris, fmt),
                _legend('Transfer', Colors.orange, transfer, fmt),
              ],
            ),
          ),

          if (ringkasan.isEmpty) ...[
            const SizedBox(height: 40),
            const Center(
              child: Text(
                'Data belum tersedia',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _legend(
    String title,
    Color color,
    num nominal,
    NumberFormat fmt,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
              ),
            ),
          ),
          Text(
            'Rp ${fmt.format(nominal)}',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
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
                        fontWeight: FontWeight.w700,
                        color: AppTheme.hitamLembut)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}