import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../shared/feature_flags.dart';

const String kCompanyName = 'Jenova';
const String kSupportEmail = 'techjenova@gmail.com';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  Future<PackageInfo> _info() => PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final isPro = FeatureGate.isPro;
    final flavorLabel = isPro ? 'PRO' : 'FREE';

    return Scaffold(
      appBar: AppBar(title: const Text('About & Legal')),
      body: FutureBuilder<PackageInfo>(
        future: _info(),
        builder: (context, snap) {
          final info = snap.data;
          final appName = info?.appName ?? 'SeedSafe';
          final version = info != null
              ? '${info.version} (${info.buildNumber})'
              : '...';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => const FlutterLogo(size: 40),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              appName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Chip(
                              label: Text(flavorLabel),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Version $version',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Privacy Policy (in-app)
              _SectionCard(
                icon: Icons.policy_outlined,
                title: 'Privacy Policy',
                child: const _PrivacyPolicyEN(),
              ),

              // Terms & Disclaimer (in-app)
              _SectionCard(
                icon: Icons.gavel_outlined,
                title: 'Terms & Disclaimer',
                child: const _TermsDisclaimerEN(),
              ),

              // Contact & Credits
              _SectionCard(
                icon: Icons.info_outline,
                title: 'Contact & Credits',
                child: _ContactCredits(year: year),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Open-source Licenses (native page)
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('Open-source Licenses'),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: appName,
                    applicationVersion: version,
                    applicationLegalese: '© $year $kCompanyName',
                    applicationIcon: SizedBox(
                      width: 100,
                      height: 100,
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) =>
                            const FlutterLogo(size: 36),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Made with 💚 by $kCompanyName',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(title, style: t.titleMedium),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _PrivacyPolicyEN extends StatelessWidget {
  const _PrivacyPolicyEN();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget p(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: t.bodyMedium),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last updated: 22 August 2025',
          style: t.bodySmall?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        p(
          'SeedSafe (“App”) is an offline password & sensitive-notes manager by Jenova (“we”). This Policy explains how the App processes data on your device.',
        ),
        Text('Scope', style: t.titleSmall),
        p(
          'SeedSafe does not require an account and does not connect to our servers. All processing happens on your device.',
        ),
        Text('Data We Collect', style: t.titleSmall),
        p(
          'We do not collect or transmit your personal data to any server. All data (passwords, notes, recovery phrases) is stored only on your device.',
        ),
        Text('On‑device Processing & Security', style: t.titleSmall),
        _bullets([
          'Data at rest is encrypted on your device.',
          'Access is protected by a passcode and/or biometrics (if available).',
          'We do not have access to your encryption keys and cannot recover data if you forget your passcode.',
        ], t),
        Text('Permissions Used', style: t.titleSmall),
        _bullets([
          'Biometrics: to unlock the app.',
          'Storage/Files (scoped): user‑initiated export/import.',
          'Camera (optional): scan/show QR codes for export/import.',
        ], t),
        p('The app does not show ads.'),
        Text('Data Sharing', style: t.titleSmall),
        p('We do not share your data with third parties.'),
        Text('Retention & User Control', style: t.titleSmall),
        p(
          'Data remains until you delete it, clear app storage, or uninstall the app.',
        ),
        Text('Data Deletion', style: t.titleSmall),
        p(
          'There is no server account. To delete data: Android → Settings → Apps → SeedSafe → Storage → Clear Storage, or uninstall the app.',
        ),
        Text('Children', style: t.titleSmall),
        p('The App is intended for users aged 18+.'),
      ],
    );
  }

  Widget _bullets(List<String> items, TextTheme t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: items
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.circle, size: 6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e, style: t.bodyMedium)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TermsDisclaimerEN extends StatelessWidget {
  const _TermsDisclaimerEN();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    Widget bullet(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.check_circle_outline, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: t.bodyMedium,
                children: [
                  TextSpan(
                    text: '$title — ',
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bullet(
          'Local‑only & Encryption',
          'SeedSafe stores your data only on your device. Data at rest is encrypted. We have no access to your passcode or encryption keys.',
        ),
        bullet(
          'No Account / No Cloud',
          'SeedSafe does not require an account and does not upload your data to our servers.',
        ),
        bullet(
          'Limitation of Liability',
          'If your device is lost, damaged, restored, or if you forget your passcode, we cannot recover your data. You are fully responsible for backups/exports and for keeping your data confidential.',
        ),
        bullet(
          'Data Deletion',
          'Delete data within the app, clear app storage, or uninstall the app. There is no server‑side account to delete.',
        ),
        Text(
          'By using SeedSafe, you agree to these terms.',
          style: t.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

class _ContactCredits extends StatelessWidget {
  final int year;
  const _ContactCredits({required this.year});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.mail_outline),
          title: const Text('Support Email'),
          subtitle: Text(kSupportEmail),
        ),
        const SizedBox(height: 8),
        Text('Credits', style: t.titleSmall),
        const SizedBox(height: 4),
        Text('Made by $kCompanyName', style: t.bodyMedium),
        const SizedBox(height: 2),
        Text(
          '© $kCompanyName $year. All rights reserved.',
          style: t.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}
