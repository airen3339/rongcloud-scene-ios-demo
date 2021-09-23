//
//  RCMessageContentAdmin.m
//  RCE
//
//  Created by shaoshuai on 2021/7/15.
//

#import "RCCRSSetAdminMessage.h"
#import "RCUserInfo+Coding.h"
#import "RCCRSReceiverProtocol.h"
#import "RCCRSHandlerProtocol.h"

@implementation RCCRSSetAdminMessage

- (NSData *)encode {
    NSMutableDictionary *mutableDict = [NSMutableDictionary dictionary];
    if (_userInfo) [mutableDict setObject:[RCUserInfo encode:_userInfo] forKey:@"_userInfo"];
    if (_targetUserInfo) [mutableDict setObject:[RCUserInfo encode:_targetUserInfo] forKey:@"_targetUserInfo"];
    if (self.extra) [mutableDict setObject:self.extra forKey:@"_extra"];
    return [NSJSONSerialization dataWithJSONObject:mutableDict options:kNilOptions error:nil];
}

- (void)decodeWithData:(NSData *)data {
    if (data == nil) return;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
    NSDictionary *json = [[NSDictionary alloc] initWithDictionary:dictionary];
    if (json == nil) return;
    _userInfo = [RCUserInfo decode:[json objectForKey:@"_userInfo"]];
    _targetUserInfo = [RCUserInfo decode:[json objectForKey:@"_targetUserInfo"]];
    self.extra = [json objectForKey:@"_extra"];
}

+ (NSString *)getObjectName {
  return @"RC:CRSSetAdminMsg";
}

- (NSArray<NSString *> *)getSearchableWords {
  return nil;
}

+ (RCMessagePersistent)persistentFlag {
  return MessagePersistent_NONE;
}

@end

@interface RCCRSSetAdminMessage (handler) <RCCRSHandlerProtocol>

@end

@implementation RCCRSSetAdminMessage (handler)

- (void)handleMessage:(RCMessage *)message toReceiver:(id<RCCRSReceiverProtocol>)receiver {
    [receiver setAdminMessageDidReceive:self];
}

@end