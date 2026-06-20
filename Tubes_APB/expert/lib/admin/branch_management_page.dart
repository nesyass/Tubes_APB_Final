import 'package:flutter/material.dart';
import 'dashboard_admin.dart';
import '../data/firestore_database_service.dart';
import '../data/models.dart';
import '../data/time_utils.dart';

class BranchManagementPage extends StatefulWidget {
  const BranchManagementPage({super.key});

  @override
  State<BranchManagementPage> createState() => _BranchManagementPageState();
}

class _BranchManagementPageState extends State<BranchManagementPage> {
  final FirestoreDatabaseService _db = FirestoreDatabaseService();
  final TextEditingController _searchController = TextEditingController();
  List<BranchModel> branches = [];
  String _searchQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final data = await _db.getAllBranches();
    if (mounted) {
      setState(() {
        branches = data;
        _loading = false;
      });
    }
  }

  List<BranchModel> get filteredBranches {
    if (_searchQuery.trim().isEmpty) return branches;
    return branches
        .where((b) => b.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Future<void> _openBranchForm({BranchModel? branch}) async {
    final result = await Navigator.push<BranchModel>(
      context,
      MaterialPageRoute(builder: (_) => BranchFormPage(branch: branch)),
    );
    if (result != null) {
      if (branch != null) {
        await _db.updateBranch(result);
      } else {
        await _db.insertBranch(result);
      }
      _loadBranches();
    }
  }

  Future<void> _deleteBranch(BranchModel branch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Cabang'),
        content: Text('Yakin ingin menghapus ${branch.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF7F7F)),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true && branch.id != null) {
      await _db.deleteBranch(branch.id!);
      _loadBranches();
    }
  }

  Future<void> _setBranchMode(BranchModel branch, String mode) async {
    final updated = BranchModel(
      id: branch.id,
      name: branch.name,
      address: branch.address,
      latitude: branch.latitude,
      longitude: branch.longitude,
      isOpen: branch.isOpen,
      openHours: branch.openHours,
      operationalMode: mode,
      rating: branch.rating,
    );
    await _db.updateBranch(updated);
    await _loadBranches();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            CustomHeader(
                title: 'Cabang',
                showBack: true,
                onBack: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Cari cabang...',
                        filled: true,
                        fillColor: AppColors.card,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.primary)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: () => _openBranchForm(),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('+ Tambah'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${filteredBranches.length} Cabang Tersedia',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredBranches.isEmpty
                      ? const Center(
                          child: Text(
                              'Belum ada cabang.\nTap "+ Tambah" untuk menambahkan.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          itemCount: filteredBranches.length,
                          itemBuilder: (context, index) {
                            final branch = filteredBranches[index];
                            final modeLabel = BranchOperationalMode.label(
                                branch.operationalMode);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                        color: AppColors.primarySoft,
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    child: const Icon(Icons.store,
                                        size: 24, color: AppColors.text),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Expanded(
                                              child: Text(branch.name,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 15))),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: branch.isOpen
                                                  ? const Color(0xFFCFF6C7)
                                                  : const Color(0xFFFFE4EE),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              branch.isOpen ? 'Buka' : 'Tutup',
                                              style: TextStyle(
                                                  color: branch.isOpen
                                                      ? const Color(0xFF277A1E)
                                                      : const Color(0xFFC0144A),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ]),
                                        const SizedBox(height: 4),
                                        Text(branch.address,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                        const SizedBox(height: 2),
                                        Text('Jam: ${branch.openHours}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey)),
                                        Text(modeLabel,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey)),
                                        const SizedBox(height: 10),
                                        Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _actionBtn(
                                                  'Auto',
                                                  const Color(0xFFE8EDFF),
                                                  AppColors.primary,
                                                  () => _setBranchMode(
                                                      branch,
                                                      BranchOperationalMode
                                                          .automatic)),
                                              _actionBtn(
                                                  'Buka',
                                                  const Color(0xFFCFF6C7),
                                                  const Color(0xFF277A1E),
                                                  () => _setBranchMode(
                                                      branch,
                                                      BranchOperationalMode
                                                          .manualOpen)),
                                              _actionBtn(
                                                  'Tutup',
                                                  const Color(0xFFFFE4EE),
                                                  const Color(0xFFC0144A),
                                                  () => _setBranchMode(
                                                      branch,
                                                      BranchOperationalMode
                                                          .manualClosed)),
                                              _actionBtn(
                                                  'Edit',
                                                  const Color(0xFFFFE29C),
                                                  const Color(0xFF9B6A00),
                                                  () => _openBranchForm(
                                                      branch: branch)),
                                              _actionBtn(
                                                  'Hapus',
                                                  const Color(0xFFFFC0C0),
                                                  const Color(0xFFC62828),
                                                  () => _deleteBranch(branch)),
                                            ]),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String label, Color bg, Color fg, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w700, color: fg, fontSize: 12)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BRANCH FORM PAGE — Add / Edit
// ═══════════════════════════════════════════════════════════════════════════════

class BranchFormPage extends StatefulWidget {
  final BranchModel? branch;
  const BranchFormPage({super.key, this.branch});

  @override
  State<BranchFormPage> createState() => _BranchFormPageState();
}

class _BranchFormPageState extends State<BranchFormPage> {
  late final TextEditingController nameController;
  late final TextEditingController addressController;
  late final TextEditingController latController;
  late final TextEditingController lngController;
  late final TextEditingController openHoursController;
  late String operationalMode;

  bool get isEdit => widget.branch != null;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.branch?.name ?? '');
    addressController =
        TextEditingController(text: widget.branch?.address ?? '');
    latController =
        TextEditingController(text: widget.branch?.latitude.toString() ?? '');
    lngController =
        TextEditingController(text: widget.branch?.longitude.toString() ?? '');
    openHoursController = TextEditingController(
        text: widget.branch?.openHours ?? '08.00 – 20.00');
    operationalMode =
        BranchOperationalMode.normalize(widget.branch?.operationalMode);
  }

  void _save() {
    if (nameController.text.trim().isEmpty ||
        addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan alamat wajib diisi.')),
      );
      return;
    }

    final normalizedOpenHours =
        BranchSchedule.normalizeOpenHours(openHoursController.text.trim());
    if (BranchSchedule.parse(normalizedOpenHours) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format jam operasional tidak valid.')),
      );
      return;
    }

    final branch = BranchModel(
      id: widget.branch?.id,
      name: nameController.text.trim(),
      address: addressController.text.trim(),
      latitude: double.tryParse(latController.text.trim()) ?? 0.0,
      longitude: double.tryParse(lngController.text.trim()) ?? 0.0,
      isOpen: BranchSchedule.effectiveIsOpen(
        openHours: normalizedOpenHours,
        operationalMode: operationalMode,
        fallbackIsOpen: true,
      ),
      openHours: normalizedOpenHours,
      operationalMode: operationalMode,
    );

    Navigator.pop(context, branch);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              CustomHeader(
                  title: isEdit ? 'Edit Cabang' : 'Tambah Cabang',
                  showBack: true,
                  onBack: () => Navigator.pop(context)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Nama Cabang*'),
                    _textField(nameController, 'Cabang Utama - Dago'),
                    const SizedBox(height: 16),
                    _label('Alamat*'),
                    _textField(
                        addressController, 'Jl. Ir. H. Juanda No. 12, Bandung'),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            _label('Latitude'),
                            _textField(latController, '-6.8915',
                                keyboardType: TextInputType.number),
                          ])),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            _label('Longitude'),
                            _textField(lngController, '107.6107',
                                keyboardType: TextInputType.number),
                          ])),
                    ]),
                    const SizedBox(height: 16),
                    _label('Jam Buka - Tutup'),
                    _textField(openHoursController, '08.00 – 20.00'),
                    const SizedBox(height: 20),
                    _label('Status'),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      _statusBtn(
                        'Otomatis',
                        operationalMode == BranchOperationalMode.automatic,
                        () => setState(() =>
                            operationalMode = BranchOperationalMode.automatic),
                      ),
                      _statusBtn(
                        'Buka Manual',
                        operationalMode == BranchOperationalMode.manualOpen,
                        () => setState(() =>
                            operationalMode = BranchOperationalMode.manualOpen),
                      ),
                      _statusBtn(
                        'Tutup Manual',
                        operationalMode == BranchOperationalMode.manualClosed,
                        () => setState(() => operationalMode =
                            BranchOperationalMode.manualClosed),
                      ),
                    ]),
                    const SizedBox(height: 28),
                    SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _save,
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: Text(
                              isEdit ? 'Simpan Perubahan' : 'Tambah Cabang',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.text, fontWeight: FontWeight.w600)),
      );

  Widget _textField(TextEditingController controller, String hint,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }

  Widget _statusBtn(String label, bool selected, VoidCallback onTap) {
    return SizedBox(
      width: 150,
      height: 52,
      child: selected
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)))
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.text, fontWeight: FontWeight.w700))),
    );
  }
}
