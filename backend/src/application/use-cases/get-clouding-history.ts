import type { CloudingRepository } from '../ports/clouding-repository';
import type { CloudingEntry } from '../../domain/clouding';

export class GetCloudingHistory {
  constructor(private readonly cloudings: CloudingRepository) {}

  async execute(userId: string): Promise<CloudingEntry[]> {
    return this.cloudings.getAllForUser(userId);
  }
}
