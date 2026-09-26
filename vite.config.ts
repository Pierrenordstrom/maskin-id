import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

// `--mode demo` bygger en fristående demo: alla tillgångar inlinas och hash-routing används
// (se scripts/build-demo.mjs som slår ihop allt till en HTML-fil).
export default defineConfig(({ mode }) => ({
  plugins: [react()],
  base: mode === "demo" ? "./" : "/",
  build:
    mode === "demo"
      ? { outDir: "dist-demo", assetsInlineLimit: Number.MAX_SAFE_INTEGER, cssCodeSplit: false, emptyOutDir: true }
      : undefined,
  test: {
    environment: "node",
    include: ["src/**/*.test.ts"],
  },
}));
