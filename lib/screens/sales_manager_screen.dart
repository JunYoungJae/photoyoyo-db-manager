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

  String _status = 'DB 연결 대기 중';
  bool _isLoading = false;

  bool get _allSelected =>
      _sales.isNotEmpty &&
      _sales.every((sale) => _selectedIds.contains(sale.id));

  // DB 파일 선택
  Future<void> _selectDbFile() async {
    if (_db.isConnected || _isLoading) return;

    try {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.any,
        dialogTitle: 'ObjectBox data.mdb 파일 선택',
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final selectedPath = result.files.single.path;

      if (selectedPath == null || selectedPath.isEmpty) {
        throw Exception('선택한 파일의 경로를 확인할 수 없습니다.');
      }

      final file = File(selectedPath);

      if (file.uri.pathSegments.last != 'data.mdb') {
        throw Exception('data.mdb 파일을 선택해 주세요.');
      }

      if (!await file.exists()) {
        throw Exception('선택한 DB 파일이 존재하지 않습니다.');
      }

      if (!mounted) return;

      setState(() {
        _pathController.text = file.parent.path;
        _sales = [];
        _selectedIds.clear();
        _status = 'DB 파일 선택 완료: ${file.parent.path}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '파일 선택 오류: $e');
    }
  }

  // DB 연결
  void _connect() {
    if (_db.isConnected || _isLoading) return;

    final directory = _pathController.text.trim();

    if (directory.isEmpty) {
      setState(() => _status = 'DB 파일을 먼저 선택해 주세요.');
      return;
    }

    final dbFile = File('$directory${Platform.pathSeparator}data.mdb');

    if (!dbFile.existsSync()) {
      setState(() => _status = '선택한 폴더에 data.mdb 파일이 없습니다.');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'DB 연결 중...';
    });

    try {
      _db.openDatabase(directory);
      final sales = _db.getSales();

      if (!mounted) return;

      setState(() {
        _sales = sales;
        _selectedIds.clear();
        _status = 'DB 연결 성공 - 총 ${sales.length}건';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'DB 연결 오류: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 새로고침
  void _refresh() {
    if (!_db.isConnected || _isLoading) return;

    try {
      final sales = _db.getSales();

      setState(() {
        _sales = sales;
        _selectedIds.clear();
        _status = '조회 완료 - 총 ${sales.length}건';
      });
    } catch (e) {
      setState(() => _status = '조회 오류: $e');
    }
  }

  // 연결 해제
  void _disconnect() {
    if (_isLoading) return;

    try {
      _db.closeDatabase();

      setState(() {
        _sales = [];
        _selectedIds.clear();
        _status = 'DB 연결 해제 완료';
      });
    } catch (e) {
      setState(() => _status = '연결 해제 오류: $e');
    }
  }

  // 전체 선택 / 전체 해제
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

  // 개별 선택
  void _toggleSale(int id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  // DB 폴더 백업
  // 반드시 ObjectBox 연결을 닫은 상태에서 호출
  Future<String> _backupDatabase(String directory) async {
    final source = Directory(directory);

    if (!await source.exists()) {
      throw Exception('DB 폴더가 존재하지 않습니다.');
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
      throw Exception('백업 파일 data.mdb를 확인할 수 없습니다.');
    }

    if (await backupDb.length() == 0) {
      throw Exception('백업 DB 파일 크기가 0입니다.');
    }

    return backupPath;
  }

  // 선택 Sale 일괄 삭제
  Future<void> _deleteSelectedSales() async {
    if (!_db.isConnected || _isLoading || _selectedIds.isEmpty) {
      return;
    }

    final selectedCount = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Sale 및 Payment 삭제 확인'),
            content: Text(
              '선택한 $selectedCount건의 Sale을 삭제하시겠습니까?\n\n'
              '각 Sale 레코드에 포함된 Payment JSON도 함께 삭제됩니다.\n\n'
              '삭제 전에 DB 폴더를 자동으로 백업합니다.\n'
              '삭제 후 원본 DB에서는 복구할 수 없습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.delete_forever),
                label: const Text('삭제 확인'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    final directory = _pathController.text.trim();
    final ids = _selectedIds.toList();

    setState(() {
      _isLoading = true;
      _status = 'DB 백업 준비 중...';
    });

    String? backupPath;
    bool deletionStarted = false;

    try {
      // DB를 닫아 일관된 상태에서 백업
      _db.closeDatabase();

      if (!mounted) return;
      setState(() => _status = 'DB 백업 중...');

      backupPath = await _backupDatabase(directory);

      // 백업 성공 후 다시 연결
      if (!mounted) return;
      setState(() => _status = 'DB 재연결 중...');

      _db.openDatabase(directory);

      // 선택한 ObjectBox ID를 기준으로 일괄 삭제
      if (!mounted) return;
      setState(() {
        _status = '${ids.length}건의 Sale 및 Payment 삭제 중...';
      });

      deletionStarted = true;
      final deletedCount = _db.deleteSales(ids);

      final remainingSales = _db.getSales();

      if (!mounted) return;

      setState(() {
        _sales = remainingSales;
        _selectedIds.clear();
        _status =
            '삭제 완료: $deletedCount건\n'
            '남은 Sale: ${remainingSales.length}건\n'
            '백업 위치: $backupPath';
      });
    } catch (e) {
      // 실패 시 재연결 시도
      if (!_db.isConnected) {
        try {
          _db.openDatabase(directory);
        } catch (_) {
          // 원래 오류를 유지
        }
      }

      if (!mounted) return;

      setState(() {
        _status =
            '${deletionStarted ? "삭제 처리 오류" : "백업/연결 오류"}: $e\n'
            '${backupPath == null ? "백업 미완료" : "백업 위치: $backupPath"}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // JSON 상세보기
  void _showDetails(SaleInfoDto sale) {
    String content = sale.data;

    try {
      final decoded = jsonDecode(sale.data);
      content = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      // JSON이 아니면 원본 표시
    }

    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('판매정보: ${sale.saleNo}'),
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
                child: const Text('닫기'),
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
              'ObjectBox 판매정보 관리',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'data.mdb 파일을 선택하여 Sale 및 Payment를 관리합니다.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // DB 경로와 연결 버튼
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'ObjectBox DB 폴더 경로',
                      hintText: 'DB 파일을 선택하세요',
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
                  label: const Text('DB 파일 선택'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _db.isConnected || _isLoading ? null : _connect,
                  icon: const Icon(Icons.storage),
                  label: const Text('DB 연결'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _db.isConnected && !_isLoading ? _refresh : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('새로고침'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed:
                      _db.isConnected && !_isLoading ? _disconnect : null,
                  icon: const Icon(Icons.link_off),
                  label: const Text('연결 해제'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 연결 상태
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

            // 판매 목록 제목
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '판매정보 목록',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '총 ${_sales.length}건',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 전체 선택 및 일괄 삭제
            Row(
              children: [
                Checkbox(
                  value: _allSelected,
                  onChanged:
                      _sales.isEmpty || _isLoading
                          ? null
                          : (value) => _toggleSelectAll(value ?? false),
                ),
                const Text('전체 선택'),
                const SizedBox(width: 16),
                Text(
                  '${_selectedIds.length}건 선택',
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
                  label: Text('선택 삭제 (${_selectedIds.length}건)'),
                ),
              ],
            ),

            const Divider(),

            // 판매정보 목록
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _sales.isEmpty
                      ? const Center(
                        child: Text(
                          '조회된 판매정보가 없습니다.',
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
                                '판매번호: ${sale.saleNo}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'ObjectBox ID: ${sale.id}'
                                '  |  매장 ID: ${sale.saleId}',
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
