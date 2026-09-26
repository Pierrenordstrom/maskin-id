/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** "mock" (standard) eller "supabase". */
  readonly VITE_DATA_SOURCE?: "mock" | "supabase";
  readonly VITE_SUPABASE_URL?: string;
  /** Publishable (anon) key – aldrig service role key i frontend. */
  readonly VITE_SUPABASE_PUBLISHABLE_KEY?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
