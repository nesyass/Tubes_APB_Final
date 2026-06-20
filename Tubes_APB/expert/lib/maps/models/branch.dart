class Branch {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final bool isOpen;
  final String openHours;
  final List<BranchService> services;

  Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.isOpen,
    required this.openHours,
    required this.services,
  });

  // Nanti data ini bisa diganti dari API backend temenmu
  static List<Branch> dummyData() {
    return [
      Branch(
        id: '1',
        name: 'Cab. Utama – Dago',
        address: 'Jl. Ir. H. Juanda No. 12, Bandung',
        latitude: -6.8915,
        longitude: 107.6107,
        isOpen: true,
        openHours: '08.00 – 20.00',
        services: [
          BranchService(name: 'Print Dokumen A4', price: 'Rp 500/lembar'),
          BranchService(name: 'Fotokopi', price: 'Rp 300/lembar'),
          BranchService(name: 'Cetak Foto', price: 'Rp 5.000/lembar'),
          BranchService(name: 'Print Spanduk', price: 'Rp 25.000/m²'),
        ],
      ),
      Branch(
        id: '2',
        name: 'Cab. Timur – Antapani',
        address: 'Jl. Antapani Raya No. 5, Bandung',
        latitude: -6.9044,
        longitude: 107.6437,
        isOpen: true,
        openHours: '08.00 – 20.00',
        services: [
          BranchService(name: 'Print Dokumen A4', price: 'Rp 500/lembar'),
          BranchService(name: 'Fotokopi', price: 'Rp 300/lembar'),
          BranchService(name: 'Cetak Foto', price: 'Rp 5.000/lembar'),
        ],
      ),
      Branch(
        id: '3',
        name: 'Cab. Barat – Cimahi',
        address: 'Jl. Cihanjuang No. 99, Cimahi',
        latitude: -6.8828,
        longitude: 107.5424,
        isOpen: false,
        openHours: '08.00 – 20.00',
        services: [
          BranchService(name: 'Print Dokumen A4', price: 'Rp 500/lembar'),
          BranchService(name: 'Fotokopi', price: 'Rp 300/lembar'),
        ],
      ),
    ];
  }
}

class BranchService {
  final String name;
  final String price;

  BranchService({required this.name, required this.price});
}
