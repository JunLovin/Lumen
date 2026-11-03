import type { MediaAsset } from '../domain/media';
import { createLoadGalleryPage, GALLERY_PAGE_SIZE } from './load-gallery-page';

const asset = (id: string): MediaAsset => ({
  id,
  width: 1,
  height: 1,
  mediaType: 'photo',
});

describe('loadGalleryPage', () => {
  it('asks for the next page and appends it', async () => {
    const fetchAssets = jest.fn(() => Promise.resolve([asset('b')]));
    const load = createLoadGalleryPage({
      readAccess: () => Promise.resolve('authorized'),
      requestAccess: () => Promise.resolve('authorized'),
      fetchAssets,
      loadThumbnail: () => Promise.resolve(null),
      manageLimitedAccess: () => undefined,
      beginDragTransfer: () => undefined,
    });
    await expect(load([asset('a')])).resolves.toEqual([asset('a'), asset('b')]);
    expect(fetchAssets).toHaveBeenCalledWith(1, GALLERY_PAGE_SIZE);
  });
});
