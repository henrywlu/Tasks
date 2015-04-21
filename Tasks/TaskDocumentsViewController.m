//
//  TaskDocumentsViewController.m
//  Tasks
//
//  Created by Henry W Lu on 11/26/14.
//  Copyright (c) 2014 Henry W Lu. All rights reserved.
//

@import TasksKit;

#import "TaskDocumentsViewController.h"
#import "AppDelegate.h"
#import "AppLaunchContext.h"
#import "NewTaskDocumentController.h"
#import "TaskViewController.h"
#import "TaskCell.h"
#import "TaskInfo.h"

// Table view cell identifiers.
NSString *const TaskDocumentsViewControllerTaskDocumentCellIdentifier = @"taskDocumentCell";

@interface TaskDocumentsViewController () <TasksControllerDelegate, UIDocumentMenuDelegate, UIDocumentPickerDelegate>

@property (nonatomic, strong) AppLaunchContext *pendingLaunchContext;

@end


@implementation TaskDocumentsViewController
            
#pragma mark - View Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.rowHeight = 44.0;
    
    self.navigationController.navigationBar.titleTextAttributes = @{
        NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline],
        NSForegroundColorAttributeName: ColorFromTaskColor(TaskColorGray)
    };
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleContentSizeCategoryDidChangeNotification:) name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.titleTextAttributes = @{
        NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline],
        NSForegroundColorAttributeName: ColorFromTaskColor(TaskColorGray)
    };
    
    UIColor *grayTaskColor = ColorFromTaskColor(TaskColorGray);
    self.navigationController.navigationBar.tintColor = grayTaskColor;
    self.navigationController.toolbar.tintColor = grayTaskColor;
    self.tableView.tintColor = grayTaskColor;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.pendingLaunchContext) {
        [self configureViewControllerWithLaunchContext:self.pendingLaunchContext];
    }
    
    self.pendingLaunchContext = nil;
}

#pragma mark - Property Overrides

- (void)setTasksController:(TasksController *)tasksController {
    if (tasksController != _tasksController) {
        _tasksController = tasksController;
        _tasksController.delegate = self;
    }
}

#pragma mark - Lifetime

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

#pragma mark - UIResponder

- (void)restoreUserActivityState:(NSUserActivity *)activity {
    // Obtain an app launch context from the provided activity and configure the view controller with it.
    AppLaunchContext *launchContext = [[AppLaunchContext alloc] initWithUserActivity:activity];
    
    // Configure the view controller with the launch context.
    [self configureViewControllerWithLaunchContext:launchContext];
}

#pragma mark - IBActions

/*!
 * Note that the document picker requires that code signing, entitlements, and provisioning for
 * the project have been configured before you run Tasks. If you run the app without configuring
 * entitlements correctly, an exception when this method is invoked (i.e. when the "+" button is
 * clicked).
 */
- (IBAction)pickDocument:(UIBarButtonItem *)barButtonItem {
    UIDocumentMenuViewController *documentMenu = [[UIDocumentMenuViewController alloc] initWithDocumentTypes:@[AppConfigurationTasksFileUTI] inMode:UIDocumentPickerModeImport];
    documentMenu.delegate = self;
    
    NSString *newDocumentTitle = NSLocalizedString(@"New Task", nil);
    [documentMenu addOptionWithTitle:newDocumentTitle image:nil order:UIDocumentMenuOrderFirst handler:^{
        // Show the NewTaskDocumentController.
        [self performSegueWithIdentifier:AppDelegateMainStoryboardTaskDocumentsViewControllerToNewTaskDocumentControllerSegueIdentifier sender:self];
    }];
    
    documentMenu.modalInPopover = UIModalPresentationPopover;
    documentMenu.popoverPresentationController.barButtonItem = barButtonItem;
    
    [self presentViewController:documentMenu animated:YES completion:nil];
}

#pragma mark - UIDocumentMenuDelegate

- (void)documentMenu:(UIDocumentMenuViewController *)documentMenu didPickDocumentPicker:(UIDocumentPickerViewController *)documentPicker {
    documentPicker.delegate = self;
    
    [self presentViewController:documentPicker animated:YES completion:nil];
}

- (void)documentMenuWasCancelled:(UIDocumentMenuViewController *)documentMenu {
    // The user cancelled interacting with the document menu. In your own app, you may want to
    // handle this with other logic.
}

#pragma mark - UIPickerViewDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    // The user selected the document and it should be picked up by the \c TasksController.
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    // The user cancelled interacting with the document picker. In your own app, you may want to
    // handle this with other logic.
}

#pragma mark - TasksControllerDelegate

- (void)tasksControllerWillChangeContent:(TasksController *)tasksController {
    [self.tableView beginUpdates];
}

- (void)tasksController:(TasksController *)tasksController didInsertTaskInfo:(TaskInfo *)taskInfo atIndex:(NSInteger)index {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
    
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)tasksController:(TasksController *)tasksController didRemoveTaskInfo:(TaskInfo *)taskInfo atIndex:(NSInteger)index {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
    
    [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)tasksController:(TasksController *)tasksController didUpdateTaskInfo:(TaskInfo *)taskInfo atIndex:(NSInteger)index {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
    
    TaskCell *cell = (TaskCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    cell.label.text = taskInfo.name;
    
    [taskInfo fetchInfoWithCompletionHandler:^{
        /*
             The fetchInfoWithCompletionHandler: method calls its completion handler on a background
             queue, dispatch back to the main queue to make UI updates.
        */
        dispatch_async(dispatch_get_main_queue(), ^{
            // Make sure that the task info is still visible once the color has been fetched.
            if ([self.tableView.indexPathsForVisibleRows containsObject:indexPath]) {
                cell.taskColorView.backgroundColor = ColorFromTaskColor(taskInfo.color);
            }
        });
    }];
}

- (void)tasksControllerDidChangeContent:(TasksController *)tasksController {
    [self.tableView endUpdates];
}

- (void)tasksController:(TasksController *)tasksController didFailCreatingTaskInfo:(TaskInfo *)taskInfo withError:(NSError *)error {
    NSString *title = NSLocalizedString(@"Failed to Create Task", nil);
    NSString *message = error.localizedDescription;
    NSString *okActionTitle = NSLocalizedString(@"OK", nil);
    
    UIAlertController *errorOutController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    [errorOutController addAction:[UIAlertAction actionWithTitle:okActionTitle style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:errorOutController animated:YES completion:nil];
}

- (void)tasksController:(TasksController *)tasksController didFailRemovingTaskInfo:(TaskInfo *)taskInfo withError:(NSError *)error {
    NSString *title = NSLocalizedString(@"Failed to Delete Task", nil);
    NSString *message = error.localizedDescription;
    NSString *okActionTitle = NSLocalizedString(@"OK", nil);
    
    UIAlertController *errorOutController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    [errorOutController addAction:[UIAlertAction actionWithTitle:okActionTitle style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:errorOutController animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.tasksController ? self.tasksController.count : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [tableView dequeueReusableCellWithIdentifier:TaskDocumentsViewControllerTaskDocumentCellIdentifier forIndexPath:indexPath];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Assert if attempting to configure an unknown or unsupported cell type.
    NSParameterAssert([cell isKindOfClass:[TaskCell class]]);
    
    TaskCell *taskCell = (TaskCell *)cell;
    TaskInfo *taskInfo = self.tasksController[indexPath.row];
    
    taskCell.label.text = taskInfo.name;
    taskCell.label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    taskCell.taskColorView.backgroundColor = [UIColor clearColor];
    
    // Once the task info has been loaded, update the associated cell's properties.
    [taskInfo fetchInfoWithCompletionHandler:^{
        /*
             The fetchInfoWithCompletionHandler: method calls its completion handler on a background
             queue, dispatch back to the main queue to make UI updates.
        */
        dispatch_async(dispatch_get_main_queue(), ^{
            // Make sure that the task info is still visible once the color has been fetched.
            if ([self.tableView.indexPathsForVisibleRows containsObject:indexPath]) {
                taskCell.taskColorView.backgroundColor = ColorFromTaskColor(taskInfo.color);
            }
        });
    }];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

#pragma mark - UIStoryboardSegue Handling

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:AppDelegateMainStoryboardTaskDocumentsViewControllerToNewTaskDocumentControllerSegueIdentifier]) {
        NewTaskDocumentController *newTaskController = segue.destinationViewController;

        newTaskController.tasksController = self.tasksController;
    }
    else if ([segue.identifier isEqualToString:AppDelegateMainStoryboardTaskDocumentsViewControllerToTaskViewControllerSegueIdentifier] ||
             [segue.identifier isEqualToString:AppDelegateMainStoryboardTaskDocumentsViewControllerContinueUserActivity]) {
        UINavigationController *taskNavigationController = (UINavigationController *)segue.destinationViewController;
        TaskViewController *taskViewController = (TaskViewController *)taskNavigationController.topViewController;
        taskViewController.tasksController = self.tasksController;
        
        taskViewController.navigationItem.leftBarButtonItem = [self.splitViewController displayModeButtonItem];
        taskViewController.navigationItem.leftItemsSupplementBackButton = YES;
        
        if ([segue.identifier isEqualToString:AppDelegateMainStoryboardTaskDocumentsViewControllerToTaskViewControllerSegueIdentifier]) {
            NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
            [taskViewController configureWithTaskInfo:self.tasksController[indexPath.row]];
        }
        else if ([segue.identifier isEqualToString:AppDelegateMainStoryboardTaskDocumentsViewControllerContinueUserActivity]) {
            TaskInfo *userActivityTaskInfo = sender;
            [taskViewController configureWithTaskInfo:userActivityTaskInfo];
        }
    }
}

#pragma mark - Notifications

- (void)handleContentSizeCategoryDidChangeNotification:(NSNotification *)notification {
    [self.view setNeedsLayout];
}


#pragma mark - Convenience

- (void)configureViewControllerWithLaunchContext:(AppLaunchContext *)launchContext {
    /**
        If there is a task currently displayed; pop to the root view controller (this controller) and
        continue configuration from there. Otherwise, configure the view controller directly.
    */
    if ([self.navigationController.topViewController isKindOfClass:[UINavigationController class]]) {
        [self.navigationController popToRootViewControllerAnimated:NO];
        self.pendingLaunchContext = launchContext;
        
        return;
    }
    
    TaskInfo *activityTaskInfo = [[TaskInfo alloc] initWithURL:launchContext.taskURL];
    activityTaskInfo.color = launchContext.taskColor;
    
    [self performSegueWithIdentifier:AppDelegateMainStoryboardTaskDocumentsViewControllerContinueUserActivity sender:activityTaskInfo];
}

@end
