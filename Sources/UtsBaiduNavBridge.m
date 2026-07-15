#import "UtsBaiduNavBridge.h"

#import <UIKit/UIKit.h>
#import <BaiduMapAPI_Base/BMKBaseComponent.h>
#import <BaiduMapAPI_Map/BMKMapComponent.h>
#import "BNaviService.h"

static NSString *const UTSBaiduNavBridgeMarker = @"BAIDU_IOS_NAVSDK_BRIDGE_POD_IMPORTED";

@implementation UtsBaiduNavBridge

+ (void)performOnMainThread:(dispatch_block_t)block {
  if ([NSThread isMainThread]) {
    block();
    return;
  }
  dispatch_async(dispatch_get_main_queue(), block);
}

+ (void)finish:(UTSBaiduNavBridgeCompletion)completion
        success:(BOOL)success
           code:(NSString *)code
        message:(NSString *)message {
  [self performOnMainThread:^{
    completion(success, code, message);
  }];
}

+ (NSString *)marker {
  return UTSBaiduNavBridgeMarker;
}

+ (nullable NSString *)sdkVersion {
  return [BNaviService sdkVersion];
}

+ (void)setAgreePrivacy:(BOOL)agreed {
  [BNaviService setAgreePrivacy:agreed];
}

+ (BOOL)isServicesInitialized {
  return [[BNaviService getInstance] isServicesInited];
}

+ (void)initializeWithAppKey:(NSString *)appKey
                  completion:(UTSBaiduNavBridgeCompletion)completion {
  if (appKey.length == 0) {
    [self finish:completion
         success:NO
            code:@"BAIDU_NAVSDK_INVALID_APP_KEY"
         message:@"The Baidu navigation app key is empty."];
    return;
  }

  [self performOnMainThread:^{
    BNaviService *service = [BNaviService getInstance];
    [service initNaviService:@{}
                     success:^{
      [service authorizeNaviAppKey:appKey
                        completion:^(BOOL authorized) {
        [self finish:completion
             success:authorized
                code:(authorized ? @"BAIDU_NAVSDK_READY" : @"BAIDU_NAVSDK_AUTH_FAILED")
             message:(authorized ? @"Baidu navigation SDK initialized and authorized."
                                  : @"Baidu navigation SDK authorization failed.")];
      }];
    }
                        fail:^{
      [self finish:completion
           success:NO
              code:@"BAIDU_NAVSDK_INIT_FAILED"
           message:@"Baidu navigation SDK initialization failed."];
    }];
  }];
}

+ (void)authorizeTTSWithAppId:(NSString *)appId
                       apiKey:(NSString *)apiKey
                    secretKey:(NSString *)secretKey
                   completion:(UTSBaiduNavBridgeCompletion)completion {
  if (appId.length == 0 || apiKey.length == 0 || secretKey.length == 0) {
    [self finish:completion
         success:NO
            code:@"BAIDU_NAVSDK_INVALID_TTS_CREDENTIALS"
         message:@"The Baidu TTS credentials are incomplete."];
    return;
  }

  [self performOnMainThread:^{
    [[BNaviService getInstance] authorizeTTSAppId:appId
                                          apiKey:apiKey
                                       secretKey:secretKey
                                      completion:^(BOOL authorized) {
      [self finish:completion
           success:authorized
              code:(authorized ? @"BAIDU_NAVSDK_TTS_READY" : @"BAIDU_NAVSDK_TTS_AUTH_FAILED")
           message:(authorized ? @"Baidu navigation TTS authorized."
                                : @"Baidu navigation TTS authorization failed.")];
    }];
  }];
}

+ (void)stopServices {
  [self performOnMainThread:^{
    [[BNaviService getInstance] stopServices];
  }];
}

@end
