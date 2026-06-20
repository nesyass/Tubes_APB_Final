import 'models.dart';

const String bookletImageUrl =
    'https://images.pexels.com/photos/4271624/pexels-photo-4271624.jpeg?auto=compress&cs=tinysrgb&w=640&h=480&fit=crop';
const String posterImageUrl =
    'https://images.pexels.com/photos/3747314/pexels-photo-3747314.jpeg?auto=compress&cs=tinysrgb&w=640&h=480&fit=crop';
const String idCardImageUrl =
    'https://images.pexels.com/photos/8554436/pexels-photo-8554436.jpeg?auto=compress&cs=tinysrgb&w=640&h=480&fit=crop';
const String blackWhitePrintImageUrl =
    'https://images.pexels.com/photos/37394506/pexels-photo-37394506.jpeg?auto=compress&cs=tinysrgb&w=640&h=480&fit=crop';
const String colorPrintImageUrl =
    'https://images.pexels.com/photos/9550363/pexels-photo-9550363.jpeg?auto=compress&cs=tinysrgb&w=640&h=480&fit=crop';
const String bannerImageUrl =
    'https://images.pexels.com/photos/12883028/pexels-photo-12883028.jpeg?auto=compress&cs=tinysrgb&w=640&h=480&fit=crop';
const String defaultPrintImageUrl =
    'https://images.pexels.com/photos/11833899/pexels-photo-11833899.jpeg?auto=compress&cs=tinysrgb&w=640&h=480&fit=crop';

String productImageUrlFor(ServiceModel service) {
  final explicitUrl = service.imageUrl.trim();
  if (explicitUrl.isNotEmpty) return explicitUrl;

  final name = service.name.toLowerCase();
  final description = service.description.toLowerCase();
  final combined = '$name $description';

  if (combined.contains('booklet') || combined.contains('majalah')) {
    return bookletImageUrl;
  }
  if (combined.contains('poster')) return posterImageUrl;
  if (combined.contains('id card') || combined.contains('pvc')) {
    return idCardImageUrl;
  }
  if (combined.contains('hitam putih') || combined.contains('black')) {
    return blackWhitePrintImageUrl;
  }
  if (combined.contains('warna') || combined.contains('color')) {
    return colorPrintImageUrl;
  }
  if (combined.contains('banner') || combined.contains('spanduk')) {
    return bannerImageUrl;
  }

  return defaultPrintImageUrl;
}
