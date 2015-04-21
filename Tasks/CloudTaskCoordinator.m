//
//  CloudTaskCoordinator.m
//  Tasks
//
//  Created by Henry W Lu on 11/26/14.
//  Copyright (c) 2014 Henry W Lu. All rights reserved.
//

#import "CloudTaskCoordinator.h"
#import "TaskUtilities.h"
#import "AppConfiguration.h"

@interface CloudTaskCoordinator ()

@property (nonatomic, strong) NSMetadataQuery *metadataQuery;
@property (nonatomic, strong) dispatch_queue_t documentsDirectoryQueue;
@property (nonatomic, strong) NSURL *documentsDirectory;
@property (nonatomic, strong) void (^firstQueryUpdateHandler)(void);
@end

@implementation CloudTaskCoordinator
@synthesize delegate = _delegate;
@synthesize documentsDirectory = _documentsDirectory;

#pragma mark - Initialization

- (instancetype)initWithPredicate:(NSPredicate *)predicate firstQueryUpdateHandler:(void (^)(void))firstQueryUpdateHandler {
    self = [super init];

    if (self) {
        _firstQueryUpdateHandler = firstQueryUpdateHandler;
        _documentsDirectoryQueue = dispatch_queue_create("com.locust123.tasks.cloudtaskcoordinator.documentsDirectory", DISPATCH_QUEUE_SERIAL);

        _metadataQuery = [[NSMetadataQuery alloc] init];
        _metadataQuery.searchScopes = @[NSMetadataQueryUbiquitousDocumentsScope, NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope];
        
        _metadataQuery.predicate = predicate;
        _metadataQuery.operationQueue = [[NSOperationQueue alloc] init];
        _metadataQuery.operationQueue.name = @"com.locust123.tasks.cloudtaskcoordinator.metadataQuery";

        dispatch_barrier_async(_documentsDirectoryQueue, ^{
            NSURL *cloudContainerURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
            
            _documentsDirectory = [cloudContainerURL URLByAppendingPathComponent:@"Documents"];
        });
        
        // Observe the query.
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        
        [notificationCenter addObserver:self selector:@selector(metadataQueryDidFinishGathering:) name:NSMetadataQueryDidFinishGatheringNotification object:_metadataQuery];
        
        [notificationCenter addObserver:self selector:@selector(metadataQueryDidUpdate:) name:NSMetadataQueryDidUpdateNotification object:_metadataQuery];
    }
    return self;
}

- (instancetype)initWithPathExtension:(NSString *)pathExtension firstQueryUpdateHandler:(void (^)(void))firstQueryUpdateHandler {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(%K.pathExtension = %@)", NSMetadataItemURLKey, pathExtension];
    
    self = [self initWithPredicate:predicate firstQueryUpdateHandler:firstQueryUpdateHandler];
    
    return self;
}

- (instancetype)initWithLastPathComponent:(NSString *)lastPathComponent firstQueryUpdateHandler:(void (^)(void))firstQueryUpdateHandler {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(%K.lastPathComponent = %@)", NSMetadataItemURLKey, lastPathComponent];
    
    self = [self initWithPredicate:predicate firstQueryUpdateHandler:firstQueryUpdateHandler];
    
    return self;
}

#pragma mark - Lifetime

- (void)dealloc {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:NSMetadataQueryDidFinishGatheringNotification object:self.metadataQuery];
    [notificationCenter removeObserver:self name:NSMetadataQueryDidUpdateNotification object:self.metadataQuery];
}

#pragma mark - Property Overrides

- (NSURL *)documentsDirectory {
    __block NSURL *documentsDirectory;

    dispatch_sync(self.documentsDirectoryQueue, ^{
        documentsDirectory = _documentsDirectory;
    });
    
    return documentsDirectory;
}

#pragma mark - TaskCoordinator

- (void)startQuery {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.metadataQuery startQuery];
    });
}

- (void)stopQuery {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.metadataQuery stopQuery];
    });
}

- (void)createURLForTask:(Task *)task withName:(NSString *)name {
    NSURL *documentURL = [self documentURLForName:name];
    
    [TaskUtilities createTask:task atURL:documentURL withCompletionHandler:^(NSError *error) {
        if (error) {
            [self.delegate taskCoordinatorDidFailCreatingTaskAtURL:documentURL withError:error];
        }
        else {
            [self.delegate taskCoordinatorDidUpdateContentsWithInsertedURLs:@[documentURL] removedURLs:@[] updatedURLs:@[]];
        }
    }];
}

- (BOOL)canCreateTaskWithName:(NSString *)name {
    if (name.length <= 0) {
        return NO;
    }
    
    NSURL *documentURL = [self documentURLForName:name];

    return ![[NSFileManager defaultManager] fileExistsAtPath:documentURL.path];
}

- (void)removeTaskAtURL:(NSURL *)URL {
    [TaskUtilities removeTaskAtURL:URL withCompletionHandler:^(NSError *error) {
        if (error) {
            [self.delegate taskCoordinatorDidFailRemovingTaskAtURL:URL withError:error];
        }
        else {
            [self.delegate taskCoordinatorDidUpdateContentsWithInsertedURLs:@[] removedURLs:@[URL] updatedURLs:@[]];
        }
    }];
}

#pragma mark - NSMetadataQuery Notifications

- (void)metadataQueryDidFinishGathering:(NSNotification *)notification {
    [self.metadataQuery disableUpdates];
    
    NSMutableArray *insertedURLs = [NSMutableArray arrayWithCapacity:self.metadataQuery.results.count];
    for (NSMetadataItem *metadataItem in self.metadataQuery.results) {
        NSURL *insertedURL = [metadataItem valueForAttribute:NSMetadataItemURLKey];
        
        [insertedURLs addObject:insertedURL];
    }
    
    [self.delegate taskCoordinatorDidUpdateContentsWithInsertedURLs:insertedURLs removedURLs:@[] updatedURLs:@[]];
    
    [self.metadataQuery enableUpdates];
    
    if (self.firstQueryUpdateHandler) {
        self.firstQueryUpdateHandler();

        self.firstQueryUpdateHandler = nil;
    }
}

- (void)metadataQueryDidUpdate:(NSNotification *)notification {
    [self.metadataQuery disableUpdates];
    
    NSArray *insertedURLs;
    NSArray *removedURLs;
    NSArray *updatedURLs;
    
    NSArray *insertedMetadataItemsOrNil = notification.userInfo[NSMetadataQueryUpdateAddedItemsKey];
    if (insertedMetadataItemsOrNil) {
        insertedURLs = [self URLsByMappingMetadataItems:insertedMetadataItemsOrNil];
    }
    
    NSArray *removedMetadataItemsOrNil = notification.userInfo[NSMetadataQueryUpdateRemovedItemsKey];
    if (removedMetadataItemsOrNil) {
        removedURLs = [self URLsByMappingMetadataItems:removedMetadataItemsOrNil];
    }
    
    NSArray *updatedMetadataItemsOrNil = notification.userInfo[NSMetadataQueryUpdateChangedItemsKey];
    if (updatedMetadataItemsOrNil) {
        NSIndexSet *indexesOfCompletelyDownloadedUpdatedMetadataItems = [updatedMetadataItemsOrNil indexesOfObjectsPassingTest:^BOOL(NSMetadataItem *updatedMetadataItem, NSUInteger idx, BOOL *stop) {
            NSString *downloadStatus = [updatedMetadataItem valueForAttribute:NSMetadataUbiquitousItemDownloadingStatusKey];
            
            return [downloadStatus isEqualToString:NSMetadataUbiquitousItemDownloadingStatusCurrent];
        }];
        
        NSArray *completelyDownloadedUpdatedMetadataItems = [updatedMetadataItemsOrNil objectsAtIndexes:indexesOfCompletelyDownloadedUpdatedMetadataItems];
        
        updatedURLs = [self URLsByMappingMetadataItems:completelyDownloadedUpdatedMetadataItems];
    }
    
    insertedURLs = insertedURLs ?: @[];
    removedURLs = removedURLs ?: @[];
    updatedURLs = updatedURLs ?: @[];
    
    [self.delegate taskCoordinatorDidUpdateContentsWithInsertedURLs:insertedURLs removedURLs:removedURLs updatedURLs:updatedURLs];

    [self.metadataQuery enableUpdates];
}

#pragma mark - Convenience

- (NSURL *)documentURLForName:(NSString *)name {
    NSURL *documentURLWithoutExtension = [self.documentsDirectory URLByAppendingPathComponent:name];
    
    return [documentURLWithoutExtension URLByAppendingPathExtension:AppConfigurationTasksFileExtension];
}

- (NSArray *)URLsByMappingMetadataItems:(NSArray *)metadataItems {
    NSMutableArray *URLs = [NSMutableArray arrayWithCapacity:metadataItems.count];
    
    for (NSMetadataItem *metadataItem in metadataItems) {
        NSURL *URL = [metadataItem valueForAttribute:NSMetadataItemURLKey];
        
        [URLs addObject:URL];
    }
    
    return URLs;
}
@end
