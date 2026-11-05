export type LibraryAccess =
  'authorized' | 'limited' | 'denied' | 'undetermined';

export type MediaAsset = {
  readonly id: string;
  readonly width: number;
  readonly height: number;
  readonly mediaType: 'photo' | 'video';
};
