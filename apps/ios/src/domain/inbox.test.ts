import {
  formatByteCount,
  isPreviewableImage,
  receivingFraction,
  type ReceivedFile,
} from './inbox';

const file = (name: string, isDirectory = false): ReceivedFile => ({
  name,
  uri: `file:///${name}`,
  isDirectory,
  byteCount: 0,
});

describe('isPreviewableImage', () => {
  it('recognizes images regardless of case', () => {
    expect(isPreviewableImage(file('IMG.HEIC'))).toBe(true);
  });

  it('rejects documents and folders', () => {
    expect(isPreviewableImage(file('a.pdf'))).toBe(false);
    expect(isPreviewableImage(file('a.png', true))).toBe(false);
  });
});

describe('receivingFraction', () => {
  it('is null when nothing is arriving', () => {
    expect(
      receivingFraction({ files: [], receivedBytes: 0, totalBytes: 0 }),
    ).toBeNull();
  });

  it('reports progress', () => {
    expect(
      receivingFraction({ files: [], receivedBytes: 1, totalBytes: 4 }),
    ).toBe(0.25);
  });
});

describe('formatByteCount', () => {
  it('picks a readable unit', () => {
    expect(formatByteCount(512)).toBe('512 B');
    expect(formatByteCount(1536)).toBe('1.5 KB');
    expect(formatByteCount(5 * 1024 * 1024)).toBe('5.0 MB');
  });
});
