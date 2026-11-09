import { ArrowUpRight, Grid2X2, Moon, Orbit, Sparkles } from 'lucide-react';
import type { Copy } from '../lib/i18n';
import type { ExplorationModule } from '../types';

export const moduleIcons = {
  bazi: Grid2X2,
  western_astrology: Orbit,
  thai_astrology: Sparkles,
  dreams: Moon,
};
export function ModuleCatalog({
  modules,
  t,
  onStart,
}: {
  modules: ExplorationModule[];
  t: Copy;
  onStart: (id: ExplorationModule['id']) => void;
}) {
  return (
    <section className="enter mx-auto max-w-4xl">
      <p className="mb-6 max-w-2xl text-sm leading-7 text-muted">{t.moduleIntro}</p>
      <div className="grid gap-5 sm:grid-cols-2">
        {modules.map((module) => {
          const Icon = moduleIcons[module.id];
          return (
            <article key={module.id} className="panel flex flex-col p-7">
              <div className="flex items-center justify-between">
                <span className="rounded-xl bg-surface p-3 text-accent">
                  <Icon size={25} strokeWidth={1.4} />
                </span>
                <span
                  className={`rounded-full px-3 py-1 text-[10px] ${module.status === 'ready' ? 'bg-surface text-accent' : 'bg-canvas text-muted'}`}
                >
                  {module.status === 'ready' ? t.moduleAvailable : t.coming}
                </span>
              </div>
              <h2 className="mb-3 mt-6 text-lg font-medium">{t[`module_${module.id}`]}</h2>
              <p className="mb-6 text-xs leading-6 text-muted">
                {module.id === 'thai_astrology'
                  ? t.th_intro
                  : module.status === 'ready'
                    ? t.moduleBaziNote
                    : t.moduleFutureNote}
              </p>
              <button
                className="btn-primary mt-auto w-full"
                onClick={() => onStart(module.id)}
                disabled={module.status !== 'ready'}
              >
                {module.status === 'ready' ? t.moduleGo : t.coming}
                <ArrowUpRight size={15} />
              </button>
            </article>
          );
        })}
      </div>
    </section>
  );
}
