export type DragFrameInput = {
  readonly capturedAtMilliseconds: number;
  readonly xMillimeters: number;
  readonly yMillimeters: number;
  readonly velocityX: number;
  readonly velocityY: number;
  readonly edgeProximity: number;
  readonly objectWidthMillimeters: number;
  readonly objectHeightMillimeters: number;
  readonly rotationRadians: number;
};

export type DragFrame = DragFrameInput & {
  readonly session: number;
  readonly sequence: number;
  readonly ageMilliseconds: number;
};
