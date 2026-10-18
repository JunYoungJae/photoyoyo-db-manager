import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';

import '../models/sale_info_dto.dart';
import '../services/objectbox_service.dart';

class SalesManagerScreen extends StatefulWidget {
  const SalesManagerScreen({super.key});

  @override
  State<SalesManagerScreen> createState() => _SalesManagerScreenState();
}

class _SalesManagerScreenState extends State<SalesManagerScreen> {
  final ObjectBoxService _db = ObjectBoxService();
  final TextEditingController _pathController = TextEditingController();

  List<SaleInfoDto> _sales = [];
  final Set<int> _selectedIds = <int>{};

  String _status = 'Đang chờ kết nối cơ sở dữ liệu';
  bool _isLoading = false;

  bool get _allSelected =>
      _sales.isNotEmpty &&
      _sales.every((sale) => _selectedIds.contains(sale.id));

  // Chọn tệp DB
  Future<void> _selectDbFile() async {
    if (_db.isConnected || _isLoading) return;

    try {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.any,
        dialogTitle: 'Chọn tệp ObjectBox data.mdb',
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final selectedPath = result.files.single.path;

      if (selectedPath == null || selectedPath.isEmpty) {
        throw Exception('Không thể xác định đường dẫn của tệp đã chọn.');
      }

      final file = File(selectedPath);

      if (file.uri.pathSegments.last != 'data.mdb') {
        throw Exception('Vui lòng chọn tệp data.mdb.');
      }

      if (!await file.exists()) {
        throw Exception('Tệp cơ sở dữ liệu đã chọn không tồn tại.');
      }

      if (!mounted) return;

      setState(() {
        _pathController.text = file.parent.path;
        _sales = [];
        _selectedIds.clear();
        _status = 'Đã chọn tệp DB: ${file.parent.path}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Lỗi chọn tệp: $e');
    }
  }

  // Kết nối DB
  void _connect() {
    if (_db.isConnected || _isLoading) return;

    final directory = _pathController.text.trim();

    if (directory.isEmpty) {
      setState(() => _status = 'Vui lòng chọn tệp DB trước.');
      return;
    }

    final dbFile = File('$directory${Platform.pathSeparator}data.mdb');

    if (!dbFile.existsSync()) {
      setState(
        () => _status = 'Không tìm thấy tệp data.mdb trong thư mục đã chọn.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Đang kết nối cơ sở dữ liệu...';
    });

    try {
      _db.openDatabase(directory);
      final sales = _db.getSales();

      if (!mounted) return;

      setState(() {
        _sales = sales;
        _selectedIds.clear();
        _status = 'Kết nối DB thành công - tổng cộng ${sales.length} giao dịch';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Lỗi kết nối DB: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Làm mới
  void _refresh() {
    if (!_db.isConnected || _isLoading) return;

    try {
      final sales = _db.getSales();

      setState(() {
        _sales = sales;
        _selectedIds.clear();
        _status =
            'Tải dữ liệu thành công - tổng cộng ${sales.length} giao dịch';
      });
    } catch (e) {
      setState(() => _status = 'Lỗi tải dữ liệu: $e');
    }
  }

  // Ngắt kết nối
  void _disconnect() {
    if (_isLoading) return;

    try {
      _db.closeDatabase();

      setState(() {
        _sales = [];
        _selectedIds.clear();
        _status = 'Đã ngắt kết nối DB';
      });
    } catch (e) {
      setState(() => _status = 'Lỗi ngắt kết nối: $e');
    }
  }

  // Chọn tất cả / bỏ chọn tất cả
  void _toggleSelectAll(bool selected) {
    setState(() {
      if (selected) {
        _selectedIds
          ..clear()
          ..addAll(_sales.map((sale) => sale.id));
      } else {
        _selectedIds.clear();
      }
    });
  }

  // Chọn từng giao dịch
  void _toggleSale(int id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  // Sao lưu thư mục DB
  // Chỉ gọi sau khi đã đóng kết nối ObjectBox
  Future<String> _backupDatabase(String directory) async {
    final source = Directory(directory);

    if (!await source.exists()) {
      throw Exception('Thư mục DB không tồn tại.');
    }

    final backupPath =
        '${source.absolute.path}_backup_'
        '${DateTime.now().microsecondsSinceEpoch}';

    final backup = Directory(backupPath);
    await backup.create(recursive: true);

    await for (final entity in source.list(recursive: true)) {
      final relativePath = entity.path.substring(source.path.length);

      final targetPath = '$backupPath$relativePath';

      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
      } else if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      }
    }

    final backupDb = File('$backupPath${Platform.pathSeparator}data.mdb');

    if (!await backupDb.exists()) {
      throw Exception('Không tìm thấy tệp data.mdb trong bản sao lưu.');
    }

    if (await backupDb.length() == 0) {
      throw Exception('Tệp DB sao lưu có kích thước bằng 0.');
    }

    return backupPath;
  }

  // Xóa hàng loạt giao dịch đã chọn
  Future<void> _deleteSelectedSales() async {
    if (!_db.isConnected || _isLoading || _selectedIds.isEmpty) {
      return;
    }

    final selectedCount = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Xác nhận xóa giao dịch và thanh toán'),
            content: Text(
              'Bạn có chắc muốn xóa $selectedCount giao dịch đã chọn không?\n\n'
              'Dữ liệu thanh toán (JSON) trong mỗi giao dịch cũng sẽ bị xóa.\n\n'
              'Thư mục DB sẽ được tự động sao lưu trước khi xóa.\n'
              'Không thể khôi phục dữ liệu đã xóa từ DB gốc.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Hủy'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Xác nhận xóa'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    final directory = _pathController.text.trim();
    final ids = _selectedIds.toList();

    setState(() {
      _isLoading = true;
      _status = 'Đang chuẩn bị sao lưu DB...';
    });

    String? backupPath;
    bool deletionStarted = false;

    try {
      // Đóng DB trước khi sao lưu để đảm bảo tính nhất quán
      _db.closeDatabase();

      if (!mounted) return;
      setState(() => _status = 'Đang sao lưu DB...');

      backupPath = await _backupDatabase(directory);

      // Kết nối lại sau khi sao lưu thành công
      if (!mounted) return;
      setState(() => _status = 'Đang kết nối lại DB...');

      _db.openDatabase(directory);

      // Xóa hàng loạt theo ObjectBox ID đã chọn
      if (!mounted) return;
      setState(() {
        _status = 'Đang xóa ${ids.length} giao dịch và dữ liệu thanh toán...';
      });

      deletionStarted = true;
      final deletedCount = _db.deleteSales(ids);

      final remainingSales = _db.getSales();

      if (!mounted) return;

      setState(() {
        _sales = remainingSales;
        _selectedIds.clear();
        _status =
            'Đã xóa: $deletedCount giao dịch\n'
            'Giao dịch còn lại: ${remainingSales.length} giao dịch\n'
            'Vị trí sao lưu: $backupPath';
      });
    } catch (e) {
      // Thử kết nối lại nếu có lỗi
      if (!_db.isConnected) {
        try {
          _db.openDatabase(directory);
        } catch (_) {
          // Giữ nguyên lỗi ban đầu
        }
      }

      if (!mounted) return;

      setState(() {
        _status =
            '${deletionStarted ? "Lỗi khi xóa dữ liệu" : "Lỗi sao lưu/kết nối"}: $e\n'
            '${backupPath == null ? "Sao lưu chưa hoàn tất" : "Vị trí sao lưu: $backupPath"}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Xem chi tiết JSON
  void _showDetails(SaleInfoDto sale) {
    String content = sale.data;

    try {
      final decoded = jsonDecode(sale.data);
      content = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      // Hiển thị dữ liệu gốc nếu không phải JSON
    }

    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('Thông tin giao dịch: ${sale.saleNo}'),
            content: SizedBox(
              width: 750,
              height: 500,
              child: SingleChildScrollView(
                child: SelectableText(
                  content,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Đóng'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _db.closeDatabase();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo YoYo DB Manager'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quản lý giao dịch ObjectBox',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chọn tệp data.mdb để quản lý giao dịch và thanh toán.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Đường dẫn DB và các nút kết nối
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Đường dẫn thư mục ObjectBox DB',
                      hintText: 'Vui lòng chọn tệp DB',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.folder),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed:
                      _db.isConnected || _isLoading ? null : _selectDbFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Chọn tệp DB'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _db.isConnected || _isLoading ? null : _connect,
                  icon: const Icon(Icons.storage),
                  label: const Text('Kết nối DB'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _db.isConnected && !_isLoading ? _refresh : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Làm mới'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed:
                      _db.isConnected && !_isLoading ? _disconnect : null,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Ngắt kết nối'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Trạng thái kết nối
            Row(
              children: [
                Icon(
                  _db.isConnected ? Icons.check_circle : Icons.info_outline,
                  color: _db.isConnected ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(child: SelectableText(_status)),
              ],
            ),
            const SizedBox(height: 20),

            // Tiêu đề danh sách giao dịch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Danh sách giao dịch',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Tổng cộng ${_sales.length} giao dịch',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Chọn tất cả và xóa hàng loạt
            Row(
              children: [
                Checkbox(
                  value: _allSelected,
                  onChanged:
                      _sales.isEmpty || _isLoading
                          ? null
                          : (value) => _toggleSelectAll(value ?? false),
                ),
                const Text('Chọn tất cả'),
                const SizedBox(width: 16),
                Text(
                  'Đã chọn ${_selectedIds.length} giao dịch',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed:
                      _selectedIds.isEmpty || _isLoading
                          ? null
                          : _deleteSelectedSales,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.delete_forever),
                  label: Text('Xóa mục đã chọn (${_selectedIds.length})'),
                ),
              ],
            ),

            const Divider(),

            // Danh sách giao dịch
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _sales.isEmpty
                      ? const Center(
                        child: Text(
                          'Không có giao dịch nào để hiển thị.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _sales.length,
                        itemBuilder: (context, index) {
                          final sale = _sales[index];

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Checkbox(
                                value: _selectedIds.contains(sale.id),
                                onChanged:
                                    _isLoading
                                        ? null
                                        : (value) => _toggleSale(
                                          sale.id,
                                          value ?? false,
                                        ),
                              ),
                              title: Text(
                                'Mã giao dịch: ${sale.saleNo}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'ObjectBox ID: ${sale.id}'
                                '  |  ID cửa hàng: ${sale.saleId}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showDetails(sale),
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
