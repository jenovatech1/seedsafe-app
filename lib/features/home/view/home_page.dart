import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/security/security_service.dart';
import '../../../shared/widgets/password_prompt_dialog.dart';
import '../../../shared/widgets/progress_dialog.dart';
import '../models/seed_phrase_model.dart';
import '../models/secure_note_model.dart';
import '../models/password_item_model.dart';
import '../widgets/add_phrase_sheet.dart';
import '../widgets/add_note_sheet.dart';
import '../widgets/add_password_sheet.dart';
import 'phrase_detail_page.dart';
import 'note_detail_page.dart';
import 'password_detail_page.dart';
import '../../../shared/utils/reauth.dart';
import 'export_picker_page.dart';
import '../../../shared/feature_flags.dart';
import '../../../shared/utils/import_file_flow.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLocking = false;
  bool _biometricEnabled = false;
  bool _isLoading = false;
  bool _authBusy = false;
  String _authMsg = '';
  bool _openingAdd = false;

  void _setAuthBusy(bool v, {String msg = ''}) {
    if (!mounted) return;
    setState(() {
      _authBusy = v;
      _authMsg = msg;
    });
  }

  Future<void> _pumpUI() async {
    await Future.delayed(const Duration(milliseconds: 16));
  }

  @override
  void initState() {
    super.initState();
    _loadBiometricStatus();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _openAddMenu() async {
    if (_openingAdd) return;
    _openingAdd = true;

    final rootCtx = context;
    try {
      final choice = await showModalBottomSheet<String>(
        context: rootCtx,
        useRootNavigator: true,
        useSafeArea: true,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.key),
                title: const Text('Add Seed Phrase'),
                onTap: () => Navigator.of(sheetCtx).pop('seed'),
              ),
              ListTile(
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: const Text('Add Note'),
                onTap: () => Navigator.of(sheetCtx).pop('note'),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Add Password'),
                onTap: () => Navigator.of(sheetCtx).pop('password'),
              ),
            ],
          ),
        ),
      );

      if (choice == null) return;
      if (!rootCtx.mounted) return;

      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!rootCtx.mounted) return;

      switch (choice) {
        case 'seed':
          await showAddPhraseSheet(rootCtx);
          break;
        case 'note':
          await showAddNoteSheet(rootCtx);
          break;
        case 'password':
          await showAddPasswordSheet(rootCtx);
          break;
      }
    } finally {
      _openingAdd = false;
    }
  }

  Future<void> _loadBiometricStatus() async {
    final s = sl<SecurityService>();
    final enabled = await s.isBiometricsEnabled();
    if (!mounted) return;
    setState(() {
      _biometricEnabled = enabled;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleRevealPhrase(SeedPhrase phrase) async {
    final ctx = context;
    setState(() => _isLoading = true);
    try {
      final ok = await ensureUnlocked(ctx, purpose: 'Reveal Seed Phrase');
      if (!ok) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (!ctx.mounted) return;
      showSimulatedProgressDialog(
        ctx,
        title: 'Decrypting',
        subtitle: 'Revealing phrase…',
      );

      final s = sl<SecurityService>();
      final decrypted = await s.decrypt(phrase.encryptedPhrase);

      if (!ctx.mounted) return;
      await closeProgressDialogNow(ctx);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!ctx.mounted) return;
      final res = await Navigator.of(ctx).push(
        MaterialPageRoute(
          builder: (_) => PhraseDetailPage(
            label: phrase.label,
            decryptedPhrase: decrypted,
            phraseKey: phrase.key,
          ),
        ),
      );

      if (!ctx.mounted) return;
      if (res == true) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('Seed phrase deleted')));
      }
    } catch (e) {
      if (mounted) _showError('An error occurred: $e');
    } finally {
      if (ctx.mounted && mounted) {
        forceCloseProgressDialog(ctx);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRevealNote(SecureNote note) async {
    final ctx = context;
    setState(() => _isLoading = true);
    try {
      final ok = await ensureUnlocked(ctx, purpose: 'Reveal Note');
      if (!ok) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (!ctx.mounted) return;
      showSimulatedProgressDialog(
        ctx,
        title: 'Decrypting',
        subtitle: 'Revealing note…',
      );

      final s = sl<SecurityService>();
      final decrypted = await s.decrypt(note.encryptedNote);

      if (!ctx.mounted) return;
      await closeProgressDialogNow(ctx);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!ctx.mounted) return;
      final res = await Navigator.of(ctx).push(
        MaterialPageRoute(
          builder: (_) => NoteDetailPage(
            label: note.label,
            decryptedNote: decrypted,
            noteKey: note.key,
          ),
        ),
      );

      if (!ctx.mounted) return;
      if (res == true) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('Note deleted')));
      }
    } catch (e) {
      if (mounted) _showError('An error occurred: $e');
    } finally {
      if (ctx.mounted && mounted) {
        forceCloseProgressDialog(ctx);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRevealPassword(PasswordItem item) async {
    final ctx = context;
    setState(() => _isLoading = true);
    try {
      final ok = await ensureUnlocked(ctx, purpose: 'Reveal Password');
      if (!ok) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (!ctx.mounted) return;
      showSimulatedProgressDialog(
        ctx,
        title: 'Decrypting',
        subtitle: 'Revealing password…',
      );

      final s = sl<SecurityService>();
      final decrypted = await s.decrypt(item.encryptedPassword);

      if (!ctx.mounted) return;
      await closeProgressDialogNow(ctx);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!ctx.mounted) return;
      final res = await Navigator.of(ctx).push(
        MaterialPageRoute(
          builder: (_) => PasswordDetailPage(
            label: item.label,
            username: item.username,
            decryptedPassword: decrypted,
            itemKey: item.key,
          ),
        ),
      );

      if (!ctx.mounted) return;
      if (res == true) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('Password deleted')));
      }
    } catch (e) {
      if (mounted) _showError('An error occurred: $e');
    } finally {
      if (ctx.mounted && mounted) {
        forceCloseProgressDialog(ctx);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleBiometrics(bool wantEnable) async {
    final messenger = ScaffoldMessenger.of(context); // cache
    final s = sl<SecurityService>();

    try {
      if (wantEnable) {
        final canUse = await s.canUseBiometrics();
        if (!canUse) {
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Biometrics not available on this device.'),
              ),
            );
          }
          await _loadBiometricStatus();
          return;
        }

        // 1) biometric dulu
        var unlocked = await s.unlockWithBiometrics();

        // 2) fallback password
        if (!unlocked) {
          if (!mounted) return;
          final pwd = await showPasswordPromptDialog(
            context: context,
            title: 'Enter Master Password',
          );
          if (pwd == null || pwd.isEmpty) {
            await _loadBiometricStatus();
            return;
          }
          _setAuthBusy(true, msg: 'Verifying password…');
          await _pumpUI();
          unlocked = await s.unlockVault(pwd);
          _setAuthBusy(false);

          if (!unlocked) {
            _showError('Wrong password.');
            await _loadBiometricStatus();
            return;
          }
        }

        // 3) enable biometrics
        _setAuthBusy(true, msg: 'Confirm with biometrics…');
        await _pumpUI();
        await s.enableBiometrics();
        _setAuthBusy(false);

        // 4) sinkronkan switch
        await _loadBiometricStatus();
        if (!mounted) return;
        if (_biometricEnabled) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Biometric unlock enabled.')),
          );
        } else {
          _showError('Failed to enable biometrics or canceled.');
        }
        return;
      }

      // === DISABLE PATH ===
      bool authed = false;
      if (await s.canUseBiometrics()) {
        _setAuthBusy(true, msg: 'Confirm to disable…');
        authed = await s.unlockWithBiometrics();
        _setAuthBusy(false);
      }
      if (!authed) {
        if (!mounted) return;
        final pwd = await showPasswordPromptDialog(
          context: context,
          title: 'Confirm to Disable Biometrics',
        );
        if (pwd != null && pwd.isNotEmpty) {
          _setAuthBusy(true, msg: 'Verifying…');
          authed = await s.unlockVault(pwd);
          _setAuthBusy(false);
        }
      }
      if (!authed) {
        await _loadBiometricStatus();
        return;
      }

      _setAuthBusy(true, msg: 'Removing hardware-backed key…');
      await s.disableBiometrics();
      _setAuthBusy(false);

      await _loadBiometricStatus();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Biometrics disabled.')),
      );
    } catch (e) {
      _setAuthBusy(false);
      await _loadBiometricStatus();
      if (mounted) _showError('Biometric toggle failed: $e');
    }
  }

  void _lockApp() {
    if (_isLocking) return; // guard re-entrancy
    _isLocking = true;

    sl<SecurityService>().lockVault();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/unlock', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SeedSafe'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Seeds'),
              Tab(text: 'Notes'),
              Tab(text: 'Passwords'),
            ],
          ),
        ),
        drawer: Drawer(
          child: SafeArea(
            top: true,
            bottom: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header dengan logo + nama
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const FlutterLogo(size: 36),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'SeedSafe',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.photo_camera_outlined),
                        title: const Text('Import from QR'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/restore');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.file_open),
                        title: const Text('Import from File'),
                        onTap: () => startImportFromFile(context),
                      ),
                      if (FeatureGate.canExportQr)
                        ListTile(
                          leading: const Icon(Icons.qr_code_2_outlined),
                          title: const Text('Export QR Code / File'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ExportPickerPage(),
                              ),
                            );
                          },
                        ),
                      if (FeatureGate.canFingerPrint)
                        SwitchListTile.adaptive(
                          secondary: const Icon(Icons.fingerprint),
                          title: const Text('Enable biometrics'),
                          value: _biometricEnabled,
                          onChanged: (v) async {
                            Navigator.pop(context);
                            await _toggleBiometrics(v);
                          },
                        ),
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Lock app'),
                        onTap: () {
                          Navigator.pop(context);
                          _lockApp();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('About & Legal'),
                        onTap: () => Navigator.of(context).pushNamed('/about'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            SafeArea(
              // <<-- tambahkan ini
              bottom: true,
              child: TabBarView(
                children: [
                  // Seeds
                  ValueListenableBuilder<Box<SeedPhrase>>(
                    valueListenable: Hive.box<SeedPhrase>(
                      'seed_phrase_box',
                    ).listenable(),
                    builder: (context, box, _) {
                      final items = box.values.toList();
                      if (items.isEmpty) {
                        return const Center(child: Text('No seed phrases'));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final phrase = items[index];
                          return ListTile(
                            leading: const Icon(Icons.shield_outlined),
                            title: Text(
                              phrase.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: const Text(
                              'Tap to reveal',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _handleRevealPhrase(phrase),
                          );
                        },
                      );
                    },
                  ),
                  // Notes
                  ValueListenableBuilder<Box<SecureNote>>(
                    valueListenable: Hive.box<SecureNote>(
                      'note_box',
                    ).listenable(),
                    builder: (context, box, _) {
                      final items = box.values.toList();
                      if (items.isEmpty) {
                        return const Center(child: Text('No Notes'));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final note = items[index];
                          return ListTile(
                            leading: const Icon(Icons.sticky_note_2_outlined),
                            title: Text(
                              note.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _handleRevealNote(note),
                          );
                        },
                      );
                    },
                  ),
                  // Passwords
                  ValueListenableBuilder<Box<PasswordItem>>(
                    valueListenable: Hive.box<PasswordItem>(
                      'password_box',
                    ).listenable(),
                    builder: (context, box, _) {
                      final items = box.values.toList();
                      if (items.isEmpty) {
                        return const Center(child: Text('No Passwords'));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            leading: const Icon(Icons.lock_outline),
                            title: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: item.username != null
                                ? Text(
                                    item.username!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _handleRevealPassword(item),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF000000).withValues(alpha: 0.7),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            if (_authBusy)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF000000).withValues(alpha: 0.35),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          _authMsg.isEmpty
                              ? 'Waiting for biometric…'
                              : _authMsg,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openAddMenu,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
