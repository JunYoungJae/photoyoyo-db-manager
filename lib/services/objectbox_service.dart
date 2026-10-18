import '../models/sale_info_dto.dart';
import '../objectbox.g.dart';

class ObjectBoxService {
  Store? _store;

  bool get isConnected => _store != null;

  void openDatabase(String directory) {
    if (_store != null) {
      throw StateError('Database is already connected.');
    }

    _store = Store(getObjectBoxModel(), directory: directory);
  }

  List<SaleInfoDto> getSales() {
    final store = _store;

    if (store == null) {
      throw StateError('Database is not connected.');
    }

    return store.box<SaleInfoDto>().getAll();
  }

  int deleteSales(List<int> ids) {
    if (!isConnected) {
      throw StateError('DB가 연결되지 않았습니다.');
    }

    if (ids.isEmpty) return 0;

    final box = _store!.box<SaleInfoDto>();

    return _store!.runInTransaction(TxMode.write, () => box.removeMany(ids));
  }

  void closeDatabase() {
    _store?.close();
    _store = null;
  }
}
