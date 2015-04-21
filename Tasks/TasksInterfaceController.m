//
//  TasksInterfaceController.m
//  Tasks
//
//  Created by Henry W Lu on 3/26/15.
//  Copyright (c) 2015 Henry W Lu. All rights reserved.
//

#import "TasksInterfaceController.h"
#import "WatchStoryboardConstants.h"
#import "ColoredTextRowController.h"
@import TasksKit;

@interface TasksInterfaceController () <TasksControllerDelegate>

@property (nonatomic, strong) TasksController *tasksController;

@property (nonatomic, weak) IBOutlet WKInterfaceTable *interfaceTable;

@end


@implementation TasksInterfaceController

- (instancetype)init {
    self = [super init];

    if (self) {
        _tasksController = [[AppConfiguration sharedAppConfiguration] tasksControllerForCurrentConfigurationWithPathExtension:AppConfigurationTasksFileExtension firstQueryHandler:nil];

        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:0];
        [self.interfaceTable insertRowsAtIndexes:indexSet withRowType:TasksInterfaceControllerNoTasksRowType];
        
        if ([AppConfiguration sharedAppConfiguration].isFirstLaunch) {
            NSLog(@"Tasks does not currently support configuring a storage option before the iOS app is launched. Please launch the iOS app first. See the Release Notes section in README.md for more information.");
        }
    }

    return self;
}

#pragma mark - Segues

- (id)contextForSegueWithIdentifier:(NSString *)segueIdentifier inTable:(WKInterfaceTable *)table rowIndex:(NSInteger)rowIndex {
    if ([segueIdentifier isEqualToString:TasksInterfaceControllerTaskSelectionSegue]) {
        TaskInfo *taskInfo = self.tasksController[rowIndex];
        
        return taskInfo;
    }
    
    return nil;
}

#pragma mark - TasksControllerDelegate

- (void)tasksController:(TasksController *)tasksController didInsertTaskInfo:(TaskInfo *)taskInfo atIndex:(NSInteger)index {
    NSInteger numberOfTasks = self.tasksController.count;
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:index];
    
    // The tasks controller was previously empty. Remove the "no tasks" row.
    if (index == 0 && numberOfTasks == 1) {
        [self.interfaceTable removeRowsAtIndexes:indexSet];
    }
    
    [self.interfaceTable insertRowsAtIndexes:indexSet withRowType:TasksInterfaceControllerTaskRowType];
    [self configureRowControllerAtIndex:index];
}

- (void)tasksController:(TasksController *)tasksController didRemoveTaskInfo:(TaskInfo *)taskInfo atIndex:(NSInteger)index {
    NSInteger numberOfTasks = self.tasksController.count;
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:index];
    
    [self.interfaceTable removeRowsAtIndexes:indexSet];
    
    // The tasks controller is now empty. Add the "no tasks" row.
    if (index == 0 && numberOfTasks == 0) {
        [self.interfaceTable insertRowsAtIndexes:indexSet withRowType:TasksInterfaceControllerNoTasksRowType];
    }
}

- (void)tasksController:(TasksController *)tasksController didUpdateTaskInfo:(TaskInfo *)taskInfo atIndex:(NSInteger)index {
    [self configureRowControllerAtIndex:index];
}

#pragma mark - Convenience

- (void)configureRowControllerAtIndex:(NSInteger)index {
    ColoredTextRowController *watchTaskRowController = [self.interfaceTable rowControllerAtIndex:index];
    
    TaskInfo *taskInfo = self.tasksController[index];
    
    [watchTaskRowController setText:taskInfo.name];
    
    [taskInfo fetchInfoWithCompletionHandler:^{
        /*
             The fetchInfoWithCompletionHandler: method calls its completion handler on a background
             queue, dispatch back to the main queue to make UI updates.
        */
        dispatch_async(dispatch_get_main_queue(), ^{
            ColoredTextRowController *watchTaskRowController = [self.interfaceTable rowControllerAtIndex:index];
            
            [watchTaskRowController setColor:ColorFromTaskColor(taskInfo.color)];
        });
    }];
}

#pragma mark - Interface Life Cycle

- (void)willActivate {
    // If the `TasksController` is activating, we should invalidate any pending user activities.
    [self invalidateUserActivity];
    
    self.tasksController.delegate = self;

    [self.tasksController startSearching];
}

- (void)didDeactivate {
    [self.tasksController stopSearching];
    
    self.tasksController.delegate = nil;
}

- (void)handleUserActivity:(NSDictionary *)userInfo {
    // The Tasks watch app only supports continuing activities where `AppConfigurationUserActivityTaskURLPathUserInfoKey` is provided.
    NSString *taskInfoFilePath = userInfo[AppConfigurationUserActivityTaskURLPathUserInfoKey];
    
    // If no `taskInfoFilePath` is found, there is no activity of interest to handle.
    if (!taskInfoFilePath) {
        return;
    }

    NSURL *taskInfoURL = [NSURL fileURLWithPath:taskInfoFilePath isDirectory:NO];
    
    // Create an `TaskInfo` that represents the task at `taskInfoURL`.
    TaskInfo *taskInfo = [[TaskInfo alloc] initWithURL:taskInfoURL];
    
    // Present an `TaskInterfaceController`.
    [self pushControllerWithName:TaskInterfaceControllerName context:taskInfo];
}

@end
