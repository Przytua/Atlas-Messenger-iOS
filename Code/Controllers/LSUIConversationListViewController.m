//
//  LSConversationListViewController.m
//  LayerSample
//
//  Created by Kevin Coleman on 8/29/14.
//  Copyright (c) 2014 Layer, Inc. All rights reserved.
//

#import "LSUIConversationListViewController.h"
#import "SVProgressHUD.h"
#import "LSUser.h"
#import "LSUIConversationViewController.h"
#import "LSSettingsTableViewController.h"

@interface LSUIConversationListViewController () < LYRUIConversationListViewControllerDelegate, LYRUIConversationListViewControllerDataSource, LSSettingsTableViewControllerDelegate, UIActionSheetDelegate>


@end

@implementation LSUIConversationListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.delegate = self;
    self.dataSource = self;
    
    // Left navigation item
    if (self.shouldDisplaySettingsItem && !self.allowsEditing) {
        UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithTitle:@"Settings"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(settingsButtonTapped)];
        settingsButton.accessibilityLabel = @"Settings Button";
        [self.navigationItem setLeftBarButtonItem:settingsButton];
    }

    // Right navigation item
    UIBarButtonItem *composeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
                                                                                   target:self
                                                                                   action:@selector(composeButtonTapped)];
    composeButton.accessibilityLabel = @"Compose Button";
    [self.navigationItem setRightBarButtonItem:composeButton];
}

#pragma mark Conversation List View Controller Delegate Methods

/**
 
 LAYER UI KIT - Allows your application to react to a conversation selection. This application pushses a subclass of 
 the `LYRUIConversationViewController` component.
 
 */
- (void)conversationListViewController:(LYRUIConversationListViewController *)conversationListViewController didSelectConversation:(LYRConversation *)conversation
{
    [self presentControllerWithConversation:conversation];
}

/**
 
 LAYER UI KIT - Allows your application react to a conversations deletion if necessary. This application does not 
 need to react because the superclass component will handle removing the conversation in response to a deletion.
 
 */
- (void)conversationListViewController:(LYRUIConversationListViewController *)conversationListViewController didDeleteConversation:(LYRConversation *)conversation deletionMode:(LYRDeletionMode)deletionMode
{
    NSLog(@"Conversation Successsfully Deleted");
}

/**
 
 LAYER UI KIT - Allows your application react to a failed conversation deletion if necessary.
 
 */
- (void)conversationListViewController:(LYRUIConversationListViewController *)conversationListViewController didFailDeletingConversation:(LYRConversation *)conversation deletionMode:(LYRDeletionMode)deletionMode error:(NSError *)error
{
    NSLog(@"Conversation Deletion Failed with Error: %@", error);
}

#pragma mark Conversation List View Controller Data Source Methods

/**
 
 LAYER UI KIT - Returns a label that is used to represent the conversation. This application puts the 
 name representing the `lastMessage.sentByUserID` property first in the string.
 
 */
- (NSString *)conversationListViewController:(LYRUIConversationListViewController *)conversationListViewController labelForConversation:(LYRConversation *)conversation
{
    if (!self.layerClient.authenticatedUserID) return @"Not auth'd";
    NSMutableSet *participantIdentifiers = [conversation.participants mutableCopy];
    [participantIdentifiers minusSet:[NSSet setWithObject:self.layerClient.authenticatedUserID]];
    
    if (!participantIdentifiers.count > 0) return @"Personal Conversation";
    
    NSMutableSet *participants = [[self.applicationController.persistenceManager participantsForIdentifiers:participantIdentifiers] mutableCopy];
    if (!participants.count > 0) return @"No Matching Participants";
    
    // Put the latest message sender's name first
    LSUser *firstUser;
    if (![conversation.lastMessage.sentByUserID isEqualToString:self.layerClient.authenticatedUserID]){
        if (conversation.lastMessage) {
            NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"SELF.userID IN %@", conversation.lastMessage.sentByUserID];
            LSUser *lastMessageSender = [[[participants filteredSetUsingPredicate:searchPredicate] allObjects] lastObject];
            if (lastMessageSender) {
                firstUser = lastMessageSender;
                [participants removeObject:lastMessageSender];
            }
        }
    } else {
        firstUser = [[participants allObjects] objectAtIndex:0];
    }
    
    NSString *conversationLabel = firstUser.fullName;
    for (int i = 1; i < [[participants allObjects] count]; i++) {
        LSUser *user = [[participants allObjects] objectAtIndex:i];
        conversationLabel = [NSString stringWithFormat:@"%@, %@", conversationLabel, user.fullName];
    }
    return conversationLabel;
}

/**
 
 LAYER UI KIT - If needed, your application can display an avatar image that represnts a conversation. If no image 
 is returned, no image will be displayed.
 
 */
- (UIImage *)conversationListViewController:(LYRUIConversationListViewController *)conversationListViewController imageForConversation:(LYRConversation *)conversation
{
    return nil;
}

#pragma mark Selected Conversation Methods

- (void)presentControllerWithConversation:(LYRConversation *)conversation
{
    LSUIConversationViewController *viewController = [LSUIConversationViewController conversationViewControllerWithConversation:conversation
                                                                                                                    layerClient:self.applicationController.layerClient];
    viewController.applicationContoller = self.applicationController;
    viewController.showsAddressBar = YES;
    [self.navigationController pushViewController:viewController animated:YES];
}

#pragma mark - Bar Button Functionality Methods

- (void)settingsButtonTapped
{
    LSSettingsTableViewController *settingsTableViewController = [[LSSettingsTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    settingsTableViewController.applicationController = self.applicationController;
    settingsTableViewController.settingsDelegate = self;
    
    UINavigationController *controller = [[UINavigationController alloc] initWithRootViewController:settingsTableViewController];
    [self.navigationController presentViewController:controller animated:YES completion:nil];
}

- (void)composeButtonTapped
{
    [self presentControllerWithConversation:nil];
}

#pragma mark - Push Notification Selection Method

- (void)selectConversation:(LYRConversation *)conversation
{
    [self.navigationController popToRootViewControllerAnimated:TRUE];
    if (conversation) {
        [self presentControllerWithConversation:conversation];
    }
}

#pragma mark - Settings View Controller Delegate

- (void)logoutTappedInSettingsTableViewController:(LSSettingsTableViewController *)settingsTableViewController
{
    [SVProgressHUD show];
    if (self.applicationController.layerClient.isConnected) {
        [self.applicationController.layerClient deauthenticateWithCompletion:^(BOOL success, NSError *error) {
            [self.applicationController.APIManager deauthenticate];
            [SVProgressHUD dismiss];
        }];
    } else {
        [self.applicationController.APIManager deauthenticate];
        [SVProgressHUD dismiss];
    }
}

@end