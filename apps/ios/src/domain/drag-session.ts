export type DragSession =
  | { readonly stage: 'idle' }
  | { readonly stage: 'lifting' }
  | { readonly stage: 'dragging' }
  | { readonly stage: 'approaching'; readonly proximity: number }
  | { readonly stage: 'crossing'; readonly fraction: number }
  | { readonly stage: 'released' }
  | { readonly stage: 'landing' }
  | { readonly stage: 'landed' }
  | { readonly stage: 'cancelled' };

export type DragEvent =
  | { readonly type: 'lift' }
  | {
      readonly type: 'moved';
      readonly proximity: number;
      readonly crossingFraction: number;
    }
  | { readonly type: 'release' }
  | { readonly type: 'landingStarted' }
  | { readonly type: 'landed' }
  | { readonly type: 'cancel' };

const isActive = (session: DragSession) => {
  'worklet';
  return (
    session.stage === 'lifting' ||
    session.stage === 'dragging' ||
    session.stage === 'approaching' ||
    session.stage === 'crossing'
  );
};

export const advanceDragSession = (
  session: DragSession,
  event: DragEvent,
): DragSession => {
  'worklet';
  switch (event.type) {
    case 'lift':
      return session.stage === 'idle' ? { stage: 'lifting' } : session;
    case 'moved':
      if (!isActive(session)) {
        return session;
      }
      if (event.crossingFraction > 0) {
        return {
          stage: 'crossing',
          fraction: Math.min(event.crossingFraction, 1),
        };
      }
      return event.proximity > 0
        ? { stage: 'approaching', proximity: Math.min(event.proximity, 1) }
        : { stage: 'dragging' };
    case 'release':
      if (session.stage === 'crossing') {
        return { stage: 'released' };
      }
      return isActive(session) ? { stage: 'cancelled' } : session;
    case 'landingStarted':
      return session.stage === 'released' ? { stage: 'landing' } : session;
    case 'landed':
      return session.stage === 'landing' ? { stage: 'landed' } : session;
    case 'cancel':
      return isActive(session) ? { stage: 'cancelled' } : session;
  }
};
