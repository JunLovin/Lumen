export type ReceivedFile = {
  readonly name: string;
  readonly uri: string;
  readonly isDirectory: boolean;
  readonly byteCount: number;
};

export type Inbox = {
  readonly files: readonly ReceivedFile[];
  readonly receivedBytes: number;
  readonly totalBytes: number;
};

const IMAGE_EXTENSIONS = ['heic', 'heif', 'jpg', 'jpeg', 'png', 'gif', 'webp'];

export const isPreviewableImage = (file: ReceivedFile): boolean => {
  const extension = file.name.split('.').at(-1)?.toLowerCase() ?? '';
  return !file.isDirectory && IMAGE_EXTENSIONS.includes(extension);
};

export const receivingFraction = (inbox: Inbox): number | null =>
  inbox.totalBytes > 0
    ? Math.min(inbox.receivedBytes / inbox.totalBytes, 1)
    : null;

const KILOBYTE = 1024;
const SIZE_UNITS = ['B', 'KB', 'MB', 'GB'];

export const formatByteCount = (bytes: number): string => {
  let value = bytes;
  let unit = 0;
  while (value >= KILOBYTE && unit < SIZE_UNITS.length - 1) {
    value /= KILOBYTE;
    unit += 1;
  }
  return `${unit === 0 ? value : value.toFixed(1)} ${SIZE_UNITS[unit]}`;
};
