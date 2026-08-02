//
//  ObjectiveCExceptionCatcher.m
//  passKit
//
//  Copyright © 2026 Bob Sun. All rights reserved.
//

#import "ObjectiveCExceptionCatcher.h"

NSString *const ObjectiveCExceptionErrorDomain = @"ObjectiveCExceptionErrorDomain";

@implementation ObjectiveCExceptionCatcher

+ (BOOL)catchException:(NS_NOESCAPE void (^)(void))block error:(NSError **)error {
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        if (error != NULL) {
            NSMutableDictionary<NSErrorUserInfoKey, id> *userInfo = [NSMutableDictionary dictionary];
            userInfo[NSLocalizedDescriptionKey] = exception.reason ?: exception.name;
            userInfo[NSDebugDescriptionErrorKey] = exception.description;
            *error = [NSError errorWithDomain:ObjectiveCExceptionErrorDomain code:0 userInfo:userInfo];
        }
        return NO;
    }
}

@end
