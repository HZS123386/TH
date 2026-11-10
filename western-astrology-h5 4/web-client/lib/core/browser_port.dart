import 'models.dart';
import 'repository.dart';

abstract interface class BrowserPort implements DeviceStore {
  String today(String zone);
  bool get visible;
  void setLanguage(String language, String title);
  Future<String> exportDocument(LifeReport report, String format);
  void postPayment(String action, Map<String, String> fields);
  void pageReady(String page);
  String? readSetting(String key, {bool session = false});
  void writeSetting(String key, String value, {bool session = false});
  Json visitContext();
}
