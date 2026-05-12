import type { Config } from 'drizzle-kit';

// drizzle-kit commands that require a connection (migrate, studio, introspect)
// will surface their own "missing credentials" error. Keeping this config
// lenient means `generate` still works without DATABASE_URL in the environment.
export default {
  schema: './src/infrastructure/db/schema.ts',
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: { url: process.env.DATABASE_URL ?? '' },
  casing: 'snake_case',
} satisfies Config;
