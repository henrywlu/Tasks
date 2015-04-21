//
//  TaskDocumentsViewController.h
//  Tasks
//
//  Created by Henry W Lu on 11/26/14.
//  Copyright (c) 2014 Henry W Lu. All rights reserved.
//

@import UIKit;
@import TasksKit;

@class AppLaunchContext;

@interface TaskDocumentsViewController : UITableViewController

@property (nonatomic, strong) TasksController *tasksController;

- (void)configureViewControllerWithLaunchContext:(AppLaunchContext *)launchContext;

@end
