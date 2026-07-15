#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^UTSBaiduNavBridgeCompletion)(BOOL success,
                                             NSString *code,
                                             NSString *message);
typedef void (^UTSBaiduNavBridgePayloadCompletion)(NSDictionary<NSString *, id> *payload);
typedef void (^UTSBaiduNavBridgeEventHandler)(NSDictionary<NSString *, id> *event);

@interface UtsBaiduNavBridge : NSObject

+ (NSString *)marker;
+ (nullable NSString *)sdkVersion;
+ (void)setAgreePrivacy:(BOOL)agreed;
+ (BOOL)isServicesInitialized;

+ (void)initializeWithAppKey:(NSString *)appKey
                  completion:(UTSBaiduNavBridgeCompletion)completion;

+ (void)authorizeTTSWithAppId:(NSString *)appId
                       apiKey:(NSString *)apiKey
                    secretKey:(NSString *)secretKey
                   completion:(UTSBaiduNavBridgeCompletion)completion;

+ (void)startNavigationWithOptions:(NSDictionary<NSString *, id> *)options
                      eventHandler:(UTSBaiduNavBridgeEventHandler)eventHandler
                        completion:(UTSBaiduNavBridgePayloadCompletion)completion;

+ (void)replanNavigationWithCompletion:(UTSBaiduNavBridgePayloadCompletion)completion;
+ (void)stopNavigationWithCompletion:(UTSBaiduNavBridgePayloadCompletion)completion;
+ (void)pauseNavigationWithCompletion:(UTSBaiduNavBridgePayloadCompletion)completion;
+ (void)resumeNavigationWithCompletion:(UTSBaiduNavBridgePayloadCompletion)completion;
+ (void)setNavigationVoiceEnabled:(BOOL)enabled
                        completion:(UTSBaiduNavBridgePayloadCompletion)completion;
+ (void)setNavigationCameraFollowingEnabled:(BOOL)enabled
                                  completion:(UTSBaiduNavBridgePayloadCompletion)completion;

+ (void)stopServices;

@end

NS_ASSUME_NONNULL_END
