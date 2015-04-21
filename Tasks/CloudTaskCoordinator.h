//
//  TaskCoordinator.h
//  Tasks
//
//  Created by Henry W Lu on 11/26/14.
//  Copyright (c) 2014 Henry W Lu. All rights reserved.
//

@import Foundation;

@interface CloudTaskCoordinator : NSObject <TaskCoordinator>

- (instancetype)initWithPathExtension:(NSString *)pathExtension firstQueryUpdateHandler:(void (^)(void))firstQueryUpdateHandler;

- (instancetype)initWithLastPathComponent:(NSString *)lastPathComponent firstQueryUpdateHandler:(void (^)(void))firstQueryUpdateHandler;

@end
