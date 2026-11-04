import { useEffect, useState } from 'react';
import { FlatList, Image, Share, StyleSheet, Text, View } from 'react-native';
import type { LabUseCases } from '../../application/lab-use-cases';
import {
  formatByteCount,
  isPreviewableImage,
  receivingFraction,
  type Inbox,
  type ReceivedFile,
} from '../../domain/inbox';
import { CondenseIn } from '../effects/CondenseIn';
import { DiagnosticRow } from '../components/DiagnosticRow';
import { LabButton } from '../components/LabButton';
import { translate } from '../i18n/translate';
import { labTheme } from '../lab-theme';

type Props = {
  readonly useCases: LabUseCases;
};

const POLL_MILLISECONDS = 500;
const PREVIEW_POINTS = 56;
const EMPTY_INBOX: Inbox = { files: [], receivedBytes: 0, totalBytes: 0 };

export function InboxScreen({ useCases }: Props) {
  const [inbox, setInbox] = useState(EMPTY_INBOX);
  const fraction = receivingFraction(inbox);

  useEffect(() => {
    const poll = () => useCases.readInbox().then(setInbox);
    poll();
    const timer = setInterval(poll, POLL_MILLISECONDS);
    return () => clearInterval(timer);
  }, [useCases]);

  const renderFile = ({ item }: { readonly item: ReceivedFile }) => (
    <CondenseIn style={styles.row}>
      {isPreviewableImage(item) && (
        <Image source={{ uri: item.uri }} style={styles.preview} />
      )}
      <View style={styles.details}>
        <Text style={styles.name} numberOfLines={1}>
          {item.name}
        </Text>
        <Text style={styles.meta}>
          {item.isDirectory
            ? translate('inbox.folder')
            : formatByteCount(item.byteCount)}
        </Text>
      </View>
      <Text
        style={styles.action}
        onPress={() => Share.share({ url: item.uri })}
      >
        {translate('inbox.share')}
      </Text>
      <Text
        style={styles.action}
        onPress={() => useCases.deleteReceivedFile(item.name)}
      >
        {translate('inbox.delete')}
      </Text>
    </CondenseIn>
  );

  return (
    <View style={styles.screen}>
      <LabButton
        title={translate('inbox.send')}
        onPress={useCases.pickFilesToSend}
      />
      {fraction !== null && (
        <DiagnosticRow
          label={translate('inbox.receiving')}
          value={`${Math.round(fraction * 100)} %`}
        />
      )}
      <FlatList
        data={inbox.files}
        keyExtractor={item => item.name}
        renderItem={renderFile}
        ListEmptyComponent={
          <Text style={styles.meta}>{translate('inbox.empty')}</Text>
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: labTheme.background,
    padding: labTheme.spacing,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingVertical: 10,
  },
  preview: { width: PREVIEW_POINTS, height: PREVIEW_POINTS, borderRadius: 8 },
  details: { flex: 1 },
  name: { color: labTheme.text, fontSize: 15 },
  meta: { color: labTheme.secondaryText, fontSize: 13 },
  action: { color: labTheme.accent, fontSize: 14 },
});
