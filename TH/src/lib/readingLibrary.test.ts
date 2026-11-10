import { afterEach, expect, it } from 'vitest';
import {
  captureReading,
  readSavedReadings,
  removeSavedReading,
  saveReading,
} from './readingLibrary';

afterEach(() => localStorage.clear());

it('keeps at most five snapshots and separates guests from individual accounts', () => {
  for (let index = 0; index < 6; index++)
    saveReading('guest', {
      id: `saved-${index}`,
      title: `Report ${index}`,
      birthDate: '1999-02-20',
      savedAt: index,
      html: '<!doctype html><html><body>Original report</body></html>',
    });
  expect(readSavedReadings('guest').map((row) => row.id)).toEqual([
    'saved-5',
    'saved-4',
    'saved-3',
    'saved-2',
    'saved-1',
  ]);
  expect(readSavedReadings('account-a')).toEqual([]);
  expect(removeSavedReading('guest', 'saved-3')).toHaveLength(4);
});

it('ignores corrupt storage and captures a complete static reading without navigation or external images', () => {
  localStorage.setItem('astro.saved-readings.v1.guest', '{invalid');
  expect(readSavedReadings('guest')).toEqual([]);
  const report = document.createElement('div');
  report.innerHTML =
    '<h1>&lt;name&gt;</h1><nav>Links</nav><button>Save</button><details><summary>Family</summary><p>Original advice</p></details><img src="/image.png" alt="Aries"><svg><g data-planet="sun" opacity=".35"></g></svg>';
  const html = captureReading(report, '<Report>');
  expect(html).toContain('<title>&lt;Report&gt;</title>');
  expect(html).toContain('details open=');
  expect(html).toContain('Original advice');
  expect(html).toContain('data-planet="sun" opacity="1"');
  expect(html).not.toMatch(/<button|<nav|<img|<script/);
});
