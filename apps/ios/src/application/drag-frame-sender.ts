import type { DragFrameInput } from '../domain/drag-frame';
import type { ClockPort } from '../ports/clock-port';
import type { PeerChannelPort } from '../ports/peer-channel-port';

export type DragFrameSender = {
  readonly begin: () => void;
  readonly send: (input: DragFrameInput) => void;
};

export const createDragFrameSender = (
  peer: PeerChannelPort,
  clock: ClockPort,
): DragFrameSender => {
  let session = 0;
  let sequence = 0;
  return {
    begin: () => {
      session += 1;
      sequence = 0;
    },
    send: input => {
      sequence += 1;
      peer.sendDragFrame({
        ...input,
        session,
        sequence,
        ageMilliseconds: clock.nowMilliseconds() - input.capturedAtMilliseconds,
      });
    },
  };
};
