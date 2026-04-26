import 'package:permission_handler/permission_handler.dart';

Future<bool> requestAudioPermission() async {
  final status = await Permission.audio.request();
  return status.isGranted;
}
