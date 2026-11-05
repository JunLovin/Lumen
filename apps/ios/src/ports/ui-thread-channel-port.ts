export type HapticStyle = 0 | 1;

export interface UIThreadChannelPort {
  sendFrame(
    session: number,
    sequence: number,
    xMillimeters: number,
    yMillimeters: number,
    velocityX: number,
    velocityY: number,
    edgeProximity: number,
    objectWidth: number,
    objectHeight: number,
    rotation: number,
    edge: number,
  ): void;
  endDrag(
    session: number,
    crossed: boolean,
    velocityX: number,
    velocityY: number,
  ): void;
  impact(style: HapticStyle): void;
}
