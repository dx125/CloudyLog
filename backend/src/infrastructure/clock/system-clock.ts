import type { Clock } from '../../application/ports/clock';

export class SystemClock implements Clock {
  now(): Date {
    return new Date();
  }

  today(): string {
    const d = this.now();
    const yyyy = d.getUTCFullYear();
    const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
    const dd = String(d.getUTCDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }
}
