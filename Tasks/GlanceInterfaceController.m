//
//  GlanceInterfaceController.m
//  Tasks
//
//  Created by Henry W Lu on 3/26/15.
//  Copyright (c) 2015 Henry W Lu. All rights reserved.
//

#import "GlanceInterfaceController.h"
#import "WatchStoryboardConstants.h"
#import "GlanceBadge.h"
@import TasksKit;

@interface GlanceInterfaceController () <TasksControllerDelegate, TaskPresenterDelegate>

@property (nonatomic, weak) IBOutlet WKInterfaceImage *glanceBadgeImage;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *glanceBadgeGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *remainingItemsLabel;

@property (nonatomic, strong) TasksController *tasksController;
@property (nonatomic, strong) TaskDocument *taskDocument;
@property (nonatomic, readonly) AllTaskItemsPresenter *taskPresenter;

@property (nonatomic) NSInteger presentedTotalTaskItemCount;
@property (nonatomic) NSInteger presentedCompleteTaskItemCount;

@end


const NSInteger GlanceInterfaceControllerCountUndefined = -1;

@implementation GlanceInterfaceController

#pragma mark - Property Overrides

- (AllTaskItemsPresenter *)taskPresenter {
    return self.taskDocument.taskPresenter;
}

#pragma mark - Initializers

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _presentedTotalTaskItemCount = GlanceInterfaceControllerCountUndefined;
        _presentedCompleteTaskItemCount = GlanceInterfaceControllerCountUndefined;
        
        if ([AppConfiguration sharedAppConfiguration].isFirstLaunch) {
            NSLog(@"Tasks first launch.");
        }
    }
    
    return self;
}

#pragma mark - Setup

- (void)setUpInterface {

    if (self.presentedCompleteTaskItemCount == GlanceInterfaceControllerCountUndefined &&
        self.presentedTotalTaskItemCount == GlanceInterfaceControllerCountUndefined) {
        [self.glanceBadgeGroup setBackgroundImage:nil];
        [self.glanceBadgeImage setImage:nil];
        [self.remainingItemsLabel setHidden:YES];
    }
    
    [self initializeTaskController];
}

- (void)initializeTaskController {
    NSString *localizedTodayTaskName = [AppConfiguration sharedAppConfiguration].localizedTodayDocumentNameAndExtension;

    self.tasksController = [[AppConfiguration sharedAppConfiguration] tasksControllerForCurrentConfigurationWithLastPathComponent:localizedTodayTaskName firstQueryHandler:nil];
    
    self.tasksController.delegate = self;
    
    [self.tasksController startSearching];
}

#pragma mark - TasksControllerDelegate

- (void)tasksController:(TasksController *)tasksController didInsertTaskInfo:(TaskInfo *)taskInfo atIndex:(NSInteger)index {

    [self.tasksController stopSearching];
    
    self.tasksController = nil;
    
    [self processTaskInfoAsTodayDocument:taskInfo];
}

#pragma mark - TaskPresenterDelegate

- (void)taskPresenterDidRefreshCompleteLayout:(id<TaskPresenting>)taskPresenter {

    [self presentGlanceBadge];
}


- (void)taskPresenterWillChangeTaskLayout:(id<TaskPresenting>)taskPresenter isInitialLayout:(BOOL)isInitialLayout {}
- (void)taskPresenter:(id<TaskPresenting>)taskPresenter didInsertTaskItem:(TaskItem *)taskItem atIndex:(NSInteger)index {}
- (void)taskPresenter:(id<TaskPresenting>)taskPresenter didRemoveTaskItem:(TaskItem *)taskItem atIndex:(NSInteger)index {}
- (void)taskPresenter:(id<TaskPresenting>)taskPresenter didUpdateTaskItem:(TaskItem *)taskItem atIndex:(NSInteger)index {}
- (void)taskPresenter:(id<TaskPresenting>)taskPresenter didUpdateTaskColorWithColor:(TaskColor)color {}
- (void)taskPresenter:(id<TaskPresenting>)taskPresenter didMoveTaskItem:(TaskItem *)taskItem fromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex {}

- (void)taskPresenterDidChangeTaskLayout:(id<TaskPresenting>)taskPresenter isInitialLayout:(BOOL)isInitialLayout {

    [self presentGlanceBadge];
}

#pragma mark - Lifecycle

- (void)willActivate {

    [self setUpInterface];
}

- (void)didDeactivate {

    [self.taskDocument closeWithCompletionHandler:^(BOOL success) {
        if (!success) {
            NSLog(@"Couldn't close document: %@.", self.taskDocument.fileURL.absoluteString);
            
            return;
        }
        
        self.taskDocument = nil;
    }];
    
    [self.tasksController stopSearching];
    self.tasksController.delegate = nil;
    self.tasksController = nil;
}

#pragma mark - Convenience

- (void)processTaskInfoAsTodayDocument:(TaskInfo *)taskInfo {
    AllTaskItemsPresenter *taskPresenter = [[AllTaskItemsPresenter alloc] init];

    self.taskDocument = [[TaskDocument alloc] initWithFileURL:taskInfo.URL taskPresenter:taskPresenter];
    
    taskPresenter.delegate = self;
    
    [self.taskDocument openWithCompletionHandler:^(BOOL success) {
        if (!success) {
            NSLog(@"Couldn't open document: %@.", self.taskDocument.fileURL.absoluteString);
            
            return;
        }
        
        NSDictionary *userInfo = @{
            AppConfigurationUserActivityTaskURLPathUserInfoKey: self.taskDocument.fileURL.path,
            AppConfigurationUserActivityTaskColorUserInfoKey: @(self.taskPresenter.color)
        };
        
        [self updateUserActivity:AppConfigurationUserActivityTypeWatch userInfo:userInfo webpageURL:nil];
    }];
}

- (void)presentGlanceBadge {
    NSInteger totalTaskItemCount = self.taskPresenter.count;

    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"isComplete == YES"];
    NSArray *completeTaskItems = [self.taskPresenter.presentedTaskItems filteredArrayUsingPredicate:filterPredicate];
    NSInteger completeTaskItemCount = completeTaskItems.count;


    if (self.presentedTotalTaskItemCount == totalTaskItemCount && self.presentedCompleteTaskItemCount == completeTaskItemCount) {
        return;
    }

    self.presentedTotalTaskItemCount = totalTaskItemCount;
    self.presentedCompleteTaskItemCount = completeTaskItemCount;
    
    GlanceBadge *glanceBadge = [[GlanceBadge alloc] initWithTotalItemCount:totalTaskItemCount completeItemCount:completeTaskItemCount];

    [self.glanceBadgeGroup setBackgroundImage:glanceBadge.groupBackgroundImage];
    [self.glanceBadgeImage setImageNamed:glanceBadge.imageName];
    [self.glanceBadgeImage startAnimatingWithImagesInRange:glanceBadge.imageRange duration:glanceBadge.animationDuration repeatCount:1];

    NSString *itemsRemainingText = [NSString localizedStringWithFormat:NSLocalizedString(@"%d items left", nil), glanceBadge.incompleteItemCount];
    [self.remainingItemsLabel setText:itemsRemainingText];
    [self.remainingItemsLabel setHidden:NO];
}

@end
