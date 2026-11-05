import type { LibraryAccess, MediaAsset } from '../domain/media';

export interface MediaLibraryPort {
  readAccess(): Promise<LibraryAccess>;
  requestAccess(): Promise<LibraryAccess>;
  fetchAssets(offset: number, limit: number): Promise<readonly MediaAsset[]>;
  loadThumbnail(assetId: string, size: number): Promise<string | null>;
  manageLimitedAccess(): void;
  beginDragTransfer(
    session: number,
    assetId: string,
    phoneHeightMillimeters: number,
  ): Promise<readonly number[]>;
}
