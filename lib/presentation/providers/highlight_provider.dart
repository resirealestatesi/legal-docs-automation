import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/highlight_selection.dart';
import 'company_provider.dart';

final highlightsProvider =
    FutureProvider.family<List<HighlightSelection>, String>(
        (ref, templateId) async {
  final repo = ref.read(highlightRepositoryProvider);
  return repo.getHighlightsByTemplateId(templateId);
});

final highlightListProvider =
    NotifierProvider<HighlightListNotifier, List<HighlightSelection>>(
        HighlightListNotifier.new);

class HighlightListNotifier extends Notifier<List<HighlightSelection>> {
  @override
  List<HighlightSelection> build() => [];

  Future<void> loadHighlights(String templateId) async {
    final repo = ref.read(highlightRepositoryProvider);
    final highlights = await repo.getHighlightsByTemplateId(templateId);
    state = highlights;
  }

  Future<void> addHighlight(HighlightSelection highlight) async {
    final repo = ref.read(highlightRepositoryProvider);
    final id = await repo.saveHighlight(highlight);
    state = [...state, highlight.copyWith(id: id)];
  }

  Future<void> removeHighlight(int id) async {
    final repo = ref.read(highlightRepositoryProvider);
    await repo.deleteHighlight(id);
    state = state.where((h) => h.id != id).toList();
  }

  void clear() {
    state = [];
  }
}
