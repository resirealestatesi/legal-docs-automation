import 'dart:io';
import 'dart:typed_data';
import 'package:docx_creator/docx_creator.dart';
import '../domain/entities/highlight_selection.dart';

class DocxService {
  /// Replaces specific ranges in a .docx document using start/end offsets.
  /// This prevents global replacement of the same text appearing elsewhere
  /// if it wasn't explicitly highlighted by the user.
  Future<Uint8List> replaceRangesInDocument(
    Uint8List docxBytes,
    List<HighlightSelection> highlights,
  ) async {
    final doc = await DocxReader.loadFromBytes(docxBytes);
    
    // Sort highlights by startOffset descending to avoid offset shift issues
    // when replacing multiple ranges.
    final sortedHighlights = List<HighlightSelection>.from(highlights)
      ..sort((a, b) => b.startOffset.compareTo(a.startOffset));

    List<DocxNode> elements = doc.elements;

    for (final highlight in sortedHighlights) {
      elements = _replaceRangeInElements(
        elements,
        highlight.startOffset,
        highlight.endOffset,
        highlight.highlightText,
      );
    }

    final modifiedDoc = DocxBuiltDocument(
      elements: elements,
      section: doc.section,
      stylesXml: doc.stylesXml,
      numberingXml: doc.numberingXml,
      numberingRelsXml: doc.numberingRelsXml,
      numberingImages: doc.numberingImages,
      settingsXml: doc.settingsXml,
      fontTableXml: doc.fontTableXml,
      fontTableRelsXml: doc.fontTableRelsXml,
      themeXml: doc.themeXml,
      contentTypesXml: doc.contentTypesXml,
      rootRelsXml: doc.rootRelsXml,
      headerBgXml: doc.headerBgXml,
      headerBgRelsXml: doc.headerBgRelsXml,
      footnotesXml: doc.footnotesXml,
      endnotesXml: doc.endnotesXml,
      fonts: doc.fonts,
      footnotes: doc.footnotes,
      endnotes: doc.endnotes,
      theme: doc.theme,
    );
    
    return DocxExporter().exportToBytes(modifiedDoc);
  }

  List<DocxNode> _replaceRangeInElements(
    List<DocxNode> elements,
    int start,
    int end,
    String replacement, {
    int currentOffset = 0,
  }) {
    int localOffset = currentOffset;
    final result = <DocxNode>[];

    for (var i = 0; i < elements.length; i++) {
        final node = elements[i];
        final nodeLength = _calculateNodeLength(node);
        
        if (localOffset + nodeLength > start && localOffset < end) {
            // This node contains or overlaps with the range
            if (node is DocxParagraph) {
                result.add(_replaceInRangeParagraph(node, start - localOffset, end - localOffset, replacement));
            } else if (node is DocxTable) {
                result.add(node);
            } else {
                result.add(node);
            }
        } else {
            result.add(node);
        }
        
        localOffset += nodeLength;
        localOffset += 1; // Newline
    }
    
    return result;
  }

  int _calculateNodeLength(DocxNode node) {
    if (node is DocxParagraph) {
      int length = 0;
      for (final child in node.children) {
        if (child is DocxText) {
          length += child.content.length;
        }
      }
      return length;
    } else if (node is DocxTable) {
      int length = 0;
      for (final row in node.rows) {
        for (final cell in row.cells) {
            for (final child in cell.children) {
                length += _calculateNodeLength(child);
                length += 1;
            }
        }
        length += 1;
      }
      return length;
    }
    return 0;
  }

  DocxParagraph _replaceInRangeParagraph(
    DocxParagraph paragraph,
    int localStart,
    int localEnd,
    String replacement,
  ) {
    final buffer = StringBuffer();
    final textRuns = <DocxText>[];
    
    for (final child in paragraph.children) {
      if (child is DocxText) {
        textRuns.add(child);
        buffer.write(child.content);
      }
    }
    
    final fullText = buffer.toString();
    final start = localStart.clamp(0, fullText.length);
    final end = localEnd.clamp(0, fullText.length);
    
    if (start >= end) return paragraph;

    final modifiedText = fullText.replaceRange(start, end, replacement);
    if (textRuns.isEmpty) return paragraph;
    
    final newChildren = <DocxInline>[];
    newChildren.add(textRuns.first.copyWith(content: modifiedText));
    
    for (final child in paragraph.children) {
      if (child is! DocxText) {
        newChildren.add(child);
      }
    }

    return paragraph.copyWith(children: newChildren);
  }

  /// Original global replacement
  Future<Uint8List> replaceTextInDocument(
    Uint8List docxBytes,
    Map<String, String> replacements,
  ) async {
    final doc = await DocxReader.loadFromBytes(docxBytes);
    final modifiedElements = doc.elements.map((e) => _replaceInNode(e, replacements)).toList();
    
    final modifiedDoc = DocxBuiltDocument(
      elements: modifiedElements,
      section: doc.section,
      stylesXml: doc.stylesXml,
      numberingXml: doc.numberingXml,
      numberingRelsXml: doc.numberingRelsXml,
      numberingImages: doc.numberingImages,
      settingsXml: doc.settingsXml,
      fontTableXml: doc.fontTableXml,
      fontTableRelsXml: doc.fontTableRelsXml,
      themeXml: doc.themeXml,
      contentTypesXml: doc.contentTypesXml,
      rootRelsXml: doc.rootRelsXml,
      headerBgXml: doc.headerBgXml,
      headerBgRelsXml: doc.headerBgRelsXml,
      footnotesXml: doc.footnotesXml,
      endnotesXml: doc.endnotesXml,
      fonts: doc.fonts,
      footnotes: doc.footnotes,
      endnotes: doc.endnotes,
      theme: doc.theme,
    );
    
    return DocxExporter().exportToBytes(modifiedDoc);
  }

  DocxNode _replaceInNode(DocxNode node, Map<String, String> replacements) {
    if (node is DocxParagraph) {
      return _replaceInParagraph(node, replacements);
    } else if (node is DocxTable) {
      return _replaceInTable(node, replacements);
    }
    return node;
  }

  DocxParagraph _replaceInParagraph(DocxParagraph paragraph, Map<String, String> replacements) {
    final buffer = StringBuffer();
    final textRuns = <DocxText>[];
    for (final child in paragraph.children) {
      if (child is DocxText) {
        textRuns.add(child);
        buffer.write(child.content);
      }
    }
    
    String text = buffer.toString();
    bool changed = false;
    for (final entry in replacements.entries) {
      if (text.contains(entry.key)) {
        text = text.replaceAll(entry.key, entry.value);
        changed = true;
      }
    }
    
    if (!changed || textRuns.isEmpty) return paragraph;
    
    return paragraph.copyWith(children: [
       textRuns.first.copyWith(content: text),
       ...paragraph.children.where((c) => c is! DocxText),
    ]);
  }

  DocxTable _replaceInTable(DocxTable table, Map<String, String> replacements) {
    final newRows = table.rows.map((row) {
      final newCells = row.cells.map((cell) {
        final newChildren = cell.children.map((child) => _replaceInNode(child, replacements) as DocxBlock).toList();
        return cell.copyWith(children: newChildren);
      }).toList();
      return row.copyWith(cells: newCells);
    }).toList();
    return table.copyWith(rows: newRows);
  }

  Future<void> exportToFile(Uint8List docxBytes, String filePath) async {
    final file = File(filePath);
    await file.writeAsBytes(docxBytes, flush: true);
  }

  Future<String> extractPlainText(Uint8List docxBytes) async {
    final doc = await DocxReader.loadFromBytes(docxBytes);
    final buffer = StringBuffer();

    for (final element in doc.elements) {
      if (element is DocxParagraph) {
        for (final child in element.children) {
          if (child is DocxText) {
            buffer.write(child.content);
          }
        }
        buffer.writeln();
      } else if (element is DocxTable) {
        for (final row in element.rows) {
          for (final cell in row.cells) {
            for (final child in cell.children) {
              if (child is DocxParagraph) {
                for (final inline in child.children) {
                  if (inline is DocxText) {
                    buffer.write(inline.content);
                  }
                }
                buffer.write('\t');
              }
            }
          }
          buffer.writeln();
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }
}
