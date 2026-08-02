//
//  ObjectiveCExceptionCatcher.h
//  passKit
//
//  Copyright © 2026 Bob Sun. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const ObjectiveCExceptionErrorDomain;

/// Runs a block and turns any Objective-C exception raised by it into an `NSError`. Swift cannot
/// catch `NSException`s, so calls into Objective-C libraries which raise them (like ObjectivePGP on
/// malformed input) have to be routed through this class to not terminate the app.
@interface ObjectiveCExceptionCatcher : NSObject

+ (BOOL)catchException:(NS_NOESCAPE void (^)(void))block error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
