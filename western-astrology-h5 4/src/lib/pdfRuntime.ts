import { isLifeReport, lifeLabels } from './lifeReport';
import { reportHtml } from './reading';
import { saveReportPdf } from './reportPdf';

// Keep the original permission-aware PDF and HTML document generation.
export async function exportDocument(payload: string, format: string) {
  const report: unknown = JSON.parse(payload);
  if (!isLifeReport(report)) throw new Error('Invalid report');
  if (format !== 'pdf' && format !== 'html') throw new Error('Invalid export format');
  const labels = lifeLabels(report);
  if (format === 'pdf') return saveReportPdf(report, labels, new AbortController().signal);
  const blob = new Blob([reportHtml(report, labels)], { type: 'text/html;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  const edition = report.access === 'full' && report.full_state === 'ready' ? 'full' : 'preview';
  const id = report.id.replace(/[^a-zA-Z0-9_-]/g, '').slice(0,48) || 'report';
  anchor.download = `FATE-${id}-${edition}.html`;
  document.body.append(anchor); anchor.click(); anchor.remove();
  setTimeout(() => URL.revokeObjectURL(url), 60000);
  return 'downloaded';
}
