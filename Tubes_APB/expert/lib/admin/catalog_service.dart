import 'package:flutter/material.dart';
import 'dashboard_admin.dart';
import '../data/firestore_database_service.dart';
import '../data/models.dart';

class CatalogServicePage extends StatefulWidget {
  const CatalogServicePage({super.key});

  @override
  State<CatalogServicePage> createState() => _CatalogServicePageState();
}

class ServiceFormResult {
  final ServiceModel service;
  final List<int> branchIds;

  ServiceFormResult({
    required this.service,
    required this.branchIds,
  });
}

class _CatalogServicePageState extends State<CatalogServicePage> {
  final TextEditingController searchController = TextEditingController();
  final FirestoreDatabaseService _db = FirestoreDatabaseService();
  List<ServiceModel> allServices = [];
  String query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    final services = await _db.getAllServices();
    if (mounted) {
      setState(() {
        allServices = services;
        _loading = false;
      });
    }
  }

  List<ServiceModel> get filteredServices {
    if (query.trim().isEmpty) return allServices;
    return allServices
        .where((item) => item.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<void> openAddForm() async {
    final result = await Navigator.push<ServiceFormResult>(
      context,
      MaterialPageRoute(builder: (_) => const ServiceFormPage()),
    );
    if (result != null) {
      final serviceId = await _db.insertService(result.service);
      await _db.setServiceBranches(serviceId, result.branchIds);
      _loadServices();
    }
  }

  Future<void> openEditForm(ServiceModel item) async {
    final result = await Navigator.push<ServiceFormResult>(
      context,
      MaterialPageRoute(builder: (_) => ServiceFormPage(service: item)),
    );
    if (result != null) {
      await _db.updateService(result.service);
      if (result.service.id != null) {
        await _db.setServiceBranches(result.service.id!, result.branchIds);
      }
      _loadServices();
    }
  }

  Future<void> deleteService(ServiceModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Layanan'),
        content: Text('Yakin ingin menghapus ${item.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF7F7F)),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true && item.id != null) {
      await _db.deleteService(item.id!);
      _loadServices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = filteredServices;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            CustomHeader(
              title: 'Layanan',
              showBack: true,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: services.isEmpty ? 4 : services.length + 3,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: searchController,
                                  onChanged: (value) =>
                                      setState(() => query = value),
                                  decoration: InputDecoration(
                                    hintText: 'Cari layanan...',
                                    filled: true,
                                    fillColor: AppColors.card,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: AppColors.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: AppColors.primary),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 52,
                                child: FilledButton(
                                  onPressed: openAddForm,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: const Text('+ Tambah'),
                                ),
                              ),
                            ],
                          );
                        }

                        if (index == 1) return const SizedBox(height: 14);

                        if (index == 2) {
                          return Text(
                            '${services.length} Layanan',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF7C7C88)),
                          );
                        }

                        if (services.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 54),
                              child: Text(
                                'Belum ada layanan.\nTap "+ Tambah" untuk menambahkan.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }

                        final item = services[index - 3];
                        return Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: _ServiceCard(
                            item: item,
                            onEdit: () => openEditForm(item),
                            onDelete: () => deleteService(item),
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICE FORM PAGE — Add / Edit
// ═══════════════════════════════════════════════════════════════════════════════

class ServiceFormPage extends StatefulWidget {
  final ServiceModel? service;
  const ServiceFormPage({super.key, this.service});

  @override
  State<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends State<ServiceFormPage> {
  final FirestoreDatabaseService _db = FirestoreDatabaseService();
  late final TextEditingController nameController;
  late final TextEditingController priceController;
  late final TextEditingController unitController;
  late final TextEditingController descriptionController;
  final TextEditingController optionController = TextEditingController();

  late bool isActive;
  late List<String> options;
  List<BranchModel> branches = [];
  Set<int> selectedBranchIds = {};
  bool loadingBranches = true;

  bool get isEdit => widget.service != null;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.service?.name ?? '');
    priceController =
        TextEditingController(text: widget.service?.price.toString() ?? '');
    unitController = TextEditingController(text: widget.service?.unit ?? '');
    descriptionController =
        TextEditingController(text: widget.service?.description ?? '');
    isActive = widget.service?.isActive ?? true;
    options = List<String>.from(widget.service?.optionsList ?? []);
    _loadBranches();
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    unitController.dispose();
    descriptionController.dispose();
    optionController.dispose();
    super.dispose();
  }

  void addOption() {
    final value = optionController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      options.add(value);
      optionController.clear();
    });
  }

  Future<void> _loadBranches() async {
    final data = await _db.getAllBranches();
    final assignedBranchIds = isEdit && widget.service?.id != null
        ? await _db.getBranchIdsForService(widget.service!.id!)
        : data
            .where((branch) => branch.isOpen && branch.id != null)
            .map((branch) => branch.id!)
            .toList();

    if (!mounted) return;
    setState(() {
      branches = data;
      selectedBranchIds = assignedBranchIds.toSet();
      loadingBranches = false;
    });
  }

  void saveForm() {
    if (nameController.text.trim().isEmpty ||
        priceController.text.trim().isEmpty ||
        unitController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Mohon lengkapi data wajib terlebih dahulu.')),
      );
      return;
    }

    if (selectedBranchIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pilih minimal satu cabang untuk layanan ini.')),
      );
      return;
    }

    final item = ServiceModel(
      id: widget.service?.id,
      name: nameController.text.trim(),
      price: int.tryParse(priceController.text.trim()) ?? 0,
      unit: unitController.text.trim(),
      options: options.join(','),
      description: descriptionController.text.trim(),
      isActive: isActive,
      icon: widget.service?.icon ?? 'print_outlined',
      imageUrl: widget.service?.imageUrl ?? '',
    );

    Navigator.pop(
      context,
      ServiceFormResult(
        service: item,
        branchIds: selectedBranchIds.toList(),
      ),
    );
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
                title: isEdit ? 'Edit Layanan' : 'Tambah Layanan',
                showBack: true,
                onBack: () => Navigator.pop(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Nama Layanan*'),
                    _textField(nameController, 'Masukkan nama layanan'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              _label('Harga*'),
                              _textField(priceController, '500',
                                  keyboardType: TextInputType.number),
                            ])),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              _label('Satuan*'),
                              _textField(unitController, 'Lembar'),
                            ])),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _label('Opsi Tambahan'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...options.map((o) => _chip(
                            o, true, () => setState(() => options.remove(o)))),
                        _chip('+ Tambah', false, () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => Padding(
                              padding: EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: 20,
                                  bottom:
                                      MediaQuery.of(context).viewInsets.bottom +
                                          20),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Tambah Opsi',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 16),
                                    _textField(optionController,
                                        'Contoh: BW / Berwarna'),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                        width: double.infinity,
                                        child: FilledButton(
                                          onPressed: () {
                                            addOption();
                                            Navigator.pop(context);
                                          },
                                          style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary),
                                          child: const Text('Simpan Opsi'),
                                        )),
                                  ]),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _label('Deskripsi Layanan'),
                    _textField(
                        descriptionController, 'Masukkan deskripsi layanan',
                        maxLines: 5),
                    const SizedBox(height: 20),
                    _label('Status'),
                    Row(children: [
                      Expanded(
                          child: _statusBtn('Aktif', isActive,
                              () => setState(() => isActive = true))),
                      const SizedBox(width: 14),
                      Expanded(
                          child: _statusBtn('Nonaktif', !isActive,
                              () => setState(() => isActive = false))),
                    ]),
                    const SizedBox(height: 16),
                    _label('Cabang Tersedia*'),
                    _branchSelector(),
                    const SizedBox(height: 28),
                    Row(children: [
                      SizedBox(
                          width: 92,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Batal',
                                style: TextStyle(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w700)),
                          )),
                      const SizedBox(width: 14),
                      Expanded(
                          child: SizedBox(
                              height: 52,
                              child: FilledButton(
                                onPressed: saveForm,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Simpan Layanan',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                              ))),
                    ]),
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
      {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
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

  Widget _chip(String label, bool filled, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF6B87F5) : AppColors.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: filled ? const Color(0xFF6B87F5) : AppColors.border),
        ),
        child: Text(
          filled ? '$label ✕' : label,
          style: TextStyle(
              color: filled ? Colors.white : const Color(0xFF7C7C88),
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _branchSelector() {
    if (loadingBranches) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (branches.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Belum ada cabang. Tambahkan cabang terlebih dahulu.',
          style: TextStyle(color: Color(0xFF7C7C88)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: branches.map((branch) {
          final branchId = branch.id;
          final selected =
              branchId != null && selectedBranchIds.contains(branchId);
          return CheckboxListTile(
            value: selected,
            onChanged: branchId == null
                ? null
                : (value) {
                    setState(() {
                      if (value == true) {
                        selectedBranchIds.add(branchId);
                      } else {
                        selectedBranchIds.remove(branchId);
                      }
                    });
                  },
            title: Text(
              branch.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.text),
            ),
            subtitle: Text(
              branch.address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7C7C88)),
            ),
            activeColor: AppColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          );
        }).toList(),
      ),
    );
  }

  Widget _statusBtn(String label, bool selected, VoidCallback onTap) {
    return SizedBox(
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

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICE CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class _ServiceCard extends StatelessWidget {
  final ServiceModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServiceCard(
      {required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.print_outlined,
                size: 28, color: AppColors.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(item.name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text))),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.isActive
                          ? const Color(0xFFCFF6C7)
                          : const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.isActive ? 'Aktif' : 'Nonaktif',
                      style: TextStyle(
                          color: item.isActive
                              ? const Color(0xFF277A1E)
                              : const Color(0xFF666666),
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('Rp. ${item.price} / ${item.unit}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7C7C88),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                Row(children: [
                  _actionBtn('Edit', const Color(0xFFFFE29C),
                      const Color(0xFF9B6A00), onEdit),
                  const SizedBox(width: 8),
                  _actionBtn('Hapus', const Color(0xFFFFC0C0),
                      const Color(0xFFC62828), onDelete),
                ]),
              ],
            ),
          ),
        ],
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
