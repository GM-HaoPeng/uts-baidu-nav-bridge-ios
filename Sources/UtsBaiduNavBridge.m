#import "UtsBaiduNavBridge.h"

#import <UIKit/UIKit.h>
#import <BaiduMapAPI_Base/BMKBaseComponent.h>
#import <BaiduMapAPI_Map/BMKMapComponent.h>
#import "BNaviService.h"

static NSString *const UTSBaiduNavBridgeMarker = @"BAIDU_IOS_NAVSDK_BRIDGE_POD_IMPORTED";
static NSTimeInterval const UTSBaiduNavBridgeCallbackTimeout = 20.0;

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
    __block BOOL finished = NO;
    __block NSString *activeStage = @"init";
    __block NSUInteger stageToken = 0;
    void (^finishOnce)(BOOL, NSString *, NSString *) = ^(BOOL success,
                                                          NSString *code,
                                                          NSString *message) {
      if (finished) {
        return;
      }
      finished = YES;
      NSLog(@"[UtsBaiduNavBridge] initialize completion stage=%@ success=%d code=%@",
            activeStage,
            success,
            code);
      [self finish:completion success:success code:code message:message];
    };
    void (^scheduleStageTimeout)(NSString *, NSString *, NSString *) = ^(NSString *stage,
                                                                          NSString *code,
                                                                          NSString *message) {
      activeStage = stage;
      stageToken += 1;
      NSUInteger expectedToken = stageToken;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                   (int64_t)(UTSBaiduNavBridgeCallbackTimeout * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{
        if (finished || expectedToken != stageToken) {
          return;
        }
        finishOnce(NO, code, message);
      });
    };
    void (^authorizeNavigation)(void) = ^{
      if (finished) {
        return;
      }
      scheduleStageTimeout(@"authorize",
                           @"BAIDU_NAVSDK_AUTH_TIMEOUT",
                           @"Baidu navigation SDK authorization timed out.");
      NSLog(@"[UtsBaiduNavBridge] authorizeNaviAppKey before");
      [service authorizeNaviAppKey:appKey
                        completion:^(BOOL authorized) {
        NSLog(@"[UtsBaiduNavBridge] authorizeNaviAppKey callback success=%d", authorized);
        finishOnce(authorized,
                   authorized ? @"BAIDU_NAVSDK_READY" : @"BAIDU_NAVSDK_AUTH_FAILED",
                   authorized ? @"Baidu navigation SDK initialized and authorized."
                              : @"Baidu navigation SDK authorization failed.");
      }];
      NSLog(@"[UtsBaiduNavBridge] authorizeNaviAppKey after");
    };

    if ([service isServicesInited]) {
      NSLog(@"[UtsBaiduNavBridge] initNaviService skipped services already initialized");
      authorizeNavigation();
      return;
    }

    scheduleStageTimeout(@"init",
                         @"BAIDU_NAVSDK_INIT_TIMEOUT",
                         @"Baidu navigation SDK initialization timed out.");
    NSLog(@"[UtsBaiduNavBridge] initNaviService before params=nil");
    [service initNaviService:nil
                     success:^{
      NSLog(@"[UtsBaiduNavBridge] initNaviService success callback");
      if (finished) {
        return;
      }
      authorizeNavigation();
    }
                        fail:^{
      NSLog(@"[UtsBaiduNavBridge] initNaviService fail callback");
      finishOnce(NO,
                 @"BAIDU_NAVSDK_INIT_FAILED",
                 @"Baidu navigation SDK initialization failed.");
    }];
    NSLog(@"[UtsBaiduNavBridge] initNaviService after");
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
    __block BOOL finished = NO;
    void (^finishOnce)(BOOL, NSString *, NSString *) = ^(BOOL success,
                                                          NSString *code,
                                                          NSString *message) {
      if (finished) {
        return;
      }
      finished = YES;
      NSLog(@"[UtsBaiduNavBridge] authorizeTTS completion success=%d code=%@", success, code);
      [self finish:completion success:success code:code message:message];
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(UTSBaiduNavBridgeCallbackTimeout * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      finishOnce(NO,
                 @"BAIDU_NAVSDK_TTS_AUTH_TIMEOUT",
                 @"Baidu navigation TTS authorization timed out.");
    });
    NSLog(@"[UtsBaiduNavBridge] authorizeTTS before");
    [[BNaviService getInstance] authorizeTTSAppId:appId
                                          apiKey:apiKey
                                       secretKey:secretKey
                                      completion:^(BOOL authorized) {
      NSLog(@"[UtsBaiduNavBridge] authorizeTTS callback success=%d", authorized);
      finishOnce(authorized,
                 authorized ? @"BAIDU_NAVSDK_TTS_READY" : @"BAIDU_NAVSDK_TTS_AUTH_FAILED",
                 authorized ? @"Baidu navigation TTS authorized."
                            : @"Baidu navigation TTS authorization failed.");
    }];
    NSLog(@"[UtsBaiduNavBridge] authorizeTTS after");
  }];
}

+ (void)stopServices {
  [self performOnMainThread:^{
    [[BNaviService getInstance] stopServices];
  }];
}

@end
