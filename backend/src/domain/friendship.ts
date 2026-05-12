export type FriendshipStatus = 'pending' | 'accepted' | 'blocked';

export interface Friendship {
  requesterId: string;
  addresseeId: string;
  status: FriendshipStatus;
  createdAt: Date;
}
