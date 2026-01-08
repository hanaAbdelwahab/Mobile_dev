import 'package:flutter/foundation.dart';
import '../../controllers/story_controller.dart';
class StoryProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _stories = [];

  List<Map<String, dynamic>> get stories => _stories;

  // =========================
  // تحميل الستوريز
  // =========================
  Future<void> loadStories({
    required int currentUserId,
    required bool forYou,
  }) async {
    _stories = await StoryController.fetchStories(
      currentUserId: currentUserId,
      forYou: forYou,
    );

    notifyListeners();
  }

  // =========================
  // لما ستوري تتشاف
  // =========================
  void markStorySeen(int storyId) {
    final index = _stories.indexWhere((s) => s['id'] == storyId);
    if (index != -1) {
      _stories[index]['is_seen'] = true;
      notifyListeners();
    }
  }

  // =========================
  // تحديث بعد الرجوع من StoryViewer
  // =========================
  Future<void> refresh({
    required int currentUserId,
    required bool forYou,
  }) async {
    await loadStories(
      currentUserId: currentUserId,
      forYou: forYou,
    );
  }
}
