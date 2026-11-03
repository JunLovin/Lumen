#import <LumenNativeSpec/LumenNativeSpec.h>
#import <React/RCTBridgeModule.h>

#if __has_include(<LumenNative/LumenNative-Swift.h>)
#import <LumenNative/LumenNative-Swift.h>
#else
#import "LumenNative-Swift.h"
#endif

@interface LumenKitModule : NSObject <NativeLumenKitSpec>
@end

@implementation LumenKitModule

RCT_EXPORT_MODULE(LumenKit)

- (NSNumber *)protocolVersion {
  return @([LumenKitBridge protocolVersion]);
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeLumenKitSpecJSI>(params);
}

@end
