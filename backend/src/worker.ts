import { buildContainer, type Container } from './composition';
import type { Env } from './env';
import { createApp } from './presentation/app';

const containerCache = new WeakMap<Env, Container>();

function resolveContainer(env: Env): Container {
  let container = containerCache.get(env);
  if (!container) {
    container = buildContainer(env);
    containerCache.set(env, container);
  }
  return container;
}

const app = createApp(resolveContainer);

export default {
  fetch: app.fetch,
  async scheduled(
    _event: ScheduledController,
    env: Env,
    ctx: ExecutionContext,
  ): Promise<void> {
    const container = resolveContainer(env);
    ctx.waitUntil(container.runDailyAggregate.execute());
  },
} satisfies ExportedHandler<Env>;
