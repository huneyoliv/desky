import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/localization/app_translation.dart';
import '../flashcards/flashcard_notifier.dart';
import '../flashcards/widgets/create_card_dialog.dart';

class SmartBookScreen extends ConsumerStatefulWidget {
  final String? initialFilePath;

  const SmartBookScreen({
    super.key,
    this.initialFilePath,
  });

  @override
  ConsumerState<SmartBookScreen> createState() => _SmartBookScreenState();
}

class _SmartBookScreenState extends ConsumerState<SmartBookScreen> {
  late PdfViewerController _pdfViewerController;
  PdfTextSearchResult? _searchResult;
  String? _currentFilePath;
  String? _documentTitle;
  int _currentPage = 1;
  int _pageCount = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final List<int> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _currentFilePath = widget.initialFilePath;
    if (_currentFilePath != null) {
      _documentTitle = _currentFilePath!.split(Platform.pathSeparator).last;
    }
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _searchController.dispose();
    _searchResult?.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _currentFilePath = result.files.single.path;
          _documentTitle = result.files.single.name;
          _currentPage = 1;
          _bookmarks.clear();
        });
      }
    } catch (_) {}
  }

  void _toggleBookmark() {
    setState(() {
      if (_bookmarks.contains(_currentPage)) {
        _bookmarks.remove(_currentPage);
      } else {
        _bookmarks.add(_currentPage);
        _bookmarks.sort();
      }
    });
  }

  void _createFlashcardFromPage() {
    final t = ref.read(appTranslationProvider);
    final flashcardState = ref.read(flashcardNotifierProvider);
    if (flashcardState.decks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.tr('smartbook_need_deck_first', fallback: 'Crie um baralho de Flashcards primeiro para vincular anotações.')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final firstDeck = flashcardState.decks.first;
    ref.read(flashcardNotifierProvider.notifier).selectDeck(firstDeck);
    CreateCardDialog.show(
      context,
      onSave: (front, back, hint) {
        ref.read(flashcardNotifierProvider.notifier).createCard(
          front: front.isNotEmpty ? front : '${t.tr("smartbook_ref", fallback: "Referência")}: $_documentTitle (${t.tr("page", fallback: "Página")} $_currentPage)',
          back: back,
          hint: hint,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.tr("smartbook_card_saved", fallback: "Flashcard salvo no baralho")} "${firstDeck.title}"!'),
            backgroundColor: AppColors.success,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appTranslationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _documentTitle ?? t.tr('pdf_reader_title', fallback: 'Leitor de PDF'),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_currentFilePath != null) ...[
            IconButton(
              icon: Icon(
                _bookmarks.contains(_currentPage) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: _bookmarks.contains(_currentPage) ? Colors.amber : Colors.white70,
              ),
              tooltip: t.tr('smartbook_bookmark_page', fallback: 'Marcar Página'),
              onPressed: _toggleBookmark,
            ),
            IconButton(
              icon: const Icon(Icons.style_rounded, color: AppColors.primary),
              tooltip: t.tr('smartbook_create_flashcard', fallback: 'Criar Flashcard desta Página'),
              onPressed: _createFlashcardFromPage,
            ),
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white70),
              tooltip: t.tr('smartbook_search_pdf', fallback: 'Buscar no PDF'),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchResult?.clear();
                    _searchController.clear();
                  }
                });
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.file_open_rounded, color: AppColors.primary),
            tooltip: t.tr('smartbook_open_pdf', fallback: 'Abrir PDF Local'),
            onPressed: _pickPdfFile,
          ),
          const SizedBox(width: 8),
        ],
        bottom: _isSearching
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: AppColors.surfaceLight,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: t.tr('smartbook_search_hint', fallback: 'Digite o termo de busca...'),
                            hintStyle: const TextStyle(color: AppColors.textMuted),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (query) {
                            if (query.trim().isNotEmpty) {
                              _searchResult = _pdfViewerController.searchText(query);
                              setState(() {});
                            }
                          },
                        ),
                      ),
                      if (_searchResult != null && _searchResult!.hasResult) ...[
                        Text(
                          '${_searchResult!.currentInstanceIndex} / ${_searchResult!.totalInstanceCount}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        IconButton(
                          icon: const Icon(Icons.navigate_before, color: Colors.white),
                          onPressed: () => _searchResult?.previousInstance(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.navigate_next, color: Colors.white),
                          onPressed: () => _searchResult?.nextInstance(),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: _currentFilePath == null ? _buildEmptyView(t) : _buildPdfViewerArea(),
      bottomNavigationBar: _currentFilePath != null ? _buildControlBar(t) : null,
    );
  }

  Widget _buildEmptyView(AppTranslation t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 80,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t.tr('pdf_reader_empty_title', fallback: 'Leitor de PDF (Materiais e Apostilas)'),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              t.tr('pdf_reader_empty_desc', fallback: 'Abra arquivos PDF do seu computador para estudar com zoom, páginas, marcadores e gerar flashcards.'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickPdfFile,
            icon: const Icon(Icons.folder_open_rounded, color: Colors.white),
            label: Text(t.tr('smartbook_select_pdf_btn', fallback: 'Selecionar Arquivo PDF'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewerArea() {
    return SfPdfViewer.file(
      File(_currentFilePath!),
      controller: _pdfViewerController,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      enableDoubleTapZooming: true,
      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
        setState(() {
          _pageCount = details.document.pages.count;
        });
      },
      onPageChanged: (PdfPageChangedDetails details) {
        setState(() {
          _currentPage = details.newPageNumber;
        });
      },
    );
  }

  Widget _buildControlBar(AppTranslation t) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.navigate_before_rounded, color: Colors.white),
                onPressed: _currentPage > 1 ? () => _pdfViewerController.previousPage() : null,
              ),
              Text(
                '${t.tr("page", fallback: "Página")} $_currentPage / $_pageCount',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              IconButton(
                icon: const Icon(Icons.navigate_next_rounded, color: Colors.white),
                onPressed: _currentPage < _pageCount ? () => _pdfViewerController.nextPage() : null,
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.zoom_out_rounded, color: Colors.white70),
                tooltip: t.tr('smartbook_zoom_out', fallback: 'Reduzir Zoom'),
                onPressed: () {
                  if (_pdfViewerController.zoomLevel > 1.0) {
                    _pdfViewerController.zoomLevel -= 0.25;
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.zoom_in_rounded, color: Colors.white70),
                tooltip: t.tr('smartbook_zoom_in', fallback: 'Aumentar Zoom'),
                onPressed: () {
                  _pdfViewerController.zoomLevel += 0.25;
                },
              ),
              IconButton(
                icon: const Icon(Icons.restart_alt_rounded, color: Colors.white70),
                tooltip: t.tr('smartbook_zoom_reset', fallback: 'Resetar Zoom'),
                onPressed: () {
                  _pdfViewerController.zoomLevel = 1.0;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
