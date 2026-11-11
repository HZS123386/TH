import type { Content, ContentOrderedList, ContentStack, ContentText, TDocumentDefinitions } from "pdfmake/interfaces";
import type { LifeLabels, LifeReport } from "./lifeReport";
import { reportHtml, ui } from "./reading";
import { reportContent, reportReference } from "./reportContent";

type PdfEngine = typeof import("pdfmake/build/pdfmake");
type SaveWindow = Window & { showSaveFilePicker?: (options: {
  id: string; suggestedName: string; excludeAcceptAllOption: boolean;
  types: { description: string; accept: Record<string, string[]> }[];
}) => Promise<FileSystemFileHandle> };

let engine: Promise<PdfEngine> | undefined;
const thaiWords = typeof Intl.Segmenter === "function" ? new Intl.Segmenter("th", { granularity: "word" }) : undefined;

function textRuns(value: string, bold = false): ContentText[] {
  const text = value.replace(/[\u2010-\u2015\u2212]/g, "-");
  return (text.match(/[\u0e00-\u0e7f]+|[^\u0e00-\u0e7f]+/gu) || []).map(part => {
    const thai = /[\u0e00-\u0e7f]/u.test(part);
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
function pageArtwork(width: number, height: number, first: boolean): string {
  const centerX = width - 42, centerY = 100;
  const ticks = Array.from({ length: 48 }, (_, i) => {
    const angle = i * Math.PI / 24;
    const inner = i % 4 ? 103 : 96;
    return `<line x1="${centerX + Math.cos(angle) * inner}" y1="${centerY + Math.sin(angle) * inner}" x2="${centerX + Math.cos(angle) * 108}" y2="${centerY + Math.sin(angle) * 108}"/>`;
  }).join("");
  const wheel = `<g stroke="${palette.paleGold}" stroke-opacity=".2" fill="none" stroke-width=".6"><circle cx="${centerX}" cy="${centerY}" r="108"/><circle cx="${centerX}" cy="${centerY}" r="91"/><circle cx="${centerX}" cy="${centerY}" r="62"/>${ticks}<ellipse cx="${centerX}" cy="${centerY}" rx="125" ry="32" transform="rotate(-28 ${centerX} ${centerY})"/></g>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}"><rect width="${width}" height="${height}" fill="${palette.paper}"/>${first ? `<rect width="${width}" height="194" fill="${palette.night}"/><rect width="10" height="194" fill="${palette.purple}"/>${wheel}${star(width - 91, 114, 18, palette.paleGold)}${star(width - 132, 77, 6, palette.paleGold)}` : `<line x1="52" y1="49" x2="${width - 52}" y2="49" stroke="${palette.line}" stroke-width=".5"/>${star(width - 63, 74, 7, palette.line)}`}<line x1="52" y1="${height - 43}" x2="${width - 52}" y2="${height - 43}" stroke="${palette.line}" stroke-width=".5"/></svg>`;
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
  return report.access === "full" && report.full_state === "ready"
    ? report.input.profile.language === "zh" ? "完整报告" : "ฉบับเต็ม"
    : labels.previewVersion;
}

function reportHeader(report: LifeReport, labels: LifeLabels): Content[] {
  const profile = report.input.profile;
  const language = profile.language;
  const version = edition(report, labels);
  const created = new Intl.DateTimeFormat(language === "zh" ? "zh-CN" : "th-TH", { dateStyle: "long", calendar: "gregory", timeZone: profile.timezone }).format(new Date(report.created_at));
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
        { stack: [label(labels.number), value(report.id.slice(0, 12).toUpperCase()), label(labels.created), value(created)] },
      ],
      [{ colSpan: 2, stack: [
        { text: [...textRuns(`${labels.name}  `), ...textRuns(profile.display_name || labels.defaultName, true)], fontSize: 9.5, color: palette.ink, margin: [0, 0, 0, 6] },
        { text: textRuns(`${labels.method}  ${labels.methodValue}`), fontSize: 9.5, color: palette.ink },
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
  const compact = report.format === "western-compact";
  const paidTitles = new Set(sections.filter(section => section.paid).map(section => section.title));
  let evidenceNoteShown = false;
  function blocks(element: Element, evidence = false): Content[] {
    const tag = element.tagName;
    const children = (): Content[] => {
      const nodes = Array.from(element.children);
      if (tag === "ARTICLE") return nodes.flatMap(child => blocks(child, evidence));
      const content: Content[] = [];
      for (let index = 0; index < nodes.length; index++) {
        if (!/^H[1-5]$/.test(nodes[index].tagName)) { content.push(...blocks(nodes[index], evidence)); continue; }
        let end = index;
        while (end < nodes.length && /^H[1-5]$/.test(nodes[end].tagName)) end++;
        const headings = nodes.slice(index, end).flatMap(node => blocks(node, evidence));
        const next = nodes[end];
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
            { text: index > 0 ? String(index).padStart(2, "0") : "", width: 34, color: palette.gold, fontSize: 17 },
            { text: inline(element), fontSize: 19, color: palette.night },
          ], columnGap: 8 },
          { canvas: [{ type: "line", x1: 0, y1: 0, x2: 491, y2: 0, lineWidth: .5, lineColor: palette.line }], margin: [0, 9, 0, 12] },
        ], margin: [0, 17, 0, 0], headlineLevel: 1 }];
      }
      if (level === 4 && element.parentElement?.tagName === "ARTICLE") {
        const articles = Array.from(element.closest("section")?.querySelectorAll("article") || []);
        const index = articles.indexOf(element.parentElement) + 1;
        return [{ text: [
          { text: `${String(index).padStart(2, "0")}   `, color: palette.gold, fontSize: 15 },
          ...inline(element),
        ], fontSize: 13.5, color: palette.purple, margin: [0, 12, 0, 3], headlineLevel: 1 }];
      }
      return [{ text: inline(element), fontSize: [0, 27, 19, 13.5, 12, 10][level], color: level < 4 ? palette.purple : palette.ink, margin: [0, level < 3 ? 16 : 12, 0, 0], headlineLevel: 1 }];
    }
    if (tag === "P" || tag === "SUMMARY") {
      const label = element.classList.contains("label") || tag === "SUMMARY";
      if (element.classList.contains("takeaway")) return [panel([{ text: inline(element), fontSize: 12, color: palette.purple, lineHeight: 1.45 }])];
      return [{ text: inline(element), fontSize: evidence ? 8.5 : label ? 9 : 10.5, color: evidence ? palette.muted : label ? palette.gold : palette.ink, margin: [0, evidence ? 5 : 9, 0, 0], lineHeight: 1.5 }];
    }
    if (tag === "UL" || tag === "OL") {
      const items = Array.from(element.children).map(item => ({ text: inline(item), margin: [0, 6, 0, 0] as [number, number, number, number] }));
      return [tag === "OL" ? { ol: items, margin: [14, 8, 0, 0] } : { ul: items, margin: [14, 8, 0, 0] }];
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
        ], pageBreak: "before" }];
      }
      // Short Western sections flow together so a brief chapter tail cannot occupy a whole page.
      const firstPaid = sections.find(section => section.paid)?.title;
      const pageBreak = full && (compact ? title === firstPaid : paidTitles.has(title) || title === labels.catalog) ? "before" as const : undefined;
      return [{ stack: children(), pageBreak, margin: [0, 4, 0, 0] }];
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
      if (content.length <= 3) return [{ stack: content, unbreakable: true, margin: [0, 6, 0, 0] }];
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
    pageSize: "A4", pageMargins: [52, 62, 52, 62],
    info: { title: labels.title, author: "FATE", subject: full ? labels.fullVersion : labels.previewVersion, keywords: `${report.method.version} / ${report.version}` },
    defaultStyle: { font: "NotoChinese", fontSize: 10.5, color: palette.ink, lineHeight: 1.5 },
    background: (page, size) => ({ svg: pageArtwork(size.width, size.height, page === 1), width: size.width, height: size.height }),
    header: page => page === 1 ? [] : ({ columns: [
      { text: "FATE", characterSpacing: 1.5, color: palette.gold },
      { text: textRuns(`${labels.title} · ${edition(report, labels)}`), alignment: "right", color: palette.muted },
    ], fontSize: 8, margin: [52, 27, 52, 0] }),
    content: Array.from(document.body.children).flatMap(element => blocks(element)),
    footer: (page, count) => ({ columns: [
      { text: textRuns(`FATE  /  ${report.id.slice(0, 12).toUpperCase()}`) },
      { text: `${page} / ${count}`, alignment: "right" },
    ], fontSize: 7.5, color: palette.muted, margin: [52, 32, 52, 0] }),
  };
}

async function fontData(filename: string): Promise<string> {
  const response = await fetch(new URL(`fonts/pdf/${filename}`, document.baseURI), { cache: "force-cache" });
  if (!response.ok) throw new Error("PDF_font_unavailable");
  const blob = await response.blob();
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(new Error("PDF_font_unavailable"));
    reader.onload = () => resolve(String(reader.result).split(",")[1]);
    reader.readAsDataURL(blob);
  });
}

function pdfEngine(): Promise<PdfEngine> {
  if (!engine) engine = Promise.all([
    import("pdfmake/build/pdfmake"), fontData("NotoSansSC-Regular.ttf"), fontData("NotoSansThai-Regular.ttf"),
  ]).then(([module, chinese, thai]) => {
    const pdf = module.default;
    pdf.addVirtualFileSystem({ "Chinese.ttf": chinese, "Thai.ttf": thai });
    pdf.addFonts(Object.fromEntries([["NotoChinese", "Chinese.ttf"], ["NotoThai", "Thai.ttf"]].map(([family, filename]) => [family, { normal: filename, bold: filename, italics: filename, bolditalics: filename }])));
    return pdf;
  }).catch(cause => { engine = undefined; throw cause; });
  return engine;
}

export async function saveReportPdf(report: LifeReport, labels: LifeLabels, signal: AbortSignal): Promise<"saved" | "downloaded" | "cancelled"> {
  const full = report.access === "full" && report.full_state === "ready";
  const id = report.id.replace(/[^a-zA-Z0-9_-]/g, "").slice(0, 48) || "report";
  const filename = `Life-Report-${id}-${full ? "full" : "preview"}.pdf`;
  let handle: FileSystemFileHandle | undefined;
  const picker = (window as SaveWindow).showSaveFilePicker;
  if (picker) {
    try {
      // Open during the click's user activation, before loading the PDF engine or fonts.
      handle = await picker.call(window, { id: "astro-life-report-pdf", suggestedName: filename, excludeAcceptAllOption: true, types: [{ description: "PDF", accept: { "application/pdf": [".pdf"] } }] });
    } catch (cause) {
      if (cause instanceof DOMException && cause.name === "AbortError") return "cancelled";
      if (!(cause instanceof DOMException && cause.name === "SecurityError")) throw cause;
    }
  }
  signal.throwIfAborted();
  const pdf = await pdfEngine();
  signal.throwIfAborted();
  const blob = await pdf.createPdf(pdfDefinition(report, labels)).getBlob();
  signal.throwIfAborted();
  if (handle) {
    const writable = await handle.createWritable();
    try { await writable.write(blob); await writable.close(); }
    catch (cause) { await writable.abort().catch(() => undefined); throw cause; }
    return "saved";
  }
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url; anchor.download = filename;
  document.body.append(anchor); anchor.click(); anchor.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
  return "downloaded";
}
