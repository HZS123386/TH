import type { Content, ContentOrderedList, ContentStack, ContentText, TDocumentDefinitions } from "pdfmake/interfaces";
import type { LifeLabels, LifeReport } from "./lifeReport";
import { reportHtml, ui } from "./reading";
import { reportContent, reportReference } from "./reportContent";
import { additionalLocales, localeTag } from "./locales";

type PdfEngine = typeof import("pdfmake/build/pdfmake");
type SaveWindow = Window & { showSaveFilePicker?: (options: {
  id: string; suggestedName: string; excludeAcceptAllOption: boolean;
  types: { description: string; accept: Record<string, string[]> }[];
}) => Promise<FileSystemFileHandle> };

let engine: Promise<PdfEngine> | undefined;
const thaiWords = typeof Intl.Segmenter === "function" ? new Intl.Segmenter("th", { granularity: "word" }) : undefined;
const regionalFonts = [
  { script: /[\u1000-\u109f\uaa60-\uaa7f\ua9e0-\ua9ff]/u, font: "NotoMyanmar", file: "NotoSansMyanmar-Regular.ttf", locale: "my" },
  { script: /[\u1780-\u17ff\u19e0-\u19ff]/u, font: "NotoKhmer", file: "NotoSansKhmer-Regular.ttf", locale: "km" },
  { script: /[\u0e80-\u0eff]/u, font: "NotoLao", file: "NotoSansLao-Regular.ttf", locale: "lo" },
];
const regionalWords = new Map<string, Intl.Segmenter>();

function textRuns(value: string, bold = false): ContentText[] {
  const text = value.replace(/[\u2010-\u2015\u2212]/g, "-");
  return (text.match(/[\u0e00-\u0e7f]+|[\u1000-\u109f\uaa60-\uaa7f\ua9e0-\ua9ff]+|[\u1780-\u17ff\u19e0-\u19ff]+|[\u0e80-\u0eff]+|[^\u0e00-\u0eff\u1000-\u109f\uaa60-\uaa7f\ua9e0-\ua9ff\u1780-\u17ff\u19e0-\u19ff]+/gu) || []).map(part => {
    const thai = /[\u0e00-\u0e7f]/u.test(part);
    const regional = regionalFonts.find(item => item.script.test(part));
    if (regional) {
      if (typeof Intl.Segmenter === "function" && !regionalWords.has(regional.locale)) {
        regionalWords.set(regional.locale, new Intl.Segmenter(regional.locale, { granularity: "word" }));
      }
      const segmenter = regionalWords.get(regional.locale);
      return { text: segmenter ? [...segmenter.segment(part)].map(word => word.segment).join("\u200b") : part, font: regional.font, bold };
    }
    // Explicit vowel decomposition preserves the same glyphs without duplicate vowels when copying PDF text.
    const words = thai && thaiWords ? [...thaiWords.segment(part)].map(word => word.segment) : [part];
    const content = thai ? words.map(word => word.normalize("NFKD")).join(thaiWords ? "\u200b" : "") : part;
    return { text: content, font: thai ? "NotoThai" : "NotoChinese", bold };
  });
}

function inline(node: Node, bold = false): ContentText[] {
  if (node.nodeType === Node.TEXT_NODE) return textRuns(node.textContent || "", bold);
  if (node.nodeName === "BR") return textRuns("\n", bold);
  return Array.from(node.childNodes).flatMap(child => inline(child, bold || node.nodeName === "STRONG"));
}

const palette = {
  night: "#21152F", purple: "#392448", gold: "#B18748", paleGold: "#E4BC78",
  paper: "#FCFAF7", ink: "#33273D", muted: "#81758B", line: "#DDD2E3", lavender: "#F1EBF5",
};

function star(x: number, y: number, radius: number, color: string) {
  return `<path d="M${x} ${y - radius}L${x + radius * .24} ${y - radius * .24}L${x + radius} ${y}L${x + radius * .24} ${y + radius * .24}L${x} ${y + radius}L${x - radius * .24} ${y + radius * .24}L${x - radius} ${y}L${x - radius * .24} ${y - radius * .24}Z" fill="none" stroke="${color}" stroke-width=".85"/>`;
}

// Decorative vectors keep the astrology identity sharp without rasterizing report text.
function pageArtwork(width: number, height: number, first: boolean, coverHeight: number): string {
  const centerX = width - 42, centerY = 100;
  const ticks = Array.from({ length: 48 }, (_, i) => {
    const angle = i * Math.PI / 24;
    const inner = i % 4 ? 103 : 96;
    return `<line x1="${centerX + Math.cos(angle) * inner}" y1="${centerY + Math.sin(angle) * inner}" x2="${centerX + Math.cos(angle) * 108}" y2="${centerY + Math.sin(angle) * 108}"/>`;
  }).join("");
  const wheel = `<g stroke="${palette.paleGold}" stroke-opacity=".2" fill="none" stroke-width=".6"><circle cx="${centerX}" cy="${centerY}" r="108"/><circle cx="${centerX}" cy="${centerY}" r="91"/><circle cx="${centerX}" cy="${centerY}" r="62"/>${ticks}<ellipse cx="${centerX}" cy="${centerY}" rx="125" ry="32" transform="rotate(-28 ${centerX} ${centerY})"/></g>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}"><rect width="${width}" height="${height}" fill="${palette.paper}"/>${first ? `<rect width="${width}" height="${coverHeight}" fill="${palette.night}"/><rect width="10" height="${coverHeight}" fill="${palette.purple}"/>${wheel}${star(width - 91, 114, 18, palette.paleGold)}${star(width - 132, 77, 6, palette.paleGold)}` : `<line x1="52" y1="49" x2="${width - 52}" y2="49" stroke="${palette.line}" stroke-width=".5"/>${star(width - 63, 74, 7, palette.line)}`}<line x1="52" y1="${height - 43}" x2="${width - 52}" y2="${height - 43}" stroke="${palette.line}" stroke-width=".5"/></svg>`;
}

function panel(content: Content[], fill = palette.lavender, accent = palette.gold, compact = false): Content {
  return {
    table: { widths: ["*"], body: [[{ stack: content, fillColor: fill, border: [true, false, false, false] }]] },
    layout: { hLineWidth: () => 0, vLineWidth: index => index === 0 ? 2 : 0, vLineColor: () => accent,
      paddingLeft: () => 14, paddingRight: () => 14, paddingTop: () => compact ? 7 : 12, paddingBottom: () => compact ? 7 : 12 },
    margin: [0, compact ? 8 : 10, 0, compact ? 8 : 12],
  };
}

function edition(report: LifeReport, labels: LifeLabels): string {
  if (report.access !== "full" || report.full_state !== "ready") return labels.previewVersion;
  const language = report.input.profile.language;
  if (language === "zh") return "完整报告";
  if (language === "th") return "ฉบับเต็ม";
  return additionalLocales[language].reportContent.fullVersion;
}

function reportNumber(report: LifeReport): string {
  return report.claim_code || report.id.slice(0, 12).toUpperCase();
}

function marriagePdfBirthDetails(report: LifeReport, labels: LifeLabels): string {
  if (report.format !== "thai-marriage" || report.access !== "full" || report.full_state !== "ready") return "";
  const { birth_date, birth_time, birthplace } = report.input.profile;
  return [birth_date, birth_time || labels.timeUnknown, birthplace].filter(Boolean).join(" · ");
}

function reportHeader(report: LifeReport, labels: LifeLabels): Content[] {
  if (report.format === "western-personal" || report.format === "thai-marriage") {
    const header: Content[] = [
      { text: "FATE", color: palette.paleGold, characterSpacing: 2.2, fontSize: 9, margin: [0, 0, 0, 10] },
      { text: textRuns(labels.title), fontSize: 26, color: "#FFF5DF", lineHeight: 1.15, margin: [0, 0, 0, report.input.profile.language === "my" ? 104 : 54] },
    ];
    const birthDetails = marriagePdfBirthDetails(report, labels);
    if (birthDetails) {
      header.push({ text: textRuns(birthDetails), fontSize: 10.5, color: palette.ink, lineHeight: 1.4, margin: [0, 0, 0, 8] });
    }
    return header;
  }
  const profile = report.input.profile;
  const language = profile.language;
  const version = edition(report, labels);
  const created = new Intl.DateTimeFormat(localeTag(language), { dateStyle: "long", calendar: "gregory", timeZone: profile.timezone }).format(new Date(report.created_at));
  const label = (value: string): Content => ({ text: textRuns(value), fontSize: 8, color: palette.gold, margin: [0, 0, 0, 5] });
  const value = (value: string, size = 10.5): Content => ({ text: textRuns(value), fontSize: size, color: palette.ink, lineHeight: 1.3, margin: [0, 0, 0, 4] });
  return [
    { columns: [
      { text: "FATE", color: palette.paleGold, characterSpacing: 2.2, fontSize: 9 },
      { text: textRuns(version), width: 140, alignment: "right", fontSize: 9, color: palette.paleGold },
    ], margin: [0, 0, 0, 16] },
    { text: textRuns(labels.title), fontSize: 34, color: "#FFF5DF", lineHeight: 1.15 },
    { text: textRuns(labels.subtitle), fontSize: 10.5, color: "#D1C1DD", margin: [0, 12, 75, 45], lineHeight: 1.4 },
    { table: { widths: ["*", 148], dontBreakRows: true, body: [
      [
        { stack: [label(labels.birth), value(`${profile.birth_date} · ${profile.birth_time || labels.timeUnknown}`, 12), value(profile.birthplace), { text: textRuns(profile.timezone), fontSize: 8.5, color: palette.muted }] },
        { stack: [label(labels.number), value(reportNumber(report)), label(labels.created), value(created)] },
      ],
      [{ colSpan: 2, stack: [
        { text: [...textRuns(`${labels.name}  `), ...textRuns(profile.display_name || labels.defaultName, true)], fontSize: 9.5, color: palette.ink, margin: [0, 0, 0, 6] },
        ...(report.format === "western-compact" ? [] : [{ text: textRuns(`${labels.method}  ${labels.methodValue}`), fontSize: 9.5, color: palette.ink }]),
        { text: textRuns(`${labels.timeRange}  ${reportReference(report, labels)}`), fontSize: 9, color: palette.muted, margin: [0, 6, 0, 0] },
      ] }, {}],
    ] }, fillColor: "#FFFFFF", layout: { hLineWidth: () => .5, vLineWidth: (index) => index === 1 ? 0 : .5,
      hLineColor: () => palette.line, vLineColor: () => palette.line,
      paddingLeft: () => 15, paddingRight: () => 15, paddingTop: () => 12, paddingBottom: () => 12 }, margin: [0, 0, 0, 10] },
    ...(!profile.birth_time ? [panel([{ text: textRuns(ui[language].timeNote), fontSize: 9, color: palette.muted, lineHeight: 1.35 }], "#F7F0E5")] : []),
  ];
}

function pdfDefinition(report: LifeReport, labels: LifeLabels): TDocumentDefinitions {
  // Parse the existing, escaped export template; never serialize the raw report into the PDF.
  const document = new DOMParser().parseFromString(reportHtml(report, labels), "text/html");
  const full = report.access === "full" && report.full_state === "ready";
  const sections = reportContent(report);
  const personal = report.format === "western-personal" || report.format === "thai-marriage";
  const compact = personal || report.format === "western-compact";
  const paidTitles = new Set(sections.filter(section => section.paid).map(section => section.title));
  let evidenceNoteShown = false;
  function blocks(element: Element, evidence = false): Content[] {
    const tag = element.tagName;
    const children = (): Content[] => {
      const nodes = Array.from(element.children);
      const personalNode = personal && element.classList.contains("personal-node");
      if (tag === "ARTICLE") return nodes.flatMap(child => blocks(child, evidence));
      const content: Content[] = [];
      for (let index = 0; index < nodes.length; index++) {
        if (!/^H[1-5]$/.test(nodes[index].tagName)) { content.push(...blocks(nodes[index], evidence)); continue; }
        let end = index;
        while (end < nodes.length && /^H[1-5]$/.test(nodes[end].tagName) && (!personalNode || end === index)) end++;
        const headings = nodes.slice(index, end).flatMap(node => blocks(node, evidence));
        const next = nodes[end];
        if (personalNode && nodes[index].tagName === "H4" && next?.tagName === "P") {
          content.push({ text: [...inline(nodes[index], true), ...textRuns(report.input.profile.language === "zh" ? "：" : ": "), ...inline(next)], fontSize: 10.5, lineHeight: 1.35, margin: [0, 6, 0, 0] });
          index = end;
          continue;
        }
        if (next?.tagName === "P") {
          content.push({ stack: [...headings, ...blocks(next, evidence)], unbreakable: true });
          index = end;
        } else if (next?.tagName === "ARTICLE") {
          const article = blocks(next, evidence)[0] as ContentStack;
          content.push(article.unbreakable ? { stack: [...headings, article], unbreakable: true } : {
            ...article, stack: [{ stack: [...headings, article.stack[0]], unbreakable: true }, ...article.stack.slice(1)],
          });
          index = end;
        } else if (next?.tagName === "OL") {
          const list = blocks(next, evidence)[0] as ContentOrderedList;
          // Keep ordinary action lists with their title, while allowing unusually long lists to flow.
          if (list.ol.length <= 6 && (next.textContent?.length || 0) <= 900) {
            content.push({ stack: [...headings, list], unbreakable: true });
          } else {
            content.push({ stack: [...headings, { ...list, ol: list.ol.slice(0, 1) }], unbreakable: true });
            if (list.ol.length > 1) content.push({ ...list, ol: list.ol.slice(1), start: 2, margin: [14, 0, 0, 0] });
          }
          index = end;
        } else {
          content.push(...headings);
          index = end - 1;
        }
      }
      return content;
    };
    if (/^H[1-5]$/.test(tag)) {
      const level = Number(tag.slice(1));
      if (level === 2 && element.parentElement?.tagName === "SECTION") {
        const index = sections.findIndex(section => section.title === element.textContent);
        return [{ stack: [
          { columns: [
            { text: index > 0 ? String(index).padStart(2, "0") : "", width: personal ? 28 : 34, color: palette.gold, fontSize: personal ? 14 : 17 },
            { text: inline(element), fontSize: personal ? 16 : 19, color: palette.night },
          ], columnGap: 8 },
          { canvas: [{ type: "line", x1: 0, y1: 0, x2: 491, y2: 0, lineWidth: .5, lineColor: palette.line }], margin: personal ? [0, 5, 0, 7] : [0, 9, 0, 12] },
        ], margin: [0, personal ? 9 : 17, 0, 0], headlineLevel: 1 }];
      }
      if (level === 4 && element.parentElement?.tagName === "ARTICLE") {
        const articles = Array.from(element.closest("section")?.querySelectorAll("article") || []);
        const index = articles.indexOf(element.parentElement) + 1;
        return [{ text: [
          { text: `${String(index).padStart(2, "0")}   `, color: palette.gold, fontSize: personal ? 11 : 15 },
          ...inline(element),
        ], fontSize: personal ? 11.5 : 13.5, color: palette.purple, margin: personal ? [0, 6, 0, 2] : [0, 12, 0, 3], headlineLevel: 1 }];
      }
      return [{ text: inline(element), fontSize: (personal ? [0, 26, 16, 12, 11, 10] : [0, 27, 19, 13.5, 12, 10])[level], color: level < 4 ? palette.purple : palette.ink, margin: [0, personal ? 4 : level < 3 ? 16 : 12, 0, 0], headlineLevel: 1 }];
    }
    if (tag === "P" || tag === "SUMMARY") {
      const label = element.classList.contains("label") || tag === "SUMMARY";
      if (personal && element.classList.contains("personal-signs")) return [{ text: inline(element), fontSize: 17, bold: true, color: palette.purple, margin: [0, 3, 0, 5] }];
      if (personal && element.classList.contains("personal-keywords")) return [{ text: inline(element), fontSize: 10, color: palette.gold, margin: [0, 2, 0, 4] }];
      if (element.classList.contains("takeaway")) return [panel([{ text: inline(element), fontSize: 12, color: palette.purple, lineHeight: 1.45 }])];
      return [{ text: inline(element), fontSize: evidence ? 8.5 : label ? 9 : 10.5, color: evidence ? palette.muted : label ? palette.gold : palette.ink, margin: [0, personal ? 4 : evidence ? 5 : 9, 0, 0], lineHeight: personal ? 1.35 : 1.5 }];
    }
    if (tag === "UL" || tag === "OL") {
      const items = Array.from(element.children).map(item => ({ text: inline(item), margin: [0, 6, 0, 0] as [number, number, number, number] }));
      const keepSteps = items.length <= 6 && (element.textContent?.length || 0) <= 900;
      return [tag === "OL" ? { ol: items, unbreakable: keepSteps, margin: [14, 8, 0, 0] } : { ul: items, margin: [14, 8, 0, 0] }];
    }
    if (tag === "SECTION") {
      const title = element.querySelector(":scope > h2")?.textContent || "";
      if (!full && title === labels.catalog) return [];
      if (compact && title === labels.catalog) {
        return [{ stack: [
          { text: textRuns(title), fontSize: 19, color: palette.purple, margin: [0, 0, 0, 18] },
          ...sections.map((section, index): Content => ({ columns: [
            { text: String(index + 1).padStart(2, "0"), width: 26, color: palette.gold, fontSize: 11 },
            { stack: [
              { text: textRuns(section.title), fontSize: 12, color: palette.ink },
              { text: textRuns(section.description), fontSize: 9, color: palette.muted, margin: [0, 4, 0, 0] },
            ] },
          ], columnGap: 8, margin: [0, 0, 0, 14] })),
        ] }];
      }
      // Short Western sections flow together so a brief chapter tail cannot occupy a whole page.
      const firstPaid = sections.find(section => section.paid)?.title;
      const pageBreak = !personal && full && (compact ? title === firstPaid : paidTitles.has(title) || title === labels.catalog) ? "before" as const : undefined;
      return [{ stack: children(), pageBreak, margin: [0, personal ? 0 : 4, 0, 0] }];
    }
    if (tag === "DETAILS") {
      const facts = Array.from(element.children).filter(child => child.textContent !== labels.evidenceHint);
      if (!facts.some(child => child.tagName === "P" && child.textContent?.trim())) return [];
      const lines = facts.flatMap((child, index) => [...(index ? textRuns("\n") : []), ...inline(child)]);
      const content: Content[] = [{ text: lines, fontSize: 8, color: palette.muted, lineHeight: 1.25 }];
      if (!evidenceNoteShown) {
        content.push({ text: textRuns(labels.evidenceHint), fontSize: 8, color: palette.muted, lineHeight: 1.25, margin: [0, 6, 0, 0] });
        evidenceNoteShown = true;
      }
      return [panel(content, "#F5F1F5", palette.line, true)];
    }
    if (tag === "HEADER") return reportHeader(report, labels);
    if (tag === "ARTICLE") {
      const content = children();
      if (personal && element.classList.contains("personal-node")) return [{ stack: content, unbreakable: true, margin: [0, 3, 0, 0] }];
      if (personal && element.classList.contains("personal-free-zone")) {
        return [{ stack: [panel(content, element.classList.contains("personal-free-opportunity") ? "#F8EBD2" : palette.lavender, palette.gold, true)], unbreakable: true }];
      }
      if (content.length <= 3) return [{ stack: content, unbreakable: true, margin: [0, personal ? 3 : 6, 0, 0] }];
      return [{ stack: [
        { stack: content.slice(0, 2), unbreakable: true },
        ...content.slice(2, -2),
        { stack: content.slice(-2), unbreakable: true },
      ], margin: [0, 6, 0, 0] }];
    }
    if (tag === "FOOTER") return [];
    return children();
  }
  return {
    pageSize: "A4", pageMargins: personal ? [52, 52, 52, 48] : [52, 62, 52, 62],
    info: { title: labels.title, author: "FATE", subject: full ? labels.fullVersion : labels.previewVersion, keywords: `${report.method.version} / ${report.version}` },
    defaultStyle: { font: "NotoChinese", fontSize: 10.5, color: palette.ink, lineHeight: 1.5 },
    // Stacked Myanmar marks require a taller title band to retain subtitle contrast.
    background: (page, size) => ({ svg: pageArtwork(size.width, size.height, page === 1, personal ? report.input.profile.language === "my" ? 206 : 156 : report.input.profile.language === "my" ? 250 : 194), width: size.width, height: size.height }),
    header: page => page === 1 ? [] : ({ columns: [
      { text: "FATE", characterSpacing: 1.5, color: palette.gold },
      { text: textRuns(`${labels.title} · ${edition(report, labels)}`), alignment: "right", color: palette.muted },
    ], fontSize: 8, margin: [52, 27, 52, 0] }),
    content: Array.from(document.body.children).flatMap(element => blocks(element)),
    footer: (page, count) => ({ columns: [
      { text: textRuns(`FATE  /  ${reportNumber(report)}`) },
      { text: `${page} / ${count}`, alignment: "right" },
    ], fontSize: 7.5, color: palette.muted, margin: [52, personal ? 20 : 32, 52, 0] }),
  };
}

async function fontData(filename: string): Promise<string> {
  const url = new URL(`../fonts/pdf/${filename}`, import.meta.url);
  let blob: Blob | undefined;
  for (const cache of ["force-cache", "reload"] as const) {
    try {
      const response = await fetch(url, { cache });
      if (response.ok) {
        const data = await response.blob();
        if (data.size) {
          blob = data;
          break;
        }
      } else if (response.status < 500 && response.status !== 408 && response.status !== 429) {
        break;
      }
    } catch {
      // A connection can also fail while receiving the response body.
    }
  }
  if (!blob) throw new Error("PDF_font_unavailable");
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(new Error("PDF_font_unavailable"));
    reader.onload = () => resolve(String(reader.result).split(",")[1]);
    reader.readAsDataURL(blob);
  });
}

function pdfEngine(): Promise<PdfEngine> {
  if (!engine) engine = Promise.all([
    import("pdfmake/build/pdfmake").catch(() => { throw new Error("PDF_engine_unavailable"); }),
    fontData("NotoSansSC-Regular.ttf"), fontData("NotoSansThai-Regular.ttf"),
  ]).then(([module, chinese, thai]) => {
    const pdf = module.default;
    pdf.addVirtualFileSystem({ "Chinese.ttf": chinese, "Thai.ttf": thai });
    pdf.addFonts(Object.fromEntries([["NotoChinese", "Chinese.ttf"], ["NotoThai", "Thai.ttf"]].map(([family, filename]) => [family, { normal: filename, bold: filename, italics: filename, bolditalics: filename }])));
    return pdf;
  }).catch(cause => { engine = undefined; throw cause; });
  return engine;
}

const regionalFontLoads = new Map<string, Promise<void>>();
async function ensureRegionalPdfFonts(pdf: PdfEngine, report: LifeReport, labels: LifeLabels) {
  const content = reportHtml(report, labels) + marriagePdfBirthDetails(report, labels);
  await Promise.all(regionalFonts.filter(item => item.script.test(content)).map(item => {
    if (!regionalFontLoads.has(item.font)) {
      const pending = fontData(item.file).then(data => {
        pdf.addVirtualFileSystem({ [item.file]: data });
        pdf.addFonts({ [item.font]: { normal: item.file, bold: item.file, italics: item.file, bolditalics: item.file } });
      }).catch(error => { regionalFontLoads.delete(item.font); throw error; });
      regionalFontLoads.set(item.font, pending);
    }
    return regionalFontLoads.get(item.font)!;
  }));
}

export type ReportPdfOptions = { showSaveDialog?: boolean };

export async function saveReportPdf(
  report: LifeReport, labels: LifeLabels, signal: AbortSignal, { showSaveDialog = true }: ReportPdfOptions = {},
): Promise<"saved" | "downloaded" | "cancelled"> {
  const full = report.access === "full" && report.full_state === "ready";
  const id = (report.claim_code || report.id).replace(/[^a-zA-Z0-9_-]/g, "").slice(0, 48) || "report";
  const fullFilename = report.format === "thai-marriage" && report.input.profile.language === "zh"
    ? "FATE完整婚姻关系报告.pdf"
    : `FATE-${edition(report, labels)}.pdf`;
  const filename = full && !report.claim_code ? fullFilename : `Life-Report-${id}-${full ? "full" : "preview"}.pdf`;
  signal.throwIfAborted();
  const pdf = await pdfEngine();
  await ensureRegionalPdfFonts(pdf, report, labels);
  signal.throwIfAborted();
  const blob = await pdf.createPdf(pdfDefinition(report, labels)).getBlob();
  if (await blob.slice(0, 5).text() !== "%PDF-") throw new Error("PDF_invalid_output");
  signal.throwIfAborted();

  const picker = showSaveDialog && (window as SaveWindow).showSaveFilePicker;
  if (picker && navigator.userActivation?.isActive !== false) {
    let handle: FileSystemFileHandle | undefined;
    try {
      handle = await picker.call(window, { id: "astro-life-report-pdf", suggestedName: filename, excludeAcceptAllOption: true, types: [{ description: "PDF", accept: { "application/pdf": [".pdf"] } }] });
    } catch (cause) {
      if (cause instanceof DOMException && cause.name === "AbortError") return "cancelled";
      // The browser can block the file picker even when it exposes the API.
    }
    if (handle) {
      signal.throwIfAborted();
      let writable: FileSystemWritableFileStream | undefined;
      try {
        writable = await handle.createWritable();
        signal.throwIfAborted();
        await writable.write(blob);
        await writable.close();
        if ((await handle.getFile()).size === blob.size) return "saved";
      } catch {
        await writable?.abort().catch(() => undefined);
        // A restricted or failed file write can still be recovered by downloading the PDF.
      }
    }
  }
  signal.throwIfAborted();
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url; anchor.download = filename;
  document.body.append(anchor); anchor.click(); anchor.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
  return "downloaded";
}
