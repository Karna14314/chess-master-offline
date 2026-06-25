import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = packageInfo.version;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _version = 'N/A';
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Open Source & Credits',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About Chess Master',
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version: $_version',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            _buildSection(
              title: 'Engine',
              content: 'Stockfish 16.1 - The powerful open source chess engine.\n\nStockfish is licensed under the GPLv3. The source code is available at github.com/official-stockfish/Stockfish.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Assets',
              content: 'Chess Pieces: Wikimedia Commons\n(Creative Commons Attribution-Share Alike 3.0)\n\nSounds: Licensed under CC0\nApp Icon: Custom design',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Libraries',
              content: '• chess.dart: Chess logic and move generation\n• flutter_riverpod: State management\n• sqflite: Local database\n• vibration: Haptic feedback\n• stockfish_chess_engine: FFI bindings',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Puzzle Database',
              content: 'Chess puzzles in this app are sourced from the Lichess.org open database.',
            ),
            const SizedBox(height: 16),
            Text(
              'Lichess is a free and open-source chess platform. We gratefully acknowledge the Lichess community for making this dataset publicly available.',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'Chess Master',
                    applicationVersion: _version,
                    applicationLegalese: 'Copyright © 2024\n\nStockfish Engine: GPLv3 License\nChess Pieces: CC BY-SA 3.0',
                  );
                },
                child: const Text('View All Licenses'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
