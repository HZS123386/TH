export type Language = 'zh' | 'en' | 'th' | 'vi';
export type ProviderId = 'mock' | 'deepseek' | 'qwen' | 'openai' | 'kimi' | 'companion';
export interface Profile {
  display_name: string;
  gender?: 'female' | 'male' | null;
  birth_date: string;
  birth_time: string | null;
  timezone: string;
  birthplace: string;
  language: Language;
  country_code?: string | null;
  location_id?: string | null;
  latitude?: number | null;
  longitude?: number | null;
}
export interface Chart {
  pillars: Record<'year' | 'month' | 'day' | 'hour', string | null>;
  visible_element_counts: Record<string, number>;
  time_known: boolean;
  engine: string;
  engine_version: string;
  calculation_version: string;
  time_convention: string;
  calculation_time: string | null;
  source: string;
  notes: string[];
}
export interface ProfileRecord {
  profile_id?: string;
  profile: Profile;
  chart: Chart;
  revision: number;
}
export interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  provider: ProviderId;
  created: number;
  evidence?: ChatEvidence;
}
export interface ChatEvidence {
  generation?: {
    mode: 'companion';
    reviewed: boolean;
    response_provider: 'qwen' | 'kimi' | null;
    steps: {
      provider: 'qwen' | 'kimi';
      model?: string;
      role: 'draft' | 'refine' | 'answer';
      status: 'pending' | 'completed' | 'failed' | 'skipped';
    }[];
  };
  profile_revision: number;
  system: string;
  calculated_at: string;
  natal_status: string | null;
  recall: {
    mode: 'recent' | 'semantic' | 'recent-unindexed' | 'recent-unavailable';
    count: number;
    confirmed_count: number;
  };
  fortunes: {
    period: 'today' | 'week' | 'month';
    status?: 'unavailable';
    period_start?: string;
    period_end?: string;
    as_of?: string;
    guidance_version?: string;
    birth?: { basis: string };
    readings?: Record<string, { code: string }>;
  }[];
}
export interface Memory {
  id: string;
  content: string;
  created: number;
  source: 'user_confirmed';
}
export interface Provider {
  id: ProviderId;
  name: string;
  enabled: boolean;
  model: string;
}
export interface Config {
  roxy?: {
    enabled: boolean;
    bazi_provider: string;
    operations: string[];
    per_minute: number;
    per_day: number;
  };
  modules: ExplorationModule[];
  providers: Provider[];
  default_provider: ProviderId;
  demo_login: boolean;
  account_login: boolean;
  liff_id: string | null;
  companion?: {
    source: string;
    commit: string;
    recall: 'semantic' | 'recent';
    real_model_ready: boolean;
  };
}
export interface Account {
  user_id: string;
  username: string;
  kind: 'account';
}
export interface ExplorationModule {
  id: 'bazi' | 'western_astrology' | 'thai_astrology' | 'dreams';
  status: 'ready' | 'planned';
  labels: Record<Language, string>;
  method: string | null;
  calculation_version: string | null;
}
export type StreamEvent =
  | {
      event: 'metadata';
      data: {
        provider: ProviderId;
        model: string;
        profile_revision: number;
        evidence?: ChatEvidence;
      };
    }
  | { event: 'token'; data: { text: string } }
  | { event: 'done'; data: { message_id: string; provider: ProviderId } }
  | { event: 'error'; data: { message: string; saved: false } };
