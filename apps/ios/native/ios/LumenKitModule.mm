#import <LumenNativeSpec/LumenNativeSpec.h>
#import <React/RCTBridgeModule.h>
#import <ReactCommon/RCTTurboModuleWithJSIBindings.h>
#import <jsi/jsi.h>

#if __has_include(<LumenNative/LumenNative-Swift.h>)
#import <LumenNative/LumenNative-Swift.h>
#else
#import "LumenNative-Swift.h"
#endif

using namespace facebook;

// A host object because Worklets can carry those to the UI runtime: drag frames and haptics then
// leave directly from the gesture, without passing through the JS thread.
class UIThreadChannel : public jsi::HostObject {
public:
  explicit UIThreadChannel(LumenKitBridge *bridge) : bridge_(bridge) {}

  jsi::Value get(jsi::Runtime &runtime, const jsi::PropNameID &name) override {
    auto property = name.utf8(runtime);
    LumenKitBridge *bridge = bridge_;
    if (property == "sendFrame") {
      return jsi::Function::createFromHostFunction(
          runtime, name, 11,
          [bridge](jsi::Runtime &, const jsi::Value &, const jsi::Value *args, size_t count) {
            if (count == 11) {
              [bridge sendDragFrameWithSession:(int32_t)args[0].asNumber()
                                      sequence:(int32_t)args[1].asNumber()
                               ageMilliseconds:0
                                  xMillimeters:(float)args[2].asNumber()
                                  yMillimeters:(float)args[3].asNumber()
                                     velocityX:(float)args[4].asNumber()
                                     velocityY:(float)args[5].asNumber()
                                 edgeProximity:(float)args[6].asNumber()
                                   objectWidth:(float)args[7].asNumber()
                                  objectHeight:(float)args[8].asNumber()
                                      rotation:(float)args[9].asNumber()
                                          edge:(NSInteger)args[10].asNumber()];
            }
            return jsi::Value::undefined();
          });
    }
    if (property == "endDrag") {
      return jsi::Function::createFromHostFunction(
          runtime, name, 4,
          [bridge](jsi::Runtime &, const jsi::Value &, const jsi::Value *args, size_t count) {
            if (count == 4) {
              [bridge endDragWithSession:(int32_t)args[0].asNumber()
                                 crossed:args[1].asBool()
                               velocityX:(float)args[2].asNumber()
                               velocityY:(float)args[3].asNumber()];
            }
            return jsi::Value::undefined();
          });
    }
    if (property == "startUpload") {
      return jsi::Function::createFromHostFunction(
          runtime, name, 1,
          [bridge](jsi::Runtime &, const jsi::Value &, const jsi::Value *args, size_t count) {
            if (count == 1) {
              [bridge startUploadWithSession:(int32_t)args[0].asNumber()];
            }
            return jsi::Value::undefined();
          });
    }
    if (property == "impact") {
      return jsi::Function::createFromHostFunction(
          runtime, name, 1,
          [bridge](jsi::Runtime &, const jsi::Value &, const jsi::Value *args, size_t count) {
            if (count == 1) {
              [bridge impactWithStyle:(NSInteger)args[0].asNumber()];
            }
            return jsi::Value::undefined();
          });
    }
    return jsi::Value::undefined();
  }

private:
  LumenKitBridge *bridge_;
};

@interface LumenKitModule : NSObject <NativeLumenKitSpec, RCTTurboModuleWithJSIBindings>
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

- (void)installJSIBindingsWithRuntime:(jsi::Runtime &)runtime
                          callInvoker:(const std::shared_ptr<react::CallInvoker> &)callInvoker {
  runtime.global().setProperty(
      runtime, "__lumenUIThreadChannel",
      jsi::Object::createFromHostObject(runtime, std::make_shared<UIThreadChannel>(_bridge)));
}

- (NSString *)deviceModel {
  return [LumenKitBridge deviceModel];
}

- (NSString *)libraryAccess {
  return [_bridge libraryAccess];
}

- (void)requestLibraryAccess:(RCTPromiseResolveBlock)resolve
                      reject:(RCTPromiseRejectBlock)reject {
  [_bridge requestLibraryAccess:^(NSString *status) {
    resolve(status);
  }];
}

- (void)fetchLibraryAssets:(double)offset
                     limit:(double)limit
                   resolve:(RCTPromiseResolveBlock)resolve
                    reject:(RCTPromiseRejectBlock)reject {
  [_bridge fetchLibraryAssetsWithOffset:(NSInteger)offset
                                  limit:(NSInteger)limit
                             completion:^(NSArray *assets) {
                               resolve(assets);
                             }];
}

- (void)loadThumbnail:(NSString *)assetId
                 size:(double)size
              resolve:(RCTPromiseResolveBlock)resolve
               reject:(RCTPromiseRejectBlock)reject {
  [_bridge loadThumbnailWithAssetId:assetId
                               size:size
                         completion:^(NSString *uri) {
                           resolve(uri);
                         }];
}

- (void)beginDrag:(double)session
           assetId:(NSString *)assetId
 phoneHeightMillimeters:(double)phoneHeightMillimeters
                   resolve:(RCTPromiseResolveBlock)resolve
                    reject:(RCTPromiseRejectBlock)reject {
  [_bridge beginDragWithSession:(int32_t)session
                        assetId:assetId
         phoneHeightMillimeters:(float)phoneHeightMillimeters
                     completion:^(NSArray<NSNumber *> *palette) {
                       resolve(palette);
                     }];
}

- (void)pickFilesToSend {
  [_bridge pickFilesToSend];
}

- (void)listReceivedFiles:(RCTPromiseResolveBlock)resolve
                   reject:(RCTPromiseRejectBlock)reject {
  [_bridge listReceivedFiles:^(NSDictionary *inbox) {
    resolve(inbox);
  }];
}

- (void)deleteReceivedFile:(NSString *)name {
  [_bridge deleteReceivedFile:name];
}

- (void)manageLimitedLibrary {
  [_bridge manageLimitedLibrary];
}

- (NSNumber *)protocolVersion {
  return @([LumenKitBridge protocolVersion]);
}

- (void)startLink {
  [_bridge startLink];
}

- (void)pairingStatus:(RCTPromiseResolveBlock)resolve
               reject:(RCTPromiseRejectBlock)reject {
  [_bridge pairingStatus:^(NSDictionary *status) {
    resolve(status);
  }];
}

- (void)forgetPairing {
  [_bridge forgetPairing];
}

- (void)reconnect {
  [_bridge reconnect];
}

- (void)probeFileChannel:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject {
  [_bridge probeFileChannel:^(BOOL succeeded) {
    resolve(@(succeeded));
  }];
}

- (void)reportEdgeExit:(double)edge {
  [_bridge reportEdgeExit:(NSInteger)edge];
}

- (void)placementStatus:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject {
  [_bridge placementStatus:^(NSDictionary *status) {
    resolve(status);
  }];
}

- (void)linkStatus:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject {
  [_bridge linkStatus:^(BOOL isConnected) {
    resolve(@(isConnected));
  }];
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
