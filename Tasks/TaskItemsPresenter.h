//
//  TaskItemsPresenter.h
//  Tasks
//
//  Created by Henry W Lu on 3/26/15.
//  Copyright (c) 2015 Henry W Lu. All rights reserved.
//

#import "TaskPresenting.h"

@class TaskItem;

@interface AllTaskItemsPresenter : NSObject <TaskPresenting>

@property NSUndoManager *undoManager;

- (void)insertTaskItem:(TaskItem *)taskItem;
- (void)insertTaskItems:(NSArray *)taskItems;
- (void)removeTaskItem:(TaskItem *)taskItem;
- (void)removeTaskItems:(NSArray *)taskItems;
- (void)updateTaskItem:(TaskItem *)taskItem withText:(NSString *)newText;
- (BOOL)canMoveTaskItem:(TaskItem *)taskItem toIndex:(NSInteger)toIndex;
- (void)moveTaskItem:(TaskItem *)taskItem toIndex:(NSInteger)toIndex;
- (void)toggleTaskItem:(TaskItem *)taskItem;
- (void)updatePresentedTaskItemsToCompletionState:(BOOL)completionState;

@end
