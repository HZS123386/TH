import type { Language } from '../types';
import type { BaziTopic } from '../lib/bazi';
import { baziFactBlocks } from '../lib/baziFacts';

export function BaziRoxyDetails({
  operation,
  data,
  language,
  translations,
}: {
  operation: BaziTopic;
  data: Record<string, unknown>;
  language: Language;
  translations?: Record<string, string>;
}) {
  return (
    <div className="mt-4 space-y-3" data-testid={'bazi-' + operation + '-facts'}>
      {baziFactBlocks(operation, data, language, translations).map((block, index) => (
        <div key={index} className="space-y-3">
          {block.paragraphs?.map((paragraph, index) => (
            <p key={index} className="text-xs leading-7">
              {paragraph}
            </p>
          ))}
          {block.columns && (
            <table className="w-full text-left text-[10px] leading-6">
              <thead>
                <tr>
                  {block.columns.map((column) => (
                    <th className="py-2" key={column}>
                      {column}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {block.rows?.map((row, index) => (
                  <tr key={index} className="border-t border-line">
                    {row.map((cell, index) => (
                      <td className="py-3" key={index}>
                        {cell}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      ))}
    </div>
  );
}
