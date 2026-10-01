import 'dart:convert';
import 'dart:typed_data';

const maxReportPhotoBytes = 1024 * 1024;
const maxLocalPhotoDataCharacters = 3 * 1024 * 1024;

String? detectReportPhotoMimeType(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}

String encodeReportPhoto(Uint8List bytes, String mimeType) =>
    'data:$mimeType;base64,${base64Encode(bytes)}';

Uint8List? decodeReportPhoto(String? data) {
  if (data == null || !data.startsWith('data:image/')) return null;
  final separator = data.indexOf(',');
  if (separator < 0) return null;
  try {
    return base64Decode(data.substring(separator + 1));
  } on FormatException {
    return null;
  }
}
