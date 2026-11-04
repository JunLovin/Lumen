import type { InboxPort } from '../ports/inbox-port';
import NativeLumenKit from './native/NativeLumenKit';

export const createNativeInboxAdapter = (): InboxPort => ({
  read: () => NativeLumenKit.listReceivedFiles(),
  delete: name => NativeLumenKit.deleteReceivedFile(name),
  pickFilesToSend: () => NativeLumenKit.pickFilesToSend(),
});
