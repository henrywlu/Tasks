//  TaskPresenting.h
//  Tasks
//
//  Created by Henry W Lu on 3/26/15.
//  Copyright (c) 2015 Henry W Lu. All rights reserved.
//

@import Foundation;
#import "Task.h"

@protocol TaskPresenterDelegate;
@protocol TaskPresenting <NSObject>
@property (nonatomic, weak) id<TaskPresenterDelegate> delegate;
@property TaskColor color;
@property (readonly, copy) Task *archiveableTask;
@property (readonly, copy) NSArray *presentedTaskItems;
@property (readonly) NSInteger count;
@property (readonly, getter=isEmpty) BOOL empty;
- (void)setTask:(Task *)task;
@end