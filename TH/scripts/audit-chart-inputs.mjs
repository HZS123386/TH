// Offline comparison only. This module does not change the production Thai engine.
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { calculateProfile } from './thai-engine.mjs';

if (!process.argv[2]) {
  console.error('Usage: node scripts/audit-chart-inputs.mjs <astronomy-engine esm/astronomy.js>');
  process.exit(1);
}
const A = await import(pathToFileURL(resolve(process.argv[2])).href);
const normalize = (value) => ((value % 360) + 360) % 360;

// The eastern intersection of the horizon and true ecliptic of date.
// No Placidus cusps or degree-based aspect orbs are calculated here.
function geometricAscendant(date, latitude, longitude) {
  const observer = new A.Observer(latitude, longitude, 0);
  const rotation = A.CombineRotation(A.Rotation_HOR_EQD(date, observer), A.Rotation_EQD_ECT(date));
  const north = A.RotateVector(rotation, A.VectorFromHorizon(new A.Spherical(0, 0, 1), date, null));
  const east = A.RotateVector(rotation, A.VectorFromHorizon(new A.Spherical(0, 90, 1), date, null));
  let x = east.x * north.z - north.x * east.z;
  let y = east.y * north.z - north.y * east.z;
  // In the horizon's orthonormal north/east basis, the east coefficient is north.z.
  if (north.z < 0) {
    x = -x;
    y = -y;
  }
  return normalize((Math.atan2(y, x) * 180) / Math.PI);
}

const results = [];
for (const [time, latitude, longitude, place] of [
  ['07:15', 39.9075, 116.39723, 'Beijing'],
  ['19:15', 39.9075, 116.39723, 'Beijing'],
  ['19:15', 35, 105, 'hypothetical-country-center-not-confirmed-phone-coordinates'],
]) {
  const profile = {
    birth_date: '1999-02-20',
    birth_time: time,
    timezone: 'Asia/Shanghai',
    birthplace: place,
    latitude,
    longitude,
  };
  const traditional = calculateProfile(profile, 28800);
  const utc = new Date(`1999-02-20T${time}:00+08:00`);
  results.push({
    local_time: time,
    utc: utc.toISOString(),
    latitude,
    longitude,
    place,
    thai: Object.fromEntries(
      ['sun', 'moon', 'ascendant'].map((key) => [
        key,
        traditional.chart.points[key].longitudeDegrees,
      ]),
    ),
    tropical: {
      sun: A.Ecliptic(A.GeoVector(A.Body.Sun, utc, true)).elon,
      moon: A.Ecliptic(A.GeoVector(A.Body.Moon, utc, true)).elon,
      ascendant: geometricAscendant(utc, latitude, longitude),
    },
  });
}
const output = resolve('tmp/chart-input-audit.json');
mkdirSync(resolve('tmp'), { recursive: true });
writeFileSync(
  output,
  JSON.stringify(
    { audit_engine: 'astronomy-engine@2.1.19', production_engine: 'thai-astrology@0.3.2', results },
    null,
    2,
  ) + '\n',
);
console.log(`Wrote ${results.length} comparisons to ${output}`);
