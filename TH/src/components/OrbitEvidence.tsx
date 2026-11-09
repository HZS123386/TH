import type { ThaiHoroscope } from 'thai-astrology';
import type { Copy } from '../lib/i18n';
import type { Language, Profile } from '../types';
import type { ThaiChart } from '../lib/thai';
import { contentFor } from '../lib/wanjai';
import { type ChartRelation } from '../lib/chartGeometry';
import { PickerDialog } from './PickerDialog';
import { formatBirthTime } from '../lib/birthTime';

export function planetLabel(point: keyof ThaiHoroscope['points'], t: Copy) {
  return t[`c_planet_${point}`];
}

export function OrbitEvidence({
  point,
  line,
  profile,
  location,
  language,
  t,
  onClose,
}: {
  point?: ThaiHoroscope['points']['sun'];
  line?: ChartRelation;
  profile?: Profile | null;
  location?: ThaiChart['location'];
  language: Language;
  t: Copy;
  onClose: () => void;
}) {
  const signs = contentFor(language).signs;
  const values = line ? [line.from, line.to] : point ? [point] : [];
  return (
    <PickerDialog
      title={
        line
          ? `${planetLabel(line.from.key, t)} · ${planetLabel(line.to.key, t)}`
          : point
            ? planetLabel(point.key, t)
            : t.c_pointDetails
      }
      t={t}
      onCancel={onClose}
      onConfirm={onClose}
    >
      {line && (
        <div className="mb-4 rounded-xl border border-line bg-canvas p-4">
          <p className="flex items-center gap-2 text-sm font-medium">
            <span className="h-1 w-7 rounded-full" style={{ background: line.color }} />
            {t[`c_relation_${line.kind}`]}
          </p>
          <p className="mt-2 text-xs leading-6 text-muted">{t.c_relationScope}</p>
        </div>
      )}
      <div className="space-y-3">
        {values.map((value) => (
          <section key={value.key} className="rounded-xl border border-line p-4">
            <h4 className="text-sm font-medium">
              {value.number ?? 'ลั'} · {planetLabel(value.key, t)}{' '}
              <span lang="th" className="text-xs text-muted">
                {value.nameThai}
              </span>
            </h4>
            <dl className="mt-3 grid grid-cols-[1fr_auto] gap-x-3 gap-y-2 text-xs leading-6">
              <dt className="text-muted">{t.c_signPosition}</dt>
              <dd>
                {signs[value.sign].name} · {value.degrees}° {value.minutes.toFixed(1)}′
              </dd>
              <dt className="text-muted">{t.th_house}</dt>
              <dd>{value.house}</dd>
              <dt className="text-muted">{t.c_longitude}</dt>
              <dd>{value.longitudeDegrees.toFixed(4)}°</dd>
            </dl>
            {value.dignities.length > 0 && (
              <p lang="th" className="mt-3 text-xs leading-6 text-gold">
                {value.dignities.join(' · ')}
              </p>
            )}
          </section>
        ))}
      </div>
      {profile && (
        <section
          className="mt-5 rounded-xl bg-[#f4ecdf] p-4 text-xs leading-7"
          data-testid="orbit-birth-source"
        >
          <h4 className="mb-1 font-medium">{t.c_birthSource}</h4>
          {profile.display_name && <p>{profile.display_name}</p>}
          <p>
            {profile.birth_date} · {formatBirthTime(profile.birth_time, t)}
          </p>
          <p>{profile.timezone}</p>
          {profile.birthplace && <p>{profile.birthplace}</p>}
          {location?.latitude != null && location.longitude != null && (
            <p>
              {location.latitude}, {location.longitude}
            </p>
          )}
        </section>
      )}
      <p className="mt-4 text-xs leading-6 text-muted">{t.c_birthScope}</p>
    </PickerDialog>
  );
}
