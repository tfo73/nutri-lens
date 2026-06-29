import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../widgets/wave_background.dart';

class LegalScreen extends StatefulWidget {
  final String title;
  final String trAssetPath;
  final String enAssetPath;

  const LegalScreen({
    super.key,
    required this.title,
    required this.trAssetPath,
    required this.enAssetPath,
  });

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  String _markdownContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure context is fully available for provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContent();
    });
  }

  Future<void> _loadContent() async {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final assetPath = langProvider.isTurkish ? widget.trAssetPath : widget.enAssetPath;
    
    try {
      final content = await rootBundle.loadString(assetPath);
      if (mounted) {
        setState(() {
          _markdownContent = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _markdownContent = langProvider.isTurkish 
            ? 'Metin yüklenirken bir hata oluştu: $e' 
            : 'Error loading text: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: WaveBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF58A6FF)))
            : Markdown(
                data: _markdownContent,
                styleSheet: MarkdownStyleSheet(
                  h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF58A6FF)),
                  h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE6EDF3)),
                  p: const TextStyle(fontSize: 14, color: Color(0xFFC9D1D9), height: 1.5),
                  listBullet: const TextStyle(color: Color(0xFF58A6FF)),
                  strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
      ),
    );
  }
}
