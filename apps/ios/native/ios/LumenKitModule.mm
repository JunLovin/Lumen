#import <LumenNativeSpec/LumenNativeSpec.h>
#import <React/RCTBridgeModule.h>

#if __has_include(<LumenNative/LumenNative-Swift.h>)
#import <LumenNative/LumenNative-Swift.h>
#else
#import "LumenNative-Swift.h"
#endif

@interface LumenKitModule : NSObject <NativeLumenKitSpec>
@end

@implementation LumenKitModule {
  LumenKitBridge *_bridge;
}

RCT_EXPORT_MODULE(LumenKit)

- (instancetype)init {
  if (self = [super init]) {
    _bridge = [LumenKitBridge new];
  }
  return self;
}

- (NSNumber *)protocolVersion {
  return @([LumenKitBridge protocolVersion]);
}

- (void)startLink {
  [_bridge startLink];
}

- (void)linkStatus:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject {
  [_bridge linkStatus:^(BOOL isConnected) {
    resolve(@(isConnected));
  }];
}

- (void)sendDragFrame:(double)session
             sequence:(double)sequence
      ageMilliseconds:(double)ageMilliseconds
         xMillimeters:(double)xMillimeters
         yMillimeters:(double)yMillimeters
            velocityX:(double)velocityX
            velocityY:(double)velocityY
        edgeProximity:(double)edgeProximity
          objectWidth:(double)objectWidth
         objectHeight:(double)objectHeight
             rotation:(double)rotation {
  [_bridge sendDragFrameWithSession:(int32_t)session
                           sequence:(int32_t)sequence
                    ageMilliseconds:ageMilliseconds
                       xMillimeters:(float)xMillimeters
                       yMillimeters:(float)yMillimeters
                          velocityX:(float)velocityX
                          velocityY:(float)velocityY
                      edgeProximity:(float)edgeProximity
                        objectWidth:(float)objectWidth
                       objectHeight:(float)objectHeight
                           rotation:(float)rotation];
}

- (void)measurePlacement:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject {
  [_bridge measurePlacementWithResolve:^(NSDictionary *measurement) {
    resolve(measurement);
  }
      reject:^(NSString *code) {
        reject(code, code, nil);
      }];
}

- (void)exportLastRecording:(RCTPromiseResolveBlock)resolve
                     reject:(RCTPromiseRejectBlock)reject {
  [_bridge exportLastRecordingWithResolve:^(NSString *url) {
    resolve(url);
  }];
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeLumenKitSpecJSI>(params);
}

@end
