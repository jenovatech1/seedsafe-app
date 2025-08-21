import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../shared/feature_flags.dart';

const String kCompanyName = 'Jenova';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  Future<PackageInfo> _info() => PackageInfo.fromPlatform();
  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final flavorLabel = FeatureGate.isPro ? 'PRO' : 'FREE';
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
              Row(
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
                        Text(
                          appName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version $version • $flavorLabel',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Made by Jenova'),
                subtitle: Text('© $year $kCompanyName. All rights reserved.'),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('Open-source Licenses'),
                onTap: () {
                  showLicensePage(
                    context: context,
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
