import { useCallback, useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import type { LabUseCases } from '../../application/lab-use-cases';
import type { LibraryAccess, MediaAsset } from '../../domain/media';
import { ConnectionBanner } from '../components/ConnectionBanner';
import { LabButton } from '../components/LabButton';
import { translate } from '../i18n/translate';
import { labTheme } from '../lab-theme';
import { GalleryGrid } from './GalleryGrid';

type Props = {
  readonly useCases: LabUseCases;
};

export function GalleryScreen({ useCases }: Props) {
  const [access, setAccess] = useState<LibraryAccess>('undetermined');
  const [assets, setAssets] = useState<readonly MediaAsset[]>([]);

  const allow = useCallback(async () => {
    const granted = await useCases.requestLibraryAccess();
    setAccess(granted);
    if (granted === 'authorized' || granted === 'limited') {
      setAssets(await useCases.loadGalleryPage([]));
    }
  }, [useCases]);

  useEffect(() => {
    useCases.readLibraryAccess().then(current => {
      if (current === 'authorized' || current === 'limited') {
        allow();
      } else {
        setAccess(current);
      }
    });
  }, [allow, useCases]);

  const loadMore = useCallback(async () => {
    setAssets(await useCases.loadGalleryPage(assets));
  }, [assets, useCases]);

  if (access === 'undetermined' || access === 'denied') {
    return (
      <View style={styles.primer}>
        <Text style={styles.title}>{translate('gallery.primerTitle')}</Text>
        <Text style={styles.body}>
          {translate(
            access === 'denied' ? 'gallery.denied' : 'gallery.primerBody',
          )}
        </Text>
        {access === 'undetermined' && (
          <LabButton title={translate('gallery.allow')} onPress={allow} />
        )}
      </View>
    );
  }

  return (
    <View style={styles.screen}>
      <ConnectionBanner isPeerConnected={useCases.isPeerConnected} />
      {access === 'limited' && (
        <LabButton
          title={translate('gallery.manage')}
          onPress={useCases.manageLimitedAccess}
        />
      )}
      {assets.length === 0 ? (
        <Text style={styles.body}>{translate('gallery.empty')}</Text>
      ) : (
        <GalleryGrid
          assets={assets}
          useCases={useCases}
          onEndReached={loadMore}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: labTheme.background },
  primer: {
    flex: 1,
    justifyContent: 'center',
    backgroundColor: labTheme.background,
    padding: labTheme.spacing * 2,
    gap: labTheme.spacing,
  },
  title: { color: labTheme.text, fontSize: 28, fontWeight: '700' },
  body: {
    color: labTheme.secondaryText,
    fontSize: 16,
    padding: labTheme.spacing / 2,
  },
});
