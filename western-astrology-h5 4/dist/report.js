import { createElement } from "react";
import { createRoot } from "react-dom/client";
import { ReportPage } from "../src/components/ReportPage";

createRoot(document.getElementById("report-root")).render(createElement(ReportPage));
