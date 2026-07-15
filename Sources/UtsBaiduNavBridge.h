#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^UTSBaiduNavBridgeCompletion)(BOOL success,
                                             NSString *code,
                                             NSString *message);

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

+ (void)stopServices;

@end

NS_ASSUME_NONNULL_END
