import type { MediaAsset } from '../domain/media';
import type { MediaLibraryPort } from '../ports/media-library-port';

export const GALLERY_PAGE_SIZE = 90;

export type LoadGalleryPage = (
  current: readonly MediaAsset[],
) => Promise<readonly MediaAsset[]>;

export const createLoadGalleryPage =
  (library: MediaLibraryPort): LoadGalleryPage =>
  async current => [
    ...current,
    ...(await library.fetchAssets(current.length, GALLERY_PAGE_SIZE)),
  ];
