import { useState } from 'react';

function createSky() {
  const stars = Array.from({ length: 115 }, (_, index) => ({
    x: Math.random() * 1440,
    y: Math.random() * 1100,
    radius: index % 13 === 0 ? 1.7 : 0.5 + Math.random(),
    opacity: 0.2 + Math.random() * 0.45,
    delay: Math.random() * -8,
  }));
  const shapes = [
    [
      [0, 0],
      [45, 24],
      [85, 5],
      [112, 48],
      [76, 91],
    ],
    [
      [0, 28],
      [38, 0],
      [65, 45],
      [33, 89],
      [93, 105],
    ],
    [
      [0, 0],
      [38, 37],
      [20, 87],
      [82, 108],
      [112, 76],
    ],
  ];
  const constellations = Array.from({ length: 4 }, (_, index) => ({
    points: shapes[Math.floor(Math.random() * shapes.length)],
    x: index % 2 ? 250 + Math.random() * 80 : 1220 + Math.random() * 35,
    y: 50 + index * 230 + Math.random() * 65,
  }));
  return { stars, constellations };
}

export function Starfield() {
  // Randomize once per visit; typing, navigation and login keep the same sky.
  const [{ stars, constellations }] = useState(createSky);
  return (
    <div aria-hidden="true" className="pointer-events-none fixed inset-0 -z-10 overflow-hidden">
      <svg
        viewBox="0 0 1440 1100"
        preserveAspectRatio="xMidYMin slice"
        className="h-full min-h-[900px] w-full"
      >
        {stars.map((star, index) => (
          <circle
            key={index}
            cx={star.x}
            cy={star.y}
            r={star.radius}
            fill={index % 9 === 0 ? '#b28b4c' : '#c0ad8c'}
            opacity={star.opacity}
            className={index % 13 === 0 ? 'star-twinkle' : undefined}
            style={index % 13 === 0 ? { animationDelay: `${star.delay}s` } : undefined}
          />
        ))}
        {constellations.map((constellation, index) => (
          <g
            key={index}
            transform={`translate(${constellation.x} ${constellation.y})`}
            stroke="#b49a6e"
            strokeWidth=".8"
            strokeOpacity=".3"
            fill="#b39b73"
          >
            <polyline
              points={constellation.points.map((point) => point.join(',')).join(' ')}
              fill="none"
            />
            {constellation.points.map(([x, y], i) => (
              <circle key={i} cx={x} cy={y} r={i === 1 ? 2.4 : 1.7} />
            ))}
          </g>
        ))}
      </svg>
    </div>
  );
}
