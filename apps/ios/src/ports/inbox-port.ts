import type { Inbox } from '../domain/inbox';

export interface InboxPort {
  read(): Promise<Inbox>;
  delete(name: string): void;
  pickFilesToSend(): void;
}
