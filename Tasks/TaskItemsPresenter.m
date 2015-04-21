//
//  TaskItemsPresenter.m
//  Tasks
//
//  Created by Henry W Lu on 3/26/15.
//  Copyright (c) 2015 Henry W Lu. All rights reserved.
//

#import "AllTaskItemsPresenter.h"
#import "TaskPresenterDelegate.h"
#import "Task.h"
#import "TaskItem.h"
#import "TaskPresenterAlgorithms.h"
#import "TaskPresenterUtilities.h"

@interface AllTaskItemsPresenter ()

@property (readwrite, nonatomic) Task *task;

@property (getter=isInitialTask) BOOL initialTask;

@property (readonly) NSInteger indexOfFirstCompleteItem;

@end

@implementation AllTaskItemsPresenter
@synthesize delegate = _delegate;
@dynamic color;

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];

    if (self) {
        _task = [[Task alloc] initWithColor:TaskColorGray items:@[]];
        _initialTask = YES;
    }
    
    return self;
}

#pragma mark - TaskItemPresenter

- (void)setColor:(TaskColor)color {
    TaskColor oldColor = self.color;
    
    BOOL different = UpdateTaskColorForTaskPresenterIfDifferent(self, self.task, color, TaskColorUpdateActionSendDelegateChangeLayoutCallsForNonInitialLayout);
    
    if (different) {
        [[self.undoManager prepareWithInvocationTarget:self] setColor:oldColor];
        
        NSString *undoActionName = NSLocalizedString(@"Change Color", nil);
        [self.undoManager setActionName:undoActionName];
    }
}

- (TaskColor)color {
    return self.task.color;
}

- (Task *)archiveableTask {
    return self.task;
}

- (NSArray *)presentedTaskItems {
    return [self.task items];
}

- (void)setTask:(Task *)newTask {

    if (self.isInitialTask) {
        self.initialTask = NO;
        
        _task = newTask;
        newTask.items = [self reorderedTaskItemsFromTaskItems:newTask.items];
        
        [self.delegate taskPresenterDidRefreshCompleteLayout:self];
        
        return;
    }
    

    Task *oldTask = self.task;
    
    NSArray *newRemovedTaskItems = FindRemovedTaskItemsFromInitialTaskItemsToChangedTaskItems(oldTask.items, newTask.items);
    NSArray *newInsertedTaskItems = FindInsertedTaskItemsFromInitialTaskItemsToChangedTaskItems(oldTask.items, newTask.items, nil);
    NSArray *newToggledTaskItems = FindToggledTaskItemsFromInitialTaskItemsToChangedTaskItems(oldTask.items, newTask.items);
    NSArray *newTaskItemsWithUpdatedText = FindTaskItemsWithUpdatedTextFromInitialTaskItemsToChangedTaskItems(oldTask.items, newTask.items);
    

    TaskItemsBatchChangeKind taskItemsBatchChangeKind = TaskItemsBatchChangeKindForChanges(newRemovedTaskItems, newInsertedTaskItems, newToggledTaskItems, newTaskItemsWithUpdatedText);
    
    if (taskItemsBatchChangeKind == TaskItemsBatchChangeKindNone) {
        if (oldTask.color != newTask.color) {
            [self.undoManager removeAllActionsWithTarget:self];
            
            UpdateTaskColorForTaskPresenterIfDifferent(self, self.task, newTask.color, TaskColorUpdateActionSendDelegateChangeLayoutCallsForInitialLayout);
        }
        
        return;
    }
    
    if (taskItemsBatchChangeKind == TaskItemsBatchChangeKindMultiple || newToggledTaskItems.count > 1 || newInsertedTaskItems.count > 1) {
        [self.undoManager removeAllActionsWithTarget:self];
        
        _task = newTask;
        newTask.items = [self reorderedTaskItemsFromTaskItems:newTask.items];
        
        [self.delegate taskPresenterDidRefreshCompleteLayout:self];
        
        return;
    }
    
    [self.undoManager removeAllActionsWithTarget:self];
    
    [self.delegate taskPresenterWillChangeTaskLayout:self isInitialLayout:YES];
    
    switch (taskItemsBatchChangeKind) {
        case TaskItemsBatchChangeKindRemoved: {
            NSMutableArray *oldTaskItemsMutableProxy = [self.task mutableArrayValueForKey:@"items"];

            RemoveTaskItemsFromTaskItemsWithTaskPresenter(self, oldTaskItemsMutableProxy, newRemovedTaskItems);

            break;
        }
        case TaskItemsBatchChangeKindInserted: {
            [self unsafeInsertTaskItem:newInsertedTaskItems.firstObject];

            break;
        }
        case TaskItemsBatchChangeKindToggled: {
            
            NSInteger indexOfToggledTaskItemInOldTaskItems = [oldTask.items indexOfObject:newToggledTaskItems.firstObject];
            
            TaskItem *taskItemToToggle = oldTask.items[indexOfToggledTaskItemInOldTaskItems];
            
            [self unsafeToggleTaskItem:taskItemToToggle];

            break;
        }
        case TaskItemsBatchChangeKindUpdatedText: {
            NSMutableArray *oldTaskItemsMutableProxy = [self.task mutableArrayValueForKey:@"items"];

            UpdateTaskItemsWithTaskItemsForTaskPresenter(self, oldTaskItemsMutableProxy, newTaskItemsWithUpdatedText);

            break;
        }

        default: abort();
    }
    
    UpdateTaskColorForTaskPresenterIfDifferent(self, self.task, newTask.color, TaskColorUpdateActionDontSendDelegateChangeLayoutCalls);
    
    [self.delegate taskPresenterDidChangeTaskLayout:self isInitialLayout:YES];
}

- (NSInteger)count {
    return self.presentedTaskItems.count;
}

- (BOOL)isEmpty {
    return self.presentedTaskItems.count == 0;
}

#pragma mark - Public Methods

- (void)insertTaskItem:(TaskItem *)taskItem {
    [self.delegate taskPresenterWillChangeTaskLayout:self isInitialLayout:NO];
    
    [self unsafeInsertTaskItem:taskItem];
    
    [self.delegate taskPresenterDidChangeTaskLayout:self isInitialLayout:NO];
    
    [[self.undoManager prepareWithInvocationTarget:self] removeTaskItem:taskItem];
    
    NSString *undoActionName = NSLocalizedString(@"Remove", nil);
    [self.undoManager setActionName:undoActionName];
}

- (void)insertTaskItems:(NSArray *)taskItems {
    if (taskItems.count == 0) {
        return;
    }
    
    [self.delegate taskPresenterWillChangeTaskLayout:self isInitialLayout:NO];
    
    for (TaskItem *taskItem in taskItems) {
        [self unsafeInsertTaskItem:taskItem];
    }
    
    [self.delegate taskPresenterDidChangeTaskLayout:self isInitialLayout:NO];
    
    [[self.undoManager prepareWithInvocationTarget:self] removeTaskItems:taskItems];
    
    NSString *undoActionName = NSLocalizedString(@"Remove", nil);
    [self.undoManager setActionName:undoActionName];
}

- (void)removeTaskItem:(TaskItem *)taskItem {
    NSInteger taskItemIndex = [self.presentedTaskItems indexOfObject:taskItem];
    
    NSAssert(taskItemIndex != NSNotFound, @"To remove a task item, it must already be in the task.");
    
    [self.delegate taskPresenterWillChangeTaskLayout:self isInitialLayout:NO];
    
    [[self.task mutableArrayValueForKey:@"items"] removeObjectAtIndex:taskItemIndex];
    
    [self.delegate taskPresenter:self didRemoveTaskItem:taskItem atIndex:taskItemIndex];
    
    [self.delegate taskPresenterDidChangeTaskLayout:self isInitialLayout:NO];
    
    [[self.undoManager prepareWithInvocationTarget:self] insertTaskItemsForUndo:@[taskItem] atIndexes:@[@(taskItemIndex)]];
    
    NSString *undoActionName = NSLocalizedString(@"Remove", nil);
    [self.undoManager setActionName:undoActionName];
}

- (void)removeTaskItems:(NSArray *)taskItemsToRemove {
    if (taskItemsToRemove.count == 0) {
        return;
    }
    
    NSMutableArray *taskItems = [self.task mutableArrayValueForKey:@"items"];

    NSMutableArray *removedIndexes = [NSMutableArray array];

    for (TaskItem *taskItem in taskItemsToRemove) {
        NSInteger taskItemIndex = [self.presentedTaskItems indexOfObject:taskItem];
        
        NSAssert(taskItemIndex != NSNotFound, @"Task items to remove must already be in the task.");
        
        [taskItems removeObjectAtIndex:taskItemIndex];
        
        [self.delegate taskPresenter:self didRemoveTaskItem:taskItem atIndex:taskItemIndex];
        
        [removedIndexes addObject:@(taskItemIndex)];
    }
    
    [self.delegate taskPresenterDidChangeTaskLayout:self isInitialLayout:NO];

    NSArray *reverseTaskItemsToRemove = [[taskItemsToRemove reverseObjectEnumerator] allObjects];
    NSArray *reverseRemovedIndexes = [[removedIndexes reverseObjectEnumerator] allObjects];
    [[self.undoManager prepareWithInvocationTarget:self] insertTaskItemsForUndo:reverseTaskItemsToRemove atIndexes:reverseRemovedIndexes];
    
    NSString *undoActionName = NSLocalizedString(@"Remove", nil);
    [self.undoManager setActionName:undoActionName];
}

- (void)updateTaskItem:(TaskItem *)taskItem withText:(NSString *)newText {
    NSInteger taskItemIndex = [self.presentedTaskItems indexOfObject:taskItem];
    
    NSAssert(taskItemIndex != NSNotFound, @"A task item can only be updated if it already exists in the task.");
    
    if ([taskItem.text isEqualToString:newText]) {
        return;
    }
    
    NSString *oldText = taskItem.text;
    
    [self.delegate taskPresenterWillChangeTaskLayout:self isInitialLayout:NO];
    
    taskItem.text = newText;
    
    [self.delegate taskPresenter:self didUpdateTaskItem:taskItem atIndex:taskItemIndex];
    
    [self.delegate taskPresenterDidChangeTaskLayout:self isInitialLayout:NO];
    
    [[self.undoManager prepareWithInvocationTarget:self] updateTaskItem:taskItem withText:oldText];
    
    NSString *undoActionName = NSLocalizedString(@"Text Change", nil);
    [self.undoManager setActionName:undoActionName];
}

- (BOOL)canMoveTaskItem:(TaskItem *)taskItem toIndex:(NSInteger)toIndex {
    if (![self.presentedTaskItems containsObject:taskItem]) {
        return NO;
    }
    
    NSInteger indexOfFirstCompleteItem = self.indexOfFirstCompleteItem;
    
    if (indexOfFirstCompleteItem != NSNotFound) {
        if (taskItem.isComplete) {
            return toIndex >= indexOfFirstCompleteItem && toIndex <= self.count;
        }
        else {
            return toIndex >= 0 && toIndex < indexOfFirstCompleteItem;
        }
    }
    
    return !taskItem.isComplete && toIndex >= 0 && toIndex <= self.count;
}

- (void)moveTaskItem:(TaskItem *)taskItem toIndex:(NSInteger)toIndex {
    NSAssert([self canMoveTaskItem:taskItem toIndex:toIndex], @"An item can only be moved if it passed a \"can move\" test.");
    
    [self.delegate taskPresenterWillChangeTaskLayout:self isInitialLayout:NO];
    
    NSInteger fromIndex = [self unsafeMoveTaskItem:taskItem toIndex:toIndex];
    
    [self.delegate taskPresenterDidChangeTaskLayout:self isInitialLayout:NO];
    
    [[self.undoManager prepareWithInvocationTarget:self] moveTaskItem:taskItem toIndex:fromIndex];
    
    NSString *undoActionName = NSLocalizedString(@"Move", nil);
    [self.undoManager setActionName:undoActionName];
}

- (void)toggleTaskItem:(TaskItem *)taskItem {
    [self.delegate taskPresenterWillChangeTaskLayout:self isInitialLayout:NO];
    
    NSInteger fromIndex = [self unsafeToggleTaskItem:taskItem];
    
    [self.delegate taskPresenterDidChangeTaskLayout:self isInitialLayout:NO];
    
    [[self.undoManager prepareWithInvocationTarget:self] toggleTaskItemForUndo:taskItem toPreviousIndex:fromIndex];
    
    NSString *undoActionName = NSLocalizedString(@"Toggle", nil);
    [self.undoManager setActionName:undoActionName];
}

- (void)updatePresentedTaskItemsToCompletionState:(BOOL)completionState {
    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"isComplete != %@", @(completionState)];
    
    NSArray *presentedTaskItemsNotMatchingCompletionState = [self.presentedTaskItems filteredArrayUsingPredicate:filterPredicate];
    
    if (presentedTaskItemsNotMatchingCompletionState.count == 0) {
        return;
    }
    
    NSString *undoActionName = completionState ? NSLocalizedString(@"Complete All", nil) : NSLocalizedString(@"Incomplete All", nil);
    [self toggleTaskItemsWithoutMoving:presentedTaskItemsNotMatchingCompletionState undoActionName:undoActionName];
}

#pragma mark - Undo Helper Methods

- (void)toggleTaskItemForUndo:(TaskItem *)taskItem toPreviousIndex:(NSInteger)previousIndex {
    NSAssert([self.presentedTaskItems containsObject:taskItem], @"The task item should already be in the task if it's going to be toggled.");
    
    [self.delegate taskPresenterWillChangeTaskLayout:self isInitialLayout:NO];
    
    // Move the task item.
    NSInteger fromIndex = [self unsafeMoveTaskItem:taskItem toIndex:previousIndex];
    
    // Update the task item's state.
    taskItem.complete = !taskItem.isComplete;
    
    [self.delegate taskPresenter:self didUpdateTaskItem:taskItem atIndex:previousIndex];
    
    [self.delegate taskPresenterDidChangeTaskLayout:self isInitialLayout:NO];
    
    [[self.undoManager prepareWithInvocationTarget:self] toggleTaskItemForUndo:taskItem toPreviousIndex:fromIndex];
    
    NSString *undoActionName = NSLocalizedString(@"Toggle", nil);
    [self.undoManager setActionName:undoActionName];
}

- (void)insertTaskItemsForUndo:(NSArray *)taskItemsToInsert atIndexes:(NSArray *)indexes {
    NSAssert(taskItemsToInsert.count == indexes.count, @"`taskItems` must have as many elements as `indexes`.");
    
    [self.delegate taskPresenterWillChangeTaskLayout:self isInitialLayout:NO];
    
    NSMutableArray *taskItems = [self.task mutableArrayValueForKey:@"items"];
    
    [taskItemsToInsert enumerateObjectsUsingBlock:^(TaskItem *taskItemToInsert, NSUInteger idx, BOOL *stop) {

        NSInteger insertionIndex = [indexes[idx] integerValue];
        
        [taskItems insertObject:taskItemToInsert atIndex:insertionIndex];
        
        [self.delegate taskPresenter:self didInsertTaskItem:taskItemToInsert atIndex:insertionIndex];
    }];
    
    [self.delegate taskPresenterDidChangeTaskLayout:self isInitialLayout:NO];
    
    // Undo
    [[self.undoManager prepareWithInvocationTarget:self] removeTaskItems:taskItemsToInsert];
    
    NSString *undoActionName = NSLocalizedString(@"Remove", nil);
    [self.undoManager setActionName:undoActionName];
}

- (void)toggleTaskItemsWithoutMoving:(NSArray *)taskItems undoActionName:(NSString *)undoActionName {
    [self.delegate taskPresenterWillChangeTaskLayout:self isInitialLayout:NO];
    
    for (TaskItem *taskItem in taskItems) {
        taskItem.complete = !taskItem.isComplete;
        
        NSInteger updatedIndex = [self.presentedTaskItems indexOfObject:taskItem];
        
        [self.delegate taskPresenter:self didUpdateTaskItem:taskItem atIndex:updatedIndex];
    }
    
    [self.delegate taskPresenterDidChangeTaskLayout:self isInitialLayout:NO];
    
    [[self.undoManager prepareWithInvocationTarget:self] toggleTaskItemsWithoutMoving:taskItems undoActionName:undoActionName];
    
    [self.undoManager setActionName:undoActionName];
}

#pragma mark - Unsafe Updating Methods

- (void)unsafeInsertTaskItem:(TaskItem *)taskItem {
    NSAssert(![self.presentedTaskItems containsObject:taskItem], @"A task item was requested to be added that is already in the task.");
    
    NSInteger indexToInsertTaskItem = taskItem.isComplete ? self.count : 0;
    
    [[self.task mutableArrayValueForKey:@"items"] insertObject:taskItem atIndex:indexToInsertTaskItem];
    
    [self.delegate taskPresenter:self didInsertTaskItem:taskItem atIndex:indexToInsertTaskItem];
}

- (NSInteger)unsafeMoveTaskItem:(TaskItem *)taskItem toIndex:(NSInteger)toIndex {
    NSInteger fromIndex = [self.presentedTaskItems indexOfObject:taskItem];
    
    NSAssert(fromIndex != NSNotFound, @"A task item can only be moved if it already exists in the presented task items.");
    
    NSMutableArray *taskItems = [self.task mutableArrayValueForKey:@"items"];
    
    [taskItems removeObjectAtIndex:fromIndex];
    [taskItems insertObject:taskItem atIndex:toIndex];
    
    [self.delegate taskPresenter:self didMoveTaskItem:taskItem fromIndex:fromIndex toIndex:toIndex];

    return fromIndex;
}

- (NSInteger)unsafeToggleTaskItem:(TaskItem *)taskItem {
    NSAssert([self.presentedTaskItems containsObject:taskItem], @"A task item can only be toggled if it already exists in the task.");
    
    // Move the task item.
    NSInteger targetIndex = taskItem.isComplete ? 0 : self.count - 1;
    NSInteger fromIndex = [self unsafeMoveTaskItem:taskItem toIndex:targetIndex];
    
    // Update the task item's state.
    taskItem.complete = !taskItem.isComplete;
    [self.delegate taskPresenter:self didUpdateTaskItem:taskItem atIndex:targetIndex];
    
    return fromIndex;
}

#pragma mark - Private Convenience Methods

- (NSInteger)indexOfFirstCompleteItem {
    return [self.presentedTaskItems indexOfObjectPassingTest:^BOOL(TaskItem *taskItem, NSUInteger idx, BOOL *stop) {
        return taskItem.isComplete;
    }];
}

- (NSArray *)reorderedTaskItemsFromTaskItems:(NSArray *)taskItems {
    NSPredicate *incompleteTaskItemsPredicate = [NSPredicate predicateWithFormat:@"isComplete = NO"];
    NSPredicate *completeTaskItemsPredicate = [NSPredicate predicateWithFormat:@"isComplete = YES"];
    
    NSArray *incompleteTaskItems = [taskItems filteredArrayUsingPredicate:incompleteTaskItemsPredicate];
    NSArray *completeTaskItems = [taskItems filteredArrayUsingPredicate:completeTaskItemsPredicate];
    
    return [incompleteTaskItems arrayByAddingObjectsFromArray:completeTaskItems];
}

@end
