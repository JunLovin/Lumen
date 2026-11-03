import fc from 'fast-check';
import {
  advanceDragSession,
  type DragEvent,
  type DragSession,
} from './drag-session';

const run = (
  events: readonly DragEvent[],
  start: DragSession = { stage: 'idle' },
) => events.reduce(advanceDragSession, start);

const moved = (proximity: number, crossingFraction = 0): DragEvent => ({
  type: 'moved',
  proximity,
  crossingFraction,
});

describe('advanceDragSession', () => {
  it('walks a full drag across the edge', () => {
    const session = run([
      { type: 'lift' },
      moved(0),
      moved(0.5),
      moved(1, 0.4),
      { type: 'release' },
      { type: 'landingStarted' },
      { type: 'landed' },
    ]);
    expect(session).toEqual({ stage: 'landed' });
  });

  it('reports proximity while approaching', () => {
    expect(run([{ type: 'lift' }, moved(0.5)])).toEqual({
      stage: 'approaching',
      proximity: 0.5,
    });
  });

  it('cancels when released before crossing', () => {
    expect(run([{ type: 'lift' }, moved(0.5), { type: 'release' }])).toEqual({
      stage: 'cancelled',
    });
  });

  it('can go back from approaching to dragging', () => {
    expect(run([{ type: 'lift' }, moved(0.5), moved(0)])).toEqual({
      stage: 'dragging',
    });
  });

  it('ignores movement before lifting and after ending', () => {
    expect(run([moved(0.5)])).toEqual({ stage: 'idle' });
    expect(run([moved(0.5)], { stage: 'cancelled' })).toEqual({
      stage: 'cancelled',
    });
  });

  it('keeps every value in range for any sequence', () => {
    const event: fc.Arbitrary<DragEvent> = fc.oneof(
      fc.constantFrom<DragEvent>(
        { type: 'lift' },
        { type: 'release' },
        { type: 'landingStarted' },
        { type: 'landed' },
        { type: 'cancel' },
      ),
      fc.record({
        type: fc.constant<'moved'>('moved'),
        proximity: fc.double({ min: -5, max: 5, noNaN: true }),
        crossingFraction: fc.double({ min: -5, max: 5, noNaN: true }),
      }),
    );
    fc.assert(
      fc.property(fc.array(event), events => {
        const session = run(events);
        if (session.stage === 'approaching') {
          expect(session.proximity).toBeLessThanOrEqual(1);
          expect(session.proximity).toBeGreaterThan(0);
        }
        if (session.stage === 'crossing') {
          expect(session.fraction).toBeLessThanOrEqual(1);
          expect(session.fraction).toBeGreaterThan(0);
        }
      }),
    );
  });
});
