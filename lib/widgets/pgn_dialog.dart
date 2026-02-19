import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/utils/pgn_parser.dart';

/// Dialog for importing PGN
class PgnImportDialog extends StatefulWidget {
  const PgnImportDialog({super.key});

  @override
  State<PgnImportDialog> createState() => _PgnImportDialogState();
}

class _PgnImportDialogState extends State<PgnImportDialog> {
  final _controller = TextEditingController();
  String? _error;
  PgnGame? _parsedGame;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validatePgn() {
    final result = PgnParser.validate(_controller.text);
    setState(() {
      if (result.isValid) {
        _error = null;
        _parsedGame = result.game;
      } else {
        _error = result.error;
        _parsedGame = null;
      }
    });
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _controller.text = data!.text!;
      _validatePgn();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.upload_file, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Import PGN',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 8,
              onChanged: (_) => _validatePgn(),
              decoration: InputDecoration(
                hintText: 'Paste PGN here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _error,
                filled: true,
                fillColor: AppTheme.cardDark,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.paste),
                  label: const Text('Paste'),
                ),
                const Spacer(),
                if (_parsedGame != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_parsedGame!.moves.length} moves',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
              ],
            ),
            if (_parsedGame != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _parsedGame!.displayTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_parsedGame!.date != null)
                      Text(
                        _parsedGame!.date!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (_parsedGame!.result != null)
                      Text(
                        'Result: ${_parsedGame!.result}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _parsedGame != null
                      ? () => Navigator.pop(context, _parsedGame)
                      : null,
                  child: const Text('Import'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for exporting PGN
class PgnExportDialog extends StatelessWidget {
  final String pgn;

  const PgnExportDialog({super.key, required this.pgn});

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: pgn));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PGN copied to clipboard')));
  }

  void _share(BuildContext context) async {
    // Using the share_plus package would be ideal here
    // For now, we'll just copy to clipboard
    _copyToClipboard(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Export PGN',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  pgn,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _share(context),
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _copyToClipboard(context),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Show PGN import dialog
Future<PgnGame?> showPgnImportDialog(BuildContext context) async {
  return showDialog<PgnGame>(
    context: context,
    builder: (context) => const PgnImportDialog(),
  );
}

/// Show PGN export dialog
void showPgnExportDialog(BuildContext context, String pgn) {
  showDialog(
    context: context,
    builder: (context) => PgnExportDialog(pgn: pgn),
  );
}
