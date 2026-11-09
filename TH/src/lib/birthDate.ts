export function daysInMonth(year: number, month: number) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

export function validBirthDate(year: number, month: number, day: number, maximum: string) {
  const date = `${year}-${String(month).padStart(2, '0')}-${String(Math.min(day, daysInMonth(year, month))).padStart(2, '0')}`;
  return date > maximum ? maximum : date;
}

export function dateParts(value: string) {
  const [year, month, day] = value.split('-').map(Number);
  return { year, month, day };
}
