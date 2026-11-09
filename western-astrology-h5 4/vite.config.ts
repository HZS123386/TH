import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { fileURLToPath } from "node:url";

export default defineConfig({
  root: "dist",
  base: "./",
  plugins: [react()],
  build: {
    outDir: "../site", emptyOutDir: true,
    rollupOptions: { input: {
      landing: fileURLToPath(new URL("./dist/index.html", import.meta.url)),
      report: fileURLToPath(new URL("./dist/report.html", import.meta.url)),
    } },
  },
  server: {
    // Development uses the same API as the existing Thai reading page.
    proxy: {
      "/api": "http://127.0.0.1:8000",
      "/health": "http://127.0.0.1:8000",
    },
  },
});
