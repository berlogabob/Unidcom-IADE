enum ReviewKind { field, output }

enum ReviewDecision {
  accepted('accepted'),
  rejected('rejected'),
  changeRequested('change_requested');

  const ReviewDecision(this.wire);

  /// Value `finish_review` expects.
  final String wire;
}

class ReviewItem {
  const ReviewItem({required this.id, required this.kind});
  final String id;
  final ReviewKind kind;
}

/// Decisions for one researcher review, held in memory until Finish review
/// (brief RV-2, RV-6, RV-7), so Undo needs no round trip.
class ReviewSession {
  ReviewSession(List<ReviewItem> items) : _items = List.unmodifiable(items);

  final List<ReviewItem> _items;
  final Map<String, ReviewDecision> _decisions = {};
  final Map<String, String> _comments = {};

  int get total => _items.length;
  int get decided => _decisions.length;
  bool get canFinish => decided == total;

  ReviewDecision? decisionOf(String id) => _decisions[id];

  /// Open items first, decided ones below; original order within each group.
  List<ReviewItem> get ordered => [
    ..._items.where((i) => !_decisions.containsKey(i.id)),
    ..._items.where((i) => _decisions.containsKey(i.id)),
  ];

  void decide(String id, ReviewDecision decision, {String? comment}) {
    final text = comment?.trim();
    if (decision == ReviewDecision.changeRequested &&
        (text == null || text.isEmpty)) {
      throw ArgumentError('A change request needs a comment');
    }
    _decisions[id] = decision;
    if (text == null || text.isEmpty) {
      _comments.remove(id);
    } else {
      _comments[id] = text;
    }
  }

  void undo(String id) {
    _decisions.remove(id);
    _comments.remove(id);
  }

  void acceptAllRemaining() {
    for (final item in _items) {
      _decisions.putIfAbsent(item.id, () => ReviewDecision.accepted);
    }
  }

  /// The `p_decisions` argument of `finish_review`.
  List<Map<String, Object?>> toPayload() {
    if (!canFinish) throw StateError('Every item needs a decision');
    return [
      for (final item in _items)
        {
          'kind': item.kind.name,
          'id': item.id,
          'decision': _decisions[item.id]!.wire,
          'comment': _comments[item.id],
        },
    ];
  }
}
