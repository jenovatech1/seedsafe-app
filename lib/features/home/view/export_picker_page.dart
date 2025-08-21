import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/security/security_service.dart';
import '../../../shared/utils/qr_payload_codec.dart';
import '../../../shared/feature_flags.dart';

import '../../home/models/seed_phrase_model.dart';
import '../../home/models/secure_note_model.dart';
import '../../home/models/password_item_model.dart';
import '../../home/view/qr_export_page.dart';

class ExportPickerPage extends StatefulWidget {
  const ExportPickerPage({super.key});

  @override
  State<ExportPickerPage> createState() => _ExportPickerPageState();
}

class _ExportPickerPageState extends State<ExportPickerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // data terdekripsi (ditarik onInit)
  List<Map<String, String?>> _phrases = [];
  List<Map<String, String?>> _notes = [];
  List<Map<String, String?>> _passwords = [];

  // seleksi
  final Set<int> _selP = {};
  final Set<int> _selN = {};
  final Set<int> _selW = {};

  int _skippedP = 0;
  int _skippedN = 0;
  int _skippedW = 0;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
      _skippedP = _skippedN = _skippedW = 0;
    });

    try {
      final s = sl<SecurityService>();

      final phraseBox = Hive.box<SeedPhrase>('seed_phrase_box');
      final noteBox = Hive.box<SecureNote>('note_box');
      final pwBox = Hive.box<PasswordItem>('password_box');

      final List<Map<String, String?>> phrases = [];
      for (final p in phraseBox.values) {
        try {
          final plain = await s.decrypt(p.encryptedPhrase);
          phrases.add({'label': p.label, 'phrase': plain});
        } catch (e) {
          _skippedP++;
          debugPrint('[Export] Skip phrase "${p.label}": $e');
        }
      }

      final List<Map<String, String?>> notes = [];
      for (final n in noteBox.values) {
        try {
          final plain = await s.decrypt(n.encryptedNote);
          notes.add({'label': n.label, 'note': plain});
        } catch (e) {
          _skippedN++;
          debugPrint('[Export] Skip note "${n.label}": $e');
        }
      }

      final List<Map<String, String?>> passwords = [];
      for (final w in pwBox.values) {
        try {
          final plain = await s.decrypt(w.encryptedPassword);
          passwords.add({
            'label': w.label,
            'username': w.username,
            'password': plain,
          });
        } catch (e) {
          _skippedW++;
          debugPrint('[Export] Skip password "${w.label}": $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _phrases = phrases;
        _notes = notes;
        _passwords = passwords;

        _selP
          ..clear()
          ..addAll(List.generate(_phrases.length, (i) => i));
        _selN
          ..clear()
          ..addAll(List.generate(_notes.length, (i) => i));
        _selW
          ..clear()
          ..addAll(List.generate(_passwords.length, (i) => i));

        _loading = false;

        if (_phrases.isEmpty &&
            _notes.isEmpty &&
            _passwords.isEmpty &&
            (_skippedP + _skippedN + _skippedW) > 0) {
          _error =
              'Tidak bisa memuat data. Semua item gagal didekripsi.\n'
              'Kemungkinan vault/key berbeda atau data korup.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load data: $e';
        _loading = false;
      });
    }
  }

  int get _totalSelected => _selP.length + _selN.length + _selW.length;

  Future<String> _buildWrappedExport() async {
    final payload = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'phrases': _selP.map((i) => _phrases[i]).toList(),
      'notes': _selN.map((i) => _notes[i]).toList(),
      'passwords': _selW.map((i) => _passwords[i]).toList(),
    };
    final s = sl<SecurityService>();
    final jsonString = jsonEncode(payload);
    final cipher = await s.encryptForExport(jsonString);
    return QrPayloadCodec.encode(cipher); // SSV1|...
  }

  Future<void> _exportNow() async {
    if (_totalSelected == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item.')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);

    try {
      final wrapped = await _buildWrappedExport();
      if (!mounted) return;

      if (!QrPayloadCodec.fitsSingleQr(wrapped)) {
        // Terlalu besar untuk satu QR → tawarkan file (kalau Pro)
        await showDialog<void>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('QR too large'),
            content: Text(
              'This selection needs ${wrapped.length} characters.\n'
              'Safe single-QR limit is ${FeatureGate.maxQrChars}.\n\n'
              '${FeatureGate.canExportFile ? 'You can export as a file instead.' : 'Please deselect some items and try again.'}',
            ),
            actions: [
              if (FeatureGate.canExportFile)
                TextButton(
                  onPressed: () async {
                    Navigator.of(d).pop();
                    if (!mounted) return;
                    await _showExportFileOptions(wrapped);
                  },
                  child: const Text('Export as File (.ssv)'),
                ),
              TextButton(
                onPressed: () => Navigator.of(d).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Muat → QR
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => QrExportPage(encryptedData: wrapped)),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _saveToDevice(String fileName, String wrapped) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final safeName = fileName.endsWith('.ssv') ? fileName : '$fileName.ssv';
      final bytes = Uint8List.fromList(utf8.encode(wrapped));

      // SAF: user pilih lokasi (Downloads / Documents, dll)
      final params = SaveFileDialogParams(data: bytes, fileName: safeName);
      final savedPath = await FlutterFileDialog.saveFile(params: params);

      if (!mounted) return;
      if (savedPath == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Save canceled.')));
      } else {
        messenger.showSnackBar(SnackBar(content: Text('Saved: $savedPath')));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _shareFile(String fileName, String wrapped) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await getTemporaryDirectory();
      final safeName = fileName.endsWith('.ssv') ? fileName : '$fileName.ssv';
      final f = File('${dir.path}/$safeName');
      await f.writeAsString(wrapped);
      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          text: 'SeedSafe export file (.ssv). Keep this file secure.',
          files: [XFile(f.path, mimeType: 'text/plain')],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  /// Satu UI untuk pilih aksi: Share atau Save to device
  Future<void> _showExportFileOptions(String wrapped) async {
    final fname = 'seedsafe-${DateTime.now().millisecondsSinceEpoch}.ssv';
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share…'),
              subtitle: const Text('Send via WhatsApp, Email, Drive, etc.'),
              onTap: () async {
                Navigator.of(context).pop();
                await _shareFile(fname, wrapped);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Save to device…'),
              subtitle: const Text('Downloads / Documents'),
              onTap: () async {
                Navigator.of(context).pop();
                await _saveToDevice(fname, wrapped);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar({
    required bool allSelected,
    required VoidCallback onSelectAll,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        TextButton.icon(
          onPressed: onSelectAll,
          icon: const Icon(Icons.done_all),
          label: const Text('Select All'),
        ),
        const SizedBox(width: 6),
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.clear),
          label: const Text('Clear'),
        ),
        const Spacer(),
        Text(
          'Selected: $_totalSelected',
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : (_error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    if ((_skippedP + _skippedN + _skippedW) > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Material(
                          color: Colors.orange.withAlpha((0.12 * 255).round()),
                          borderRadius: BorderRadius.circular(8),
                          child: ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -2),
                            leading: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                            ),
                            title: const Text(
                              'Beberapa item dilewati saat memuat',
                              style: TextStyle(color: Colors.orange),
                            ),
                            subtitle: Text(
                              '$_skippedP seed • $_skippedN note • $_skippedW password',
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    TabBar(
                      controller: _tab,
                      tabs: const [
                        Tab(text: 'Seeds'),
                        Tab(text: 'Notes'),
                        Tab(text: 'Passwords'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tab,
                        children: [
                          // Seeds
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                _toolbar(
                                  allSelected: _selP.length == _phrases.length,
                                  onSelectAll: () => setState(
                                    () => _selP
                                      ..clear()
                                      ..addAll(
                                        List.generate(
                                          _phrases.length,
                                          (i) => i,
                                        ),
                                      ),
                                  ),
                                  onClear: () => setState(() => _selP.clear()),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _phrases.length,
                                    itemBuilder: (_, i) {
                                      final m = _phrases[i];
                                      return CheckboxListTile(
                                        value: _selP.contains(i),
                                        onChanged: (v) {
                                          setState(() {
                                            if (v == true) {
                                              _selP.add(i);
                                            } else {
                                              _selP.remove(i);
                                            }
                                          });
                                        },
                                        title: Text(m['label'] ?? 'Untitled'),
                                        subtitle: Text(
                                          (m['phrase'] ?? '')
                                              .split(RegExp(r'\s+'))
                                              .take(3)
                                              .join(' '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Notes
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                _toolbar(
                                  allSelected: _selN.length == _notes.length,
                                  onSelectAll: () => setState(
                                    () => _selN
                                      ..clear()
                                      ..addAll(
                                        List.generate(_notes.length, (i) => i),
                                      ),
                                  ),
                                  onClear: () => setState(() => _selN.clear()),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _notes.length,
                                    itemBuilder: (_, i) {
                                      final m = _notes[i];
                                      return CheckboxListTile(
                                        value: _selN.contains(i),
                                        onChanged: (v) {
                                          setState(() {
                                            if (v == true) {
                                              _selN.add(i);
                                            } else {
                                              _selN.remove(i);
                                            }
                                          });
                                        },
                                        title: Text(m['label'] ?? 'Untitled'),
                                        subtitle: Text(
                                          m['note'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Passwords
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                _toolbar(
                                  allSelected:
                                      _selW.length == _passwords.length,
                                  onSelectAll: () => setState(
                                    () => _selW
                                      ..clear()
                                      ..addAll(
                                        List.generate(
                                          _passwords.length,
                                          (i) => i,
                                        ),
                                      ),
                                  ),
                                  onClear: () => setState(() => _selW.clear()),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _passwords.length,
                                    itemBuilder: (_, i) {
                                      final m = _passwords[i];
                                      return CheckboxListTile(
                                        value: _selW.contains(i),
                                        onChanged: (v) {
                                          setState(() {
                                            if (v == true) {
                                              _selW.add(i);
                                            } else {
                                              _selW.remove(i);
                                            }
                                          });
                                        },
                                        title: Text(m['label'] ?? 'Untitled'),
                                        subtitle: Text(
                                          [
                                            if ((m['username'] ?? '')
                                                .isNotEmpty)
                                              (m['username'] ?? ''),
                                            '••••••••',
                                          ].join('  •  '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // QR → selalu ada
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.qr_code_2),
                                label: const Text('Export as QR'),
                                onPressed: _exportNow,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // File → hanya Pro
                            if (FeatureGate.canExportFile)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.insert_drive_file_outlined,
                                  ),
                                  label: const Text('Export as File (.ssv)'),
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    if (_totalSelected == 0) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Select at least one item.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    try {
                                      final wrapped =
                                          await _buildWrappedExport();
                                      if (!mounted) return;
                                      await _showExportFileOptions(wrapped);
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Export to file failed: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ));

    return Scaffold(
      appBar: AppBar(title: const Text('Choose items to export')),
      body: body,
    );
  }
}
