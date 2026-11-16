import 'package:flutter/foundation.dart';
import '../../core/storage/session_store.dart';

class ActionPlan {
  const ActionPlan({
    required this.id,
    required this.title,
    required this.category,
    required this.beneficiary,
    required this.date,
    required this.reviewDate,
    required this.notes,
    required this.reflection,
    required this.done,
    required this.reviewed,
  });

  final String id, title, notes, reflection;
  final int category, beneficiary;
  final DateTime date, reviewDate;
  final bool done, reviewed;

  bool readyOn(DateTime today) =>
      done && !reviewed && !reviewDate.isAfter(today);

  static ActionPlan? fromJson(Map<String, dynamic> value) {
    final date = DateTime.tryParse(value['date']?.toString() ?? '');
    final review = DateTime.tryParse(value['review_date']?.toString() ?? '');
    if (date == null ||
        review == null ||
        value['id'] is! String ||
        value['title'] is! String) {
      return null;
    }
    final category = value['category'], beneficiary = value['beneficiary'];
    return ActionPlan(
      id: value['id'] as String,
      title: value['title'] as String,
      category: category == 1 ? 1 : 0,
      beneficiary: beneficiary == 0
          ? 0
          : beneficiary == 2
          ? 2
          : 1,
      date: date,
      reviewDate: review,
      notes: value['notes']?.toString() ?? '',
      reflection: value['reflection']?.toString() ?? '',
      done: value['done'] == true,
      reviewed: value['done'] == true && value['reviewed'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'beneficiary': beneficiary,
    'date': date.toIso8601String(),
    'review_date': reviewDate.toIso8601String(),
    'notes': notes,
    'reflection': reflection,
    'done': done,
    'reviewed': reviewed,
  };
}

class ActionLedger extends ChangeNotifier {
  ActionLedger(this.drafts);

  static const storageKind = LocalDraftStore.actionLedger;
  final LocalDraftStore drafts;
  Future<void> _pending = Future.value();

  List<ActionPlan> plans(String owner) {
    final rows = drafts.read(owner, storageKind)?['items'];
    return rows is List
        ? rows
              .whereType<Map<String, dynamic>>()
              .map(ActionPlan.fromJson)
              .whereType<ActionPlan>()
              .toList()
        : [];
  }

  int? weekday(String owner) {
    final day = drafts.read(owner, storageKind)?['weekday'];
    return day is int && day >= 1 && day <= 7 ? day : null;
  }

  Future<void> save(String owner, ActionPlan plan) => _change(owner, () {
    final items = plans(owner);
    final existing = items.indexWhere((item) => item.id == plan.id);
    if (existing < 0) {
      items.insert(0, plan);
    } else {
      items[existing] = plan;
    }
    return {
      'weekday': weekday(owner),
      'items': items.map((item) => item.toJson()).toList(),
    };
  });

  Future<void> setWeekday(String owner, int day) => _change(
    owner,
    () => {...?drafts.read(owner, storageKind), 'weekday': day},
  );

  Future<void> clear(String owner) =>
      _ordered(() => drafts.remove(owner, storageKind));

  Future<void> _change(String owner, Map<String, dynamic> Function() update) =>
      _ordered(() => drafts.write(owner, storageKind, update()));

  Future<void> _ordered(Future<void> Function() update) {
    final next = _pending.then((_) async {
      await update();
      if (hasListeners) notifyListeners();
    });
    _pending = next.catchError((Object _) {});
    return next;
  }
}
