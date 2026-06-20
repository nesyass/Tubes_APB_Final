import 'package:geolocator/geolocator.dart';

enum LocationAccessStatus {
  allowed,
  serviceDisabled,
  denied,
  deniedForever,
}

class LocationAccessResult {
  final LocationAccessStatus status;
  final String message;

  const LocationAccessResult(this.status, this.message);

  bool get canUseLocation => status == LocationAccessStatus.allowed;
  bool get canOpenLocationSettings => status == LocationAccessStatus.serviceDisabled;
  bool get canOpenAppSettings => status == LocationAccessStatus.deniedForever;
}

Future<LocationAccessResult> ensureLocationAccess() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return const LocationAccessResult(
      LocationAccessStatus.serviceDisabled,
      'GPS belum aktif. Aktifkan layanan lokasi perangkat.',
    );
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied) {
    return const LocationAccessResult(
      LocationAccessStatus.denied,
      'Izin lokasi ditolak. Izinkan lokasi agar jarak cabang bisa dihitung.',
    );
  }

  if (permission == LocationPermission.deniedForever) {
    return const LocationAccessResult(
      LocationAccessStatus.deniedForever,
      'Izin lokasi diblokir permanen. Buka pengaturan aplikasi untuk mengaktifkannya.',
    );
  }

  return const LocationAccessResult(
    LocationAccessStatus.allowed,
    'Lokasi aktif.',
  );
}

Future<void> openLocationSettingsFor(LocationAccessResult result) async {
  if (result.canOpenLocationSettings) {
    await Geolocator.openLocationSettings();
    return;
  }

  if (result.canOpenAppSettings) {
    await Geolocator.openAppSettings();
  }
}
