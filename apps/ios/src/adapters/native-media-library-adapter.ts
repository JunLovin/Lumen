import type { LibraryAccess } from '../domain/media';
import type { MediaLibraryPort } from '../ports/media-library-port';
import NativeLumenKit from './native/NativeLumenKit';

const ACCESS_LEVELS: readonly LibraryAccess[] = [
  'authorized',
  'limited',
  'denied',
  'undetermined',
];

const toAccess = (access: string): LibraryAccess =>
  ACCESS_LEVELS.find(level => level === access) ?? 'denied';

export const createNativeMediaLibraryAdapter = (): MediaLibraryPort => ({
  readAccess: async () => toAccess(NativeLumenKit.libraryAccess()),
  requestAccess: async () =>
    toAccess(await NativeLumenKit.requestLibraryAccess()),
  fetchAssets: async (offset, limit) => {
    const assets = await NativeLumenKit.fetchLibraryAssets(offset, limit);
    return assets.map(asset => ({
      ...asset,
      mediaType: asset.mediaType === 'video' ? 'video' : 'photo',
    }));
  },
  loadThumbnail: (assetId, size) => NativeLumenKit.loadThumbnail(assetId, size),
  manageLimitedAccess: () => NativeLumenKit.manageLimitedLibrary(),
  beginDragTransfer: (session, assetId, phoneHeightMillimeters) =>
    NativeLumenKit.beginDrag(session, assetId, phoneHeightMillimeters),
});
