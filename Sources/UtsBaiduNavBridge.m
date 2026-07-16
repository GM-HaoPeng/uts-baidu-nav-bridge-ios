#import "UtsBaiduNavBridge.h"

#import <UIKit/UIKit.h>
#import <BaiduMapAPI_Base/BMKBaseComponent.h>
#import <BaiduMapAPI_Map/BMKMapComponent.h>
#import "BNaviService.h"
#import "BNaviModel.h"

static NSString *const UTSBaiduNavBridgeMarker = @"BAIDU_IOS_NAVSDK_BRIDGE_POD_IMPORTED";
static NSTimeInterval const UTSBaiduNavBridgeCallbackTimeout = 20.0;
static NSTimeInterval const UTSBaiduNavBridgeRouteTimeout = 30.0;

@interface UtsBaiduNavBridge () <BNNaviRoutePlanDelegate, BNNaviUIManagerDelegate, BNaviModelDelegate>

@property (nonatomic, copy, nullable) UTSBaiduNavBridgePayloadCompletion startCompletion;
@property (nonatomic, copy, nullable) UTSBaiduNavBridgePayloadCompletion replanCompletion;
@property (nonatomic, copy, nullable) UTSBaiduNavBridgeEventHandler eventHandler;
@property (nonatomic, copy) NSString *navigationId;
@property (nonatomic, copy) NSArray<BNRoutePlanNode *> *routeNodes;
@property (nonatomic, assign) BN_NaviType naviType;
@property (nonatomic, assign) NSUInteger startToken;
@property (nonatomic, assign) NSUInteger replanToken;
@property (nonatomic, assign) BOOL navigationActive;
@property (nonatomic, assign) BOOL stoppingNavigation;
@property (nonatomic, assign) BOOL voiceEnabled;
@property (nonatomic, assign) BOOL cameraFollowingEnabled;
@property (nonatomic, assign) BOOL usesSdkUI;

@end

@implementation UtsBaiduNavBridge

+ (instancetype)sharedBridge {
  static UtsBaiduNavBridge *bridge;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    bridge = [[UtsBaiduNavBridge alloc] init];
    bridge.navigationId = @"";
    bridge.routeNodes = @[];
  });
  return bridge;
}

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

+ (NSDictionary<NSString *, id> *)navigationPayloadWithSuccess:(BOOL)success
                                                            code:(NSString *)code
                                                         message:(NSString *)message
                                                    navigationId:(NSString *)navigationId
                                                          status:(NSString *)status {
  return @{
    @"success": @(success),
    @"code": code ?: @"",
    @"message": message ?: @"",
    @"nativeCode": code ?: @"",
    @"nativeMessage": message ?: @"",
    @"platform": @"ios",
    @"navigationId": navigationId ?: @"",
    @"status": status ?: @""
  };
}

- (NSDictionary<NSString *, id> *)eventWithType:(NSString *)eventType
                                          status:(NSString *)status
                                          extras:(nullable NSDictionary<NSString *, id> *)extras {
  NSMutableDictionary<NSString *, id> *event = [@{
    @"navigationId": self.navigationId ?: @"",
    @"eventType": eventType ?: @"",
    @"status": status ?: @"",
    @"currentCoordinate": [NSNull null],
    @"matchedCoordinate": [NSNull null],
    @"remainingDistanceInMeters": [NSNull null],
    @"remainingDurationInSeconds": [NSNull null],
    @"traveledDistanceInMeters": [NSNull null],
    @"currentRoadName": @"",
    @"nextRoadName": @"",
    @"instructionText": @"",
    @"voiceInstructionText": @"",
    @"routeLine": [NSNull null],
    @"error": [NSNull null]
  } mutableCopy];
  if (extras.count > 0) {
    [event addEntriesFromDictionary:extras];
  }
  return event;
}

- (void)emitEventType:(NSString *)eventType
                status:(NSString *)status
                extras:(nullable NSDictionary<NSString *, id> *)extras {
  UTSBaiduNavBridgeEventHandler handler = self.eventHandler;
  if (handler == nil) {
    return;
  }
  NSDictionary<NSString *, id> *event = [self eventWithType:eventType status:status extras:extras];
  NSLog(@"[UtsBaiduNavBridge] navigation event type=%@ status=%@", eventType, status);
  handler(event);
}

+ (nullable NSDictionary<NSString *, id> *)coordinateDictionaryFromValue:(id)value {
  if (![value isKindOfClass:[NSDictionary class]]) {
    return nil;
  }
  NSDictionary<NSString *, id> *coordinate = (NSDictionary<NSString *, id> *)value;
  NSNumber *latitude = [coordinate[@"latitude"] isKindOfClass:[NSNumber class]] ? coordinate[@"latitude"] : nil;
  NSNumber *longitude = [coordinate[@"longitude"] isKindOfClass:[NSNumber class]] ? coordinate[@"longitude"] : nil;
  if (latitude == nil || longitude == nil) {
    return nil;
  }
  double latitudeValue = latitude.doubleValue;
  double longitudeValue = longitude.doubleValue;
  if (!isfinite(latitudeValue) || !isfinite(longitudeValue) ||
      latitudeValue < -90.0 || latitudeValue > 90.0 ||
      longitudeValue < -180.0 || longitudeValue > 180.0) {
    return nil;
  }
  return coordinate;
}

+ (nullable BNRoutePlanNode *)routeNodeFromCoordinateValue:(id)value name:(nullable id)nameValue {
  NSDictionary<NSString *, id> *coordinate = [self coordinateDictionaryFromValue:value];
  if (coordinate == nil) {
    return nil;
  }
  BNPosition *position = [[BNPosition alloc] init];
  position.y = [coordinate[@"latitude"] doubleValue];
  position.x = [coordinate[@"longitude"] doubleValue];
  position.eType = BNCoordinate_BaiduMapSDK;
  BNRoutePlanNode *node = [[BNRoutePlanNode alloc] init];
  node.pos = position;
  node.title = [nameValue isKindOfClass:[NSString class]] ? (NSString *)nameValue : @"";
  return node;
}

+ (nullable NSArray<BNRoutePlanNode *> *)routeNodesFromOptions:(NSDictionary<NSString *, id> *)options {
  BNRoutePlanNode *startNode = [self routeNodeFromCoordinateValue:options[@"startCoordinate"]
                                                             name:options[@"startName"]];
  BNRoutePlanNode *endNode = [self routeNodeFromCoordinateValue:options[@"endCoordinate"]
                                                           name:options[@"endName"]];
  if (startNode == nil || endNode == nil) {
    return nil;
  }
  NSMutableArray<BNRoutePlanNode *> *nodes = [NSMutableArray arrayWithObject:startNode];
  id waypointValue = options[@"waypointList"];
  if ([waypointValue isKindOfClass:[NSArray class]]) {
    for (id item in (NSArray *)waypointValue) {
      if (![item isKindOfClass:[NSDictionary class]]) {
        return nil;
      }
      NSDictionary<NSString *, id> *waypoint = (NSDictionary<NSString *, id> *)item;
      BNRoutePlanNode *waypointNode = [self routeNodeFromCoordinateValue:waypoint[@"coordinate"]
                                                                    name:waypoint[@"name"]];
      if (waypointNode == nil) {
        return nil;
      }
      [nodes addObject:waypointNode];
    }
  }
  [nodes addObject:endNode];
  return nodes;
}

+ (nullable UIViewController *)topViewControllerFrom:(nullable UIViewController *)viewController {
  if (viewController == nil) {
    return nil;
  }
  if (viewController.presentedViewController != nil) {
    return [self topViewControllerFrom:viewController.presentedViewController];
  }
  if ([viewController isKindOfClass:[UINavigationController class]]) {
    return [self topViewControllerFrom:((UINavigationController *)viewController).visibleViewController];
  }
  if ([viewController isKindOfClass:[UITabBarController class]]) {
    return [self topViewControllerFrom:((UITabBarController *)viewController).selectedViewController];
  }
  return viewController;
}

+ (nullable UIViewController *)hostViewController {
  UIWindow *window = nil;
  if (@available(iOS 13.0, *)) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
      if (scene.activationState != UISceneActivationStateForegroundActive ||
          ![scene isKindOfClass:[UIWindowScene class]]) {
        continue;
      }
      for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
        if (candidate.isKeyWindow) {
          window = candidate;
          break;
        }
      }
      if (window != nil) {
        break;
      }
    }
  }
  if (window == nil) {
    window = UIApplication.sharedApplication.keyWindow;
  }
  return [self topViewControllerFrom:window.rootViewController];
}

- (void)finishStartSuccess:(BOOL)success code:(NSString *)code message:(NSString *)message status:(NSString *)status {
  UTSBaiduNavBridgePayloadCompletion completion = self.startCompletion;
  self.startCompletion = nil;
  if (completion != nil) {
    completion([UtsBaiduNavBridge navigationPayloadWithSuccess:success
                                                          code:code
                                                       message:message
                                                  navigationId:self.navigationId
                                                        status:status]);
  }
}

- (void)finishReplanSuccess:(BOOL)success code:(NSString *)code message:(NSString *)message status:(NSString *)status {
  UTSBaiduNavBridgePayloadCompletion completion = self.replanCompletion;
  self.replanCompletion = nil;
  if (completion != nil) {
    completion([UtsBaiduNavBridge navigationPayloadWithSuccess:success
                                                          code:code
                                                       message:message
                                                  navigationId:self.navigationId
                                                        status:status]);
  }
}

- (void)clearNavigationState {
  self.navigationActive = NO;
  self.stoppingNavigation = NO;
  self.usesSdkUI = NO;
  self.startToken += 1;
  self.replanToken += 1;
  self.startCompletion = nil;
  self.replanCompletion = nil;
  [[BNaviModel getInstance] removeNaviModelListener:self];
  self.routeNodes = @[];
  self.navigationId = @"";
}

- (void)applyNavigationPresentationOptions {
  BNaviService_Strategy.naviSpeakMode = self.voiceEnabled ? BN_SpeakMode_Real_Play : BN_SpeakMode_Real_Mute;
  if (self.cameraFollowingEnabled) {
    [[BNaviModel getInstance] mapExitViewAllMode];
  } else {
    [[BNaviModel getInstance] mapEnterViewAllMode];
  }
}

+ (void)startNavigationWithOptions:(NSDictionary<NSString *, id> *)options
                      eventHandler:(UTSBaiduNavBridgeEventHandler)eventHandler
                        completion:(UTSBaiduNavBridgePayloadCompletion)completion {
  [self performOnMainThread:^{
    UtsBaiduNavBridge *bridge = [self sharedBridge];
    if (![[BNaviService getInstance] isServicesInited]) {
      completion([self navigationPayloadWithSuccess:NO
                                                code:@"BAIDU_NAVSDK_NOT_INITIALIZED"
                                             message:@"Baidu navigation SDK services are not initialized."
                                        navigationId:@""
                                              status:@"failed"]);
      return;
    }
    if (bridge.navigationActive || bridge.startCompletion != nil) {
      completion([self navigationPayloadWithSuccess:NO
                                                code:@"BAIDU_NAVSDK_SESSION_ACTIVE"
                                             message:@"A Baidu navigation session is already active."
                                        navigationId:bridge.navigationId
                                              status:@"failed"]);
      return;
    }
    NSArray<BNRoutePlanNode *> *nodes = [self routeNodesFromOptions:options];
    if (nodes == nil || nodes.count < 2) {
      completion([self navigationPayloadWithSuccess:NO
                                                code:@"BAIDU_NAVSDK_INVALID_ROUTE_NODES"
                                             message:@"Valid Baidu coordinates are required for start, waypoints, and end."
                                        navigationId:@""
                                              status:@"failed"]);
      return;
    }
    UIViewController *host = [self hostViewController];
    if (host == nil) {
      completion([self navigationPayloadWithSuccess:NO
                                                code:@"BAIDU_NAVSDK_HOST_VIEW_CONTROLLER_MISSING"
                                             message:@"The host view controller is unavailable."
                                        navigationId:@""
                                              status:@"failed"]);
      return;
    }
    NSString *navigationId = [options[@"navigationId"] isKindOfClass:[NSString class]] ? options[@"navigationId"] : @"";
    bridge.navigationId = navigationId.length > 0 ? navigationId : [NSString stringWithFormat:@"ios-navigation-%lld", (long long)(NSDate.date.timeIntervalSince1970 * 1000.0)];
    bridge.naviType = [options[@"isSimulateNavigationEnabled"] boolValue] ? BN_NaviTypeSimulator : BN_NaviTypeReal;
    bridge.voiceEnabled = options[@"isVoiceBroadcastEnabled"] == nil || [options[@"isVoiceBroadcastEnabled"] boolValue];
    bridge.cameraFollowingEnabled = options[@"isCameraFollowingLocationEnabled"] == nil || [options[@"isCameraFollowingLocationEnabled"] boolValue];
    NSString *navigationUiMode = [options[@"navigationUiMode"] isKindOfClass:[NSString class]] ? options[@"navigationUiMode"] : @"sdk";
    bridge.usesSdkUI = ![navigationUiMode isEqualToString:@"none"];
    bridge.routeNodes = nodes;
    bridge.eventHandler = eventHandler;
    bridge.startCompletion = completion;
    bridge.navigationActive = NO;
    bridge.stoppingNavigation = NO;
    bridge.startToken += 1;
    NSUInteger token = bridge.startToken;
    [[BNaviModel getInstance] addNaviModelListener:bridge];
    id<BNRoutePlanManagerProtocol> routePlanManager = BNaviService_RoutePlan;
    if (routePlanManager == nil) {
      [bridge finishStartSuccess:NO
                            code:@"BAIDU_NAVSDK_ROUTE_MANAGER_MISSING"
                         message:@"Baidu navigation route-plan manager is unavailable."
                          status:@"failed"];
      [bridge clearNavigationState];
      return;
    }
    BOOL respondsToSuccess = [bridge respondsToSelector:@selector(routePlanDidFinished:)];
    BOOL respondsToFailure = [bridge respondsToSelector:@selector(routePlanDidFailedWithError:andUserInfo:)];
    BOOL respondsToCancel = [bridge respondsToSelector:@selector(routePlanDidUserCanceled:)];
    [bridge emitEventType:@"routeProgressUpdated"
                   status:@"rerouting"
                   extras:@{
                     @"instructionText": @"iOS NavSDK navigation request accepted.",
                     @"nativeDiagnostic": @{
                       @"isMainThread": @([NSThread isMainThread]),
                       @"servicesInitialized": @([[BNaviService getInstance] isServicesInited]),
                       @"nodeCount": @(nodes.count),
                       @"respondsToSuccess": @(respondsToSuccess),
                       @"respondsToFailure": @(respondsToFailure),
                       @"respondsToCancel": @(respondsToCancel)
                     }
                   }];
    NSLog(@"[UtsBaiduNavBridge] routePlan before nodes=%lu simulate=%d", (unsigned long)nodes.count, bridge.naviType == BN_NaviTypeSimulator);
    [routePlanManager startNaviRoutePlan:BNRoutePlanMode_Recommend
                               naviNodes:nodes
                                    time:nil
                                delegete:bridge
                                userInfo:nil];
    NSLog(@"[UtsBaiduNavBridge] routePlan after");
    NSInteger acceptedNodeCount = [routePlanManager getCurNodeCount];
    int acceptedRoutePlanMode = [routePlanManager getCurRoutePlanMode];
    [bridge emitEventType:@"routeProgressUpdated"
                   status:@"rerouting"
                   extras:@{
                     @"instructionText": @"iOS NavSDK route-plan request dispatched.",
                     @"nativeDiagnostic": @{
                       @"acceptedNodeCount": @(acceptedNodeCount),
                       @"acceptedRoutePlanMode": @(acceptedRoutePlanMode),
                       @"isMainThread": @([NSThread isMainThread])
                     }
                   }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(UTSBaiduNavBridgeRouteTimeout * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      if (bridge.startCompletion == nil || bridge.startToken != token) {
        return;
      }
      NSString *timeoutMessage = [NSString stringWithFormat:@"Baidu navigation route planning timed out. managerNodeCount=%ld routePlanMode=%d mainThread=%d delegateSuccess=%d delegateFailure=%d delegateCancel=%d",
                                  (long)[routePlanManager getCurNodeCount],
                                  [routePlanManager getCurRoutePlanMode],
                                  [NSThread isMainThread],
                                  respondsToSuccess,
                                  respondsToFailure,
                                  respondsToCancel];
      NSDictionary *failure = [self navigationPayloadWithSuccess:NO
                                                              code:@"BAIDU_NAVSDK_ROUTE_PLAN_TIMEOUT"
                                                           message:timeoutMessage
                                                      navigationId:bridge.navigationId
                                                            status:@"failed"];
      [bridge emitEventType:@"navigationFailed" status:@"failed" extras:@{@"error": failure}];
      [bridge finishStartSuccess:NO
                            code:@"BAIDU_NAVSDK_ROUTE_PLAN_TIMEOUT"
                         message:timeoutMessage
                          status:@"failed"];
      [bridge clearNavigationState];
    });
  }];
}

+ (void)replanNavigationWithCompletion:(UTSBaiduNavBridgePayloadCompletion)completion {
  [self performOnMainThread:^{
    UtsBaiduNavBridge *bridge = [self sharedBridge];
    if (!bridge.navigationActive || bridge.routeNodes.count < 2) {
      completion([self navigationPayloadWithSuccess:NO code:@"BAIDU_NAVSDK_SESSION_MISSING" message:@"No active Baidu navigation session is available." navigationId:bridge.navigationId status:@"failed"]);
      return;
    }
    if (bridge.replanCompletion != nil) {
      completion([self navigationPayloadWithSuccess:NO code:@"BAIDU_NAVSDK_REPLAN_ACTIVE" message:@"A Baidu navigation replan operation is already active." navigationId:bridge.navigationId status:@"rerouting"]);
      return;
    }
    bridge.replanCompletion = completion;
    bridge.replanToken += 1;
    NSUInteger token = bridge.replanToken;
    [bridge emitEventType:@"routeProgressUpdated" status:@"rerouting" extras:@{@"instructionText": @"iOS NavSDK route replanning started."}];
    [[BNaviModel getInstance] reCalculateRoutePlan:BNRoutePlanMode_Recommend
                                         naviNodes:bridge.routeNodes
                                          userInfo:@{BNaviTripTypeKey: @(BN_NaviTypeReal)}];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(UTSBaiduNavBridgeRouteTimeout * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      if (bridge.replanCompletion == nil || bridge.replanToken != token) {
        return;
      }
      [bridge finishReplanSuccess:NO code:@"BAIDU_NAVSDK_REPLAN_TIMEOUT" message:@"Baidu navigation route replanning timed out." status:@"failed"];
    });
  }];
}

+ (void)stopNavigationWithCompletion:(UTSBaiduNavBridgePayloadCompletion)completion {
  [self performOnMainThread:^{
    UtsBaiduNavBridge *bridge = [self sharedBridge];
    NSString *navigationId = bridge.navigationId;
    if (!bridge.navigationActive && bridge.startCompletion == nil) {
      completion([self navigationPayloadWithSuccess:YES code:@"BAIDU_NAVSDK_ALREADY_STOPPED" message:@"No active Baidu navigation session." navigationId:navigationId status:@"cancelled"]);
      return;
    }
    bridge.stoppingNavigation = YES;
    [bridge emitEventType:@"navigationStopped" status:@"cancelled" extras:@{@"instructionText": @"stopRouteNavigation called."}];
    NSDictionary *payload = [self navigationPayloadWithSuccess:YES code:@"BAIDU_NAVSDK_NAVIGATION_STOPPED" message:@"Baidu navigation stopped." navigationId:navigationId status:@"cancelled"];
    if (bridge.navigationActive && bridge.usesSdkUI) {
      [BNaviService_UI exitPage:EN_BNavi_ExitAllVC animated:YES extraInfo:@{}];
    } else if (bridge.navigationActive) {
      [BNaviService_naviCoreLogicManager stopNavi:bridge.naviType extParam:nil];
    }
    completion(payload);
    if ([bridge.navigationId isEqualToString:navigationId]) {
      [bridge clearNavigationState];
    }
  }];
}

+ (void)pauseNavigationWithCompletion:(UTSBaiduNavBridgePayloadCompletion)completion {
  [self performOnMainThread:^{
    UtsBaiduNavBridge *bridge = [self sharedBridge];
    if (!bridge.navigationActive) {
      completion([self navigationPayloadWithSuccess:NO code:@"BAIDU_NAVSDK_SESSION_MISSING" message:@"No active Baidu navigation session is available." navigationId:bridge.navigationId status:@"failed"]);
      return;
    }
    if (bridge.naviType == BN_NaviTypeSimulator) {
      [[BNaviModel getInstance] pauseSimulator];
    }
    [bridge emitEventType:@"navigationPaused" status:@"paused" extras:nil];
    completion([self navigationPayloadWithSuccess:YES code:@"BAIDU_NAVSDK_NAVIGATION_PAUSED" message:@"Baidu navigation pause requested." navigationId:bridge.navigationId status:@"paused"]);
  }];
}

+ (void)resumeNavigationWithCompletion:(UTSBaiduNavBridgePayloadCompletion)completion {
  [self performOnMainThread:^{
    UtsBaiduNavBridge *bridge = [self sharedBridge];
    if (!bridge.navigationActive) {
      completion([self navigationPayloadWithSuccess:NO code:@"BAIDU_NAVSDK_SESSION_MISSING" message:@"No active Baidu navigation session is available." navigationId:bridge.navigationId status:@"failed"]);
      return;
    }
    if (bridge.naviType == BN_NaviTypeSimulator) {
      [[BNaviModel getInstance] resumeSimulator];
    }
    [bridge emitEventType:@"navigationResumed" status:@"navigating" extras:nil];
    completion([self navigationPayloadWithSuccess:YES code:@"BAIDU_NAVSDK_NAVIGATION_RESUMED" message:@"Baidu navigation resume requested." navigationId:bridge.navigationId status:@"navigating"]);
  }];
}

+ (void)setNavigationVoiceEnabled:(BOOL)enabled completion:(UTSBaiduNavBridgePayloadCompletion)completion {
  [self performOnMainThread:^{
    UtsBaiduNavBridge *bridge = [self sharedBridge];
    if (!bridge.navigationActive) {
      completion([self navigationPayloadWithSuccess:NO code:@"BAIDU_NAVSDK_SESSION_MISSING" message:@"No active Baidu navigation session is available." navigationId:bridge.navigationId status:@"failed"]);
      return;
    }
    BNaviService_Strategy.naviSpeakMode = enabled ? BN_SpeakMode_Real_Play : BN_SpeakMode_Real_Mute;
    bridge.voiceEnabled = enabled;
    NSString *message = enabled ? @"Baidu navigation voice enabled." : @"Baidu navigation voice disabled.";
    [bridge emitEventType:@"voiceInstructionUpdated" status:@"navigating" extras:@{@"voiceInstructionText": message}];
    completion([self navigationPayloadWithSuccess:YES code:@"BAIDU_NAVSDK_VOICE_UPDATED" message:message navigationId:bridge.navigationId status:@"navigating"]);
  }];
}

+ (void)setNavigationCameraFollowingEnabled:(BOOL)enabled completion:(UTSBaiduNavBridgePayloadCompletion)completion {
  [self performOnMainThread:^{
    UtsBaiduNavBridge *bridge = [self sharedBridge];
    if (!bridge.navigationActive) {
      completion([self navigationPayloadWithSuccess:NO code:@"BAIDU_NAVSDK_SESSION_MISSING" message:@"No active Baidu navigation session is available." navigationId:bridge.navigationId status:@"failed"]);
      return;
    }
    if (enabled) {
      [[BNaviModel getInstance] mapExitViewAllMode];
    } else {
      [[BNaviModel getInstance] mapEnterViewAllMode];
    }
    bridge.cameraFollowingEnabled = enabled;
    completion([self navigationPayloadWithSuccess:YES code:@"BAIDU_NAVSDK_CAMERA_UPDATED" message:@"Baidu navigation camera mode updated." navigationId:bridge.navigationId status:@"navigating"]);
  }];
}

#pragma mark - BNNaviRoutePlanDelegate

- (void)routePlanDidFinished:(NSDictionary *)userInfo {
  NSLog(@"[UtsBaiduNavBridge] routePlan success callback");
  if (self.startCompletion == nil) {
    return;
  }
  self.startToken += 1;
  self.navigationActive = YES;
  @try {
    if (self.usesSdkUI) {
      [BNaviService_UI showPage:BNaviUI_NormalNavi
                       delegate:self
                      extParams:@{BNaviUI_NormalNavi_TypeKey: @(self.naviType)}];
      [self emitEventType:@"navigationStarted" status:@"navigating" extras:@{@"instructionText": @"iOS NavSDK navigation started with SDK UI."}];
      [self finishStartSuccess:YES code:@"BAIDU_NAVSDK_NAVIGATION_STARTED" message:@"Baidu navigation route planned and SDK UI started." status:@"navigating"];
      return;
    }
    [self applyNavigationPresentationOptions];
    NSError *startError = [BNaviService_naviCoreLogicManager startNavi:self.naviType extParam:nil];
    if (startError != nil && startError.code > 0) {
      NSString *message = startError.localizedDescription ?: @"Baidu navigation core failed to start.";
      NSDictionary *failure = [UtsBaiduNavBridge navigationPayloadWithSuccess:NO code:[NSString stringWithFormat:@"%ld", (long)startError.code] message:message navigationId:self.navigationId status:@"failed"];
      [self emitEventType:@"navigationFailed" status:@"failed" extras:@{@"error": failure}];
      [self finishStartSuccess:NO code:@"BAIDU_NAVSDK_CORE_START_FAILED" message:message status:@"failed"];
      [self clearNavigationState];
      return;
    }
    [self emitEventType:@"navigationStarted" status:@"navigating" extras:@{@"instructionText": @"iOS NavSDK no-UI navigation started."}];
    [self finishStartSuccess:YES code:@"BAIDU_NAVSDK_NAVIGATION_STARTED" message:@"Baidu navigation route planned and no-UI navigation started." status:@"navigating"];
  } @catch (NSException *exception) {
    NSString *failureCode = self.usesSdkUI ? @"BAIDU_NAVSDK_UI_START_FAILED" : @"BAIDU_NAVSDK_CORE_START_FAILED";
    NSString *fallbackMessage = self.usesSdkUI ? @"Baidu navigation UI failed to start." : @"Baidu navigation core failed to start.";
    NSString *failureMessage = exception.reason ?: fallbackMessage;
    NSDictionary *failure = [UtsBaiduNavBridge navigationPayloadWithSuccess:NO code:failureCode message:failureMessage navigationId:self.navigationId status:@"failed"];
    [self emitEventType:@"navigationFailed" status:@"failed" extras:@{@"error": failure}];
    [self finishStartSuccess:NO code:failureCode message:failureMessage status:@"failed"];
    [self clearNavigationState];
  }
}

- (void)routePlanDidFailedWithError:(NSError *)error andUserInfo:(NSDictionary *)userInfo {
  NSLog(@"[UtsBaiduNavBridge] routePlan failure callback code=%ld", (long)error.code);
  NSString *message = error.localizedDescription ?: @"Baidu navigation route planning failed.";
  NSDictionary *failure = [UtsBaiduNavBridge navigationPayloadWithSuccess:NO code:[NSString stringWithFormat:@"%ld", (long)error.code] message:message navigationId:self.navigationId status:@"failed"];
  [self emitEventType:@"navigationFailed" status:@"failed" extras:@{@"error": failure}];
  [self finishStartSuccess:NO code:@"BAIDU_NAVSDK_ROUTE_PLAN_FAILED" message:message status:@"failed"];
  [self clearNavigationState];
}

- (void)routePlanDidUserCanceled:(NSDictionary *)userInfo {
  [self finishStartSuccess:NO code:@"BAIDU_NAVSDK_ROUTE_PLAN_CANCELLED" message:@"Baidu navigation route planning was cancelled." status:@"cancelled"];
  [self clearNavigationState];
}

#pragma mark - BNNaviUIManagerDelegate

- (id)naviPresentedViewController {
  return [UtsBaiduNavBridge hostViewController];
}

- (void)willExitPage:(BNaviUIType)pageType extraInfo:(NSDictionary *)extraInfo {
  NSLog(@"[UtsBaiduNavBridge] navigation UI will exit page=%d", pageType);
}

- (void)onExitPage:(BNaviUIType)pageType extraInfo:(NSDictionary *)extraInfo {
  NSLog(@"[UtsBaiduNavBridge] navigation UI exited page=%d", pageType);
  if (!self.stoppingNavigation && self.navigationId.length > 0) {
    [self emitEventType:@"navigationStopped" status:@"cancelled" extras:@{@"instructionText": @"iOS NavSDK UI exited."}];
  }
  [self clearNavigationState];
}

- (void)onHandleNaviViewDidLoad:(UIView *)naviView {
  NSLog(@"[UtsBaiduNavBridge] navigation UI view loaded");
  [self applyNavigationPresentationOptions];
}

#pragma mark - BNaviModelDelegate

- (void)onHandleCurrentRoadName:(BNaviCurrentRoadName *)currentRoadName {
  [self emitEventType:@"routeProgressUpdated" status:@"navigating" extras:@{@"currentRoadName": currentRoadName.curRoadName ?: @""}];
}

- (void)onHandleRemainInfo:(BNaviRemainInfo *)remainInfo {
  [self emitEventType:@"routeProgressUpdated" status:@"navigating" extras:@{
    @"remainingDistanceInMeters": @(remainInfo.remainDist),
    @"remainingDurationInSeconds": @(remainInfo.remainTime)
  }];
}

- (void)onHandleSimpleGuideInfo:(BNaviSimpleGuideInfo *)simpleGuideInfo {
  [self emitEventType:@"routeProgressUpdated" status:@"navigating" extras:@{
    @"currentRoadName": simpleGuideInfo.curRoadName ?: @"",
    @"nextRoadName": simpleGuideInfo.nextRoadName ?: @"",
    @"instructionText": simpleGuideInfo.nextRoadName ?: @""
  }];
}

- (void)naviYawingDidStart:(BNaviModel *)model withStamp:(NSString *)yawingStamp {
  [self emitEventType:@"routeDeviationDetected" status:@"rerouting" extras:@{@"instructionText": yawingStamp ?: @""}];
}

- (void)onHandleNaviRouteWillRefresh {
  [self emitEventType:@"routeProgressUpdated" status:@"rerouting" extras:@{@"instructionText": @"iOS NavSDK route refresh started."}];
}

- (void)onHandleNaviRouteDidRefreshWithType:(BNaviMessage_OtherRoute_Enum)type {
  [self emitEventType:@"routeProgressUpdated" status:@"navigating" extras:@{@"instructionText": [NSString stringWithFormat:@"iOS NavSDK route refresh result=%ld.", (long)type]}];
}

- (void)onHandleNaviStatusChange:(BNaviStatusInfo *)naviStatusInfo {
  if (naviStatusInfo.eNaviStatusType == BNaviStatus_Type_End2) {
    [self emitEventType:@"navigationArrived" status:@"arrived" extras:nil];
  }
}

- (void)reCalculateNaviRouteDidFinished:(BNaviModel *)model sourceType:(BNCalculateSourceType)sourceType {
  self.replanToken += 1;
  [self emitEventType:@"routeProgressUpdated" status:@"navigating" extras:@{@"instructionText": @"iOS NavSDK route replanning succeeded."}];
  [self finishReplanSuccess:YES code:@"BAIDU_NAVSDK_REPLAN_SUCCEEDED" message:@"Baidu navigation route replanning succeeded." status:@"navigating"];
}

- (void)reCalculateNaviRouteDidFailed:(BNaviModel *)model sourceType:(BNCalculateSourceType)sourceType {
  self.replanToken += 1;
  [self finishReplanSuccess:NO code:@"BAIDU_NAVSDK_REPLAN_FAILED" message:@"Baidu navigation route replanning failed." status:@"failed"];
}

- (void)reCalculateNaviRouteDidCancel:(BNaviModel *)model sourceType:(BNCalculateSourceType)sourceType {
  self.replanToken += 1;
  [self finishReplanSuccess:NO code:@"BAIDU_NAVSDK_REPLAN_CANCELLED" message:@"Baidu navigation route replanning was cancelled." status:@"cancelled"];
}

+ (void)stopServices {
  [self performOnMainThread:^{
    UtsBaiduNavBridge *bridge = [self sharedBridge];
    if (bridge.navigationActive) {
      [BNaviService_naviCoreLogicManager stopNavi:bridge.naviType extParam:nil];
    }
    [BNaviService_Sound releaseInstance];
    [bridge clearNavigationState];
  }];
}

@end
