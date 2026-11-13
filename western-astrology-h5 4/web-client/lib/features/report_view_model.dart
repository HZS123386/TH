import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';

class ReportViewModel extends ChangeNotifier {
  ReportViewModel(this.h5, this.id);
  final H5Controller h5;
  final String id;
  LifeReport? report;
  String error = '', exportStatus = '';
  bool loading = false,
      exporting = false,
      feedbackBusy = false,
      _disposed = false,
      _active = true;
  CancelToken? _read, _feedback;
  Timer? _poll;
  Future<void> load({bool background = false}) async {
    _poll?.cancel();
    _read?.cancel();
    final token = CancelToken();
    _read = token;
    if (!background) {
      loading = true;
      error = '';
      notifyListeners();
    }
    try {
      final next = await h5.repository.load(id, token);
      if (_disposed || token.cancelled) return;
      if (!await h5.changeLanguage(next.language)) {
        throw const ApiFailure('network');
      }
      if (_disposed || token.cancelled) return;
      if (next.full || next.preview.isNotEmpty) {
        await h5.prepareText(jsonEncode(next.json), language: next.language);
      }
      if (_disposed || token.cancelled) return;
      report = next;
      error = '';
    } catch (cause) {
      if (!_disposed && !token.cancelled) error = h5.message(cause);
    } finally {
      if (!_disposed && !token.cancelled) {
        loading = false;
        notifyListeners();
        _schedule();
      }
    }
  }

  void _schedule() {
    _poll?.cancel();
    final r = report;
    if (!_active || r == null) return;
    if (r.json['preview_state'] == 'generating' ||
        r.full && r.json['full_state'] == 'generating') {
      _poll = Timer(const Duration(seconds: 3), () {
        if (h5.browser.visible) {
          unawaited(load(background: true));
        } else {
          _schedule();
        }
      });
    }
  }

  void pause() {
    _active = false;
    _poll?.cancel();
    _read?.cancel();
  }

  void resume() {
    _active = true;
    unawaited(load(background: report != null));
  }

  void accept(LifeReport next) {
    if (next.id != id) throw const FormatException('report_changed');
    report = next;
    error = '';
    notifyListeners();
    _schedule();
  }

  Future<void> feedback(String rating) async {
    if (!['close', 'partly', 'different'].contains(rating) || report == null) {
      return;
    }
    _feedback?.cancel();
    final token = CancelToken();
    _feedback = token;
    feedbackBusy = true;
    notifyListeners();
    try {
      await h5.repository.request(
        '/api/life-reports/$id/feedback',
        token,
        body: {'rating': rating},
      );
      if (!_disposed && !token.cancelled) {
        report = LifeReport.parse({
          ...report!.json,
          'feedback': rating,
        }, id: id);
        error = '';
      }
    } catch (cause) {
      if (!_disposed && !token.cancelled) error = h5.message(cause);
    } finally {
      if (!_disposed && !token.cancelled) {
        feedbackBusy = false;
        notifyListeners();
      }
    }
  }

  Future<void> export(String format) async {
    final r = report;
    if (exporting || r == null) return;
    final c = h5.copy.forReport(r);
    exporting = true;
    exportStatus = c.t(
      'report',
      format == 'pdf' ? 'pdfPreparing' : 'htmlPreparing',
    );
    notifyListeners();
    try {
      final result = await h5.browser.exportDocument(r, format);
      if (!_disposed) {
        exportStatus = result == 'cancelled'
            ? ''
            : c.t(
                'report',
                format == 'html'
                    ? 'htmlDownloaded'
                    : result == 'saved'
                    ? 'pdfSaved'
                    : 'pdfDownloaded',
              );
      }
    } catch (_) {
      if (!_disposed) {
        exportStatus = c.t(
          'report',
          format == 'pdf' ? 'pdfError' : 'htmlError',
        );
      }
    } finally {
      if (!_disposed) {
        exporting = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _read?.cancel();
    _feedback?.cancel();
    super.dispose();
  }
}
