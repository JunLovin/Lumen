import type { DragFrame } from '../domain/drag-frame';
import { createDragFrameSender } from './drag-frame-sender';

const input = {
  capturedAtMilliseconds: 95,
  xMillimeters: 1,
  yMillimeters: 2,
  velocityX: 0,
  velocityY: 0,
  edgeProximity: 0,
  objectWidthMillimeters: 10,
  objectHeightMillimeters: 10,
  rotationRadians: 0,
};

const setup = () => {
  const frames: DragFrame[] = [];
  const sender = createDragFrameSender(
    {
      start: () => undefined,
      isConnected: () => Promise.resolve(true),
      reconnect: () => undefined,
      probeFileChannel: () => Promise.resolve(true),
      sendDragFrame: frame => frames.push(frame),
    },
    { nowMilliseconds: () => 100 },
  );
  return { frames, sender };
};

describe('dragFrameSender', () => {
  it('numbers frames within a session and measures their age', () => {
    const { frames, sender } = setup();
    sender.begin();
    sender.send(input);
    sender.send(input);
    expect(frames.map(frame => frame.sequence)).toEqual([1, 2]);
    expect(frames[0]?.ageMilliseconds).toBe(5);
  });

  it('restarts the sequence in a new session', () => {
    const { frames, sender } = setup();
    sender.begin();
    sender.send(input);
    sender.begin();
    sender.send(input);
    expect(frames.map(frame => [frame.session, frame.sequence])).toEqual([
      [1, 1],
      [2, 1],
    ]);
  });
});
