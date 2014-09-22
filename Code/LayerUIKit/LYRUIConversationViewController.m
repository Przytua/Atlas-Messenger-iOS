//
//  LYRUIConversationViewController.m
//  LayerSample
//
//  Created by Kevin Coleman on 8/31/14.
//  Copyright (c) 2014 Layer, Inc. All rights reserved.
//

#import "LYRUIConversationViewController.h"
#import "LYRUIConversationCollectionViewFlowLayout.h"

#import "LYRUIOutgoingMessageCollectionViewCell.h"
#import "LYRUIIncomingMessageCollectionViewCell.h"

#import "LYRUIConversationCollectionViewHeader.h"
#import "LYRUIConversationCollectionViewFooter.h"

#import "LYRUIConstants.h"
#import "LYRUIUtilities.h"

#import "LYRUIChangeNotificationObserver.h"

#import "LYRUIMessageBubbleView.h"

#import "LYRUIMessageInputToolbar.h"

#import "LYRUIDataSourceChange.h"
#import "LYRUIMessageNotificationObserver.h"

#import "LYRUIParticipantTableViewController.h"
#import "LYRUIParticipantTableViewCell.h"

@interface LYRUIConversationViewController () <UICollectionViewDataSource, UICollectionViewDelegate, LYRUIMessageInputToolbarDelegate, UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, LYRUIChangeNotificationObserverDelegate, LYRUIParticipantTableViewControllerDelegate>


@property (nonatomic, strong) LYRClient *layerClient;
@property (nonatomic, strong) LYRConversation *conversation;
@property (nonatomic, strong) NSOrderedSet *messages;

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) LYRUIMessageInputToolbar *messageInputToolbar;

@property (nonatomic, strong) LYRUIMessageNotificationObserver *messageNotificationObserver;
@property (nonatomic, strong) dispatch_queue_t messageSendQueue;

@property (nonatomic) BOOL keyboardIsOnScreen;
@property (nonatomic) CGFloat keyboardHeight;

@property (nonatomic, strong) LYRUIParticipantTableViewController *participantTableViewController;

@end

@implementation LYRUIConversationViewController {
    UIView *inputAccessoryView;
}

static NSString *const LYRUIIncomingMessageCellIdentifier = @"incomingMessageCellIdentifier";
static NSString *const LYRUIOutgoingMessageCellIdentifier = @"outgoingMessageCellIdentifier";

static NSString *const LYRUIMessageCellHeaderIdentifier = @"messageCellHeaderIdentifier";
static NSString *const LYRUIMessageCellFooterIdentifier = @"messageCellFooterIdentifier";

static CGFloat const LYRUIMessageInputToolbarHeight = 40;

- (id)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Failed to call designated initializer." userInfo:nil];
}

+ (instancetype)conversationViewControllerWithConversation:(LYRConversation *)conversation layerClient:(LYRClient *)layerClient;
{
    return [[self alloc] initWithConversation:conversation layerClient:layerClient];
}

- (id)initWithConversation:(LYRConversation *)conversation layerClient:(LYRClient *)layerClient
{
    self = [super init];
    if (self) {
        
        NSAssert(layerClient, @"`Layer Client` cannot be nil");
        NSAssert(conversation, @"`Conversation` cannont be nil");
        
        self.title = @"Conversation";
        self.accessibilityLabel = @"Conversation";
        
        self.conversation = conversation;
        self.layerClient = layerClient;
        
        self.messageSendQueue = dispatch_queue_create("com.layer.messageSend", NULL);
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self fetchMessages];
    
    // Setup Collection View
    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:[[UICollectionViewFlowLayout alloc] init]];
    self.collectionView.contentInset = self.collectionView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, LYRUIMessageInputToolbarHeight, 0);
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.backgroundColor = [UIColor whiteColor];
    self.collectionView.alwaysBounceVertical = TRUE;
    self.collectionView.bounces = TRUE;
    self.collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.collectionView.accessibilityLabel = @"Conversation Collection View";
    [self.view addSubview:self.collectionView];
    
    // Register reusable collection view cells, header and footer
    [self.collectionView registerClass:[LYRUIIncomingMessageCollectionViewCell class] forCellWithReuseIdentifier:LYRUIIncomingMessageCellIdentifier];
    [self.collectionView registerClass:[LYRUIOutgoingMessageCollectionViewCell class] forCellWithReuseIdentifier:LYRUIOutgoingMessageCellIdentifier];
    [self.collectionView registerClass:[LYRUIConversationCollectionViewHeader class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:LYRUIMessageCellHeaderIdentifier];
    [self.collectionView registerClass:[LYRUIConversationCollectionViewFooter class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:LYRUIMessageCellFooterIdentifier];

    [self addContactsButton];
    
    // Setup Layer Change notification observer
    self.messageNotificationObserver = [[LYRUIMessageNotificationObserver alloc] initWithClient:self.layerClient conversation:self.conversation];
    self.messageNotificationObserver.delegate = self;

    // Configure defualt cell appearance
    [self configureMessageBubbleAppearance];
}

- (UIView *)inputAccessoryView
{
    if (!inputAccessoryView) {
        self.messageInputToolbar = [[LYRUIMessageInputToolbar alloc] init];
        self.messageInputToolbar.delegate = self;
    }
    CGSize size = [self.messageInputToolbar systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    self.messageInputToolbar.frame = CGRectMake(0, 0, size.width, size.height);
    inputAccessoryView = self.messageInputToolbar;
    return inputAccessoryView;
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self scrollToBottomOfCollectionViewAnimated:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    // Register for keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
    self.keyboardIsOnScreen = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    self.messageNotificationObserver = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
}

- (void)dealloc
{
    self.collectionView.delegate = nil;
}

#pragma mark - Refresh Data Source

- (void)fetchMessages
{
    self.messages = [self.layerClient messagesForConversation:self.conversation];
}

# pragma mark - Collection View Data Source

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    // MessageParts correspond to rows in a section
    return [[[self.messages objectAtIndex:section] parts] count];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    // Messages correspond to sections
    return self.messages.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    LYRMessage *message = [self.messages objectAtIndex:indexPath.section];
    LYRMessagePart *messagePart = [message.parts objectAtIndex:indexPath.row];
    
    LYRUIMessageCollectionViewCell <LYRUIMessagePresenting> *cell;
    if ([self.layerClient.authenticatedUserID isEqualToString:message.sentByUserID]) {
       
        // If the message was sent by the currently authenticated user, it is outgoing
        cell =  [self.collectionView dequeueReusableCellWithReuseIdentifier:LYRUIOutgoingMessageCellIdentifier forIndexPath:indexPath];
    } else {
        
        // If the message was sent by someone other than the currently authenticated user, it is incoming
        cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:LYRUIIncomingMessageCellIdentifier forIndexPath:indexPath];
    }
    [cell presentMessage:messagePart fromParticipant:nil];
    
    // Sets the width of the bubble view
    [cell updateBubbleViewWidth:[self sizeForItemAtIndexPath:indexPath].width];
    [self updateRecipientStatusForMessage:message];
    return cell;
}

#pragma mark
#pragma mark Collection View Delegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    //Nothing to do for now
}

#pragma mark – UICollectionViewDelegateFlowLayout Methods

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGRect rect = [[UIScreen mainScreen] bounds];
    CGSize size = [self sizeForItemAtIndexPath:indexPath];
    return CGSizeMake(rect.size.width, size.height);
}

- (UIEdgeInsets)collectionView: (UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsZero;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    LYRMessage *message = [self.messages objectAtIndex:indexPath.section];
    if (kind == UICollectionElementKindSectionHeader ) {
        LYRUIConversationCollectionViewHeader *header = [self.collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:LYRUIMessageCellHeaderIdentifier forIndexPath:indexPath];
        if ([self shouldDisplaySenderLabelForSection:indexPath.section]) {
            id<LYRUIParticipant>participant = [self.dataSource conversationViewController:self participantForIdentifier:message.sentByUserID];
            [header updateWithAttributedStringForParticipantName:participant.fullName];
        }
        
        if ([self shouldDisplayDateLabelForSection:indexPath.section]) {
            [header updateWithAttributedStringForDate:[self.dataSource conversationViewController:self attributedStringForDisplayOfDate:message.sentAt]];
        }
        return header;
    } else {
        LYRUIConversationCollectionViewFooter *footer = [self.collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:LYRUIMessageCellFooterIdentifier forIndexPath:indexPath];
        if ([self shouldDisplayReadReceiptForSection:indexPath.section]) {
            [footer updateWithAttributedStringForRecipientStatus:[self.dataSource conversationViewController:self attributedStringForDisplayOfRecipientStatus:message.recipientStatusByUserID]];
        }
        return footer;
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
    if ([self shouldDisplayReadReceiptForSection:section]) {
        return CGSizeMake(320, 20);
    }
    return CGSizeMake(320, 4);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    CGFloat height = 0;
    
    LYRMessage *message = [self.messages objectAtIndex:section];
    if (section > 0) {
        LYRMessage *previousMessage = [self.messages objectAtIndex:section - 1];
        if (![message.sentByUserID isEqualToString:previousMessage.sentByUserID]) {
            height += 10;
        }
    }
    
    if ([self shouldDisplayDateLabelForSection:section]) {
        height += 30;
    }
    
    if ([self shouldDisplaySenderLabelForSection:section]) {
        height += 30;
    }
    return CGSizeMake([[UIScreen mainScreen] bounds].size.width, height);
}

#pragma mark - Recipient Status Methods

- (void)updateRecipientStatusForMessage:(LYRMessage *)message
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSNumber *recipientStatus = [message.recipientStatusByUserID objectForKey:self.layerClient.authenticatedUserID];
        if (![recipientStatus isEqualToNumber:[NSNumber numberWithInteger:LYRRecipientStatusRead]] ) {
                NSError *error;
                BOOL success = [self.layerClient markMessageAsRead:message error:&error];
                if (success) {
                    NSLog(@"Message successfully marked as read");
                } else {
                    NSLog(@"Failed to mark message as read with error %@", error);
                }
        }
    });
}

#pragma mark - UI Configuration Methods

- (BOOL)shouldDisplayDateLabelForSection:(NSUInteger)section
{
    // If it is the first section, show date label
    if (section == 0) return YES;
    
    LYRMessage *previousMessage;
    LYRMessage *message = [self.messages objectAtIndex:section];
    if (section > 0) {
        previousMessage = [self.messages objectAtIndex:section - 1];
    }
    double interval = [message.receivedAt timeIntervalSinceDate:previousMessage.receivedAt];
    
    // If it has been 60min since last message, show date label
    if (interval > (60 * 60)) {
        return YES;
    }
    
    // Otherwise, don't show date label
    return NO;
}

- (BOOL)shouldDisplaySenderLabelForSection:(NSUInteger)section
{
    LYRMessage *message = [self.messages objectAtIndex:section];
    if ([message.sentByUserID isEqualToString:self.layerClient.authenticatedUserID]) {
        return NO;
    }
    
    if (!self.conversation.participants.count > 2) {
        return NO;
    }
    
    if (section > 0) {
        LYRMessage *previousMessage = [self.messages objectAtIndex:section - 1];
        if ([previousMessage.sentByUserID isEqualToString:message.sentByUserID]) {
            return NO;
        }
    }

    return YES;
}

- (BOOL)shouldDisplayReadReceiptForSection:(NSUInteger)section
{
    LYRMessage *message = [self.messages objectAtIndex:section];
    if (section == self.messages.count - 1 && message.sentByUserID == self.layerClient.authenticatedUserID) {
        return YES;
    }
    return NO;
}

- (CGSize)sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    LYRMessage *message = [self.messages objectAtIndex:indexPath.section];
    LYRMessagePart *part = [message.parts objectAtIndex:indexPath.row];
    
    CGSize size;
    if ([part.MIMEType isEqualToString:LYRUIMIMETypeTextPlain]) {
        NSString *text = [[NSString alloc] initWithData:part.data encoding:NSUTF8StringEncoding];
        size = LYRUITextPlainSize(text, [[LYRUIOutgoingMessageCollectionViewCell appearance] messageTextFont]);
        size.height = size.height + 16; // Adding 16 to account for default vertical padding for text in bubble view
    } else if ([part.MIMEType isEqualToString:LYRUIMIMETypeImageJPEG] || [part.MIMEType isEqualToString:LYRUIMIMETypeImagePNG]) {
        UIImage *image = [UIImage imageWithData:part.data];
        size = LYRUIImageSize(image);
    }
    return size;
}

#pragma mark
#pragma mark Keyboard Nofifications

- (void)keyboardWasShown:(NSNotification*)notification
{
    self.keyboardIsOnScreen = TRUE;
    NSDictionary* info = [notification userInfo];
    self.keyboardHeight = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
    [UIView setAnimationCurve:[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue]];
    [UIView setAnimationBeginsFromCurrentState:YES];
    
    [self updateInsets];
    
    [UIView commitAnimations];
    
    [self scrollToBottomOfCollectionViewAnimated:TRUE];
    
    self.keyboardIsOnScreen = TRUE;
}

- (void)keyboardWillBeHidden:(NSNotification*)notification
{
    self.keyboardHeight = 0;
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
    [UIView setAnimationCurve:[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue]];
    [UIView setAnimationBeginsFromCurrentState:YES];
    
    [self updateInsets];
    
    [UIView commitAnimations];
    
    self.keyboardIsOnScreen = FALSE;
}

#pragma mark LYRUIComposeView Delegate Methods

- (void)messageInputToolbar:(LYRUIMessageInputToolbar *)messageInputToolbar didTapRightAccessoryButton:(UIButton *)rightAccessoryButton
{
    if (messageInputToolbar.messageContentParts) {
        [self sendMessageWithContentParts:messageInputToolbar.messageContentParts];
    }
    if (messageInputToolbar.textInputView.text.length > 1) {
        [self sendMessageWithText:messageInputToolbar.textInputView.text];
    }
}

- (void)messageInputToolbar:(LYRUIMessageInputToolbar *)messageInputToolbar didTapLeftAccessoryButton:(UIButton *)leftAccessoryButton
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle:nil
                                  delegate:self
                                  cancelButtonTitle:@"Cancel"
                                  destructiveButtonTitle:nil
                                  otherButtonTitles:@"Select Photo", @"Take Photo", nil];
    [actionSheet showInView:self.view];
}

#pragma mark Message Sent Methods

- (void)sendMessageWithContentParts:(NSMutableArray *)messageContentParts
{
    for (id object in messageContentParts){
        
        if ([object isKindOfClass:[UIImage class]]) {
            [self sendMessageWithImage:object];
        }
        
        if ([object isKindOfClass:[CLLocation class]]) {
            [self sendMessageWithLocation:object];
        }
    }
}

- (void)sendMessageWithText:(NSString *)text
{
    LYRMessagePart *part = [LYRMessagePart messagePartWithText:text];
    LYRMessage *message = [LYRMessage messageWithConversation:self.conversation parts:@[ part ]];
    [self sendMessage:message pushText:text];
}

- (void)sendMessageWithImage:(UIImage *)image
{
    UIImage *adjustedImage = LYRUIAdjustOrientationForImage(image);
    NSData *compressedImageData =  LYRUIJPEGDataForImageWithConstraint(adjustedImage, 300);
    
    LYRMessagePart *part = [LYRMessagePart messagePartWithMIMEType:LYRUIMIMETypeImageJPEG data:compressedImageData];
    LYRMessage *message = [LYRMessage messageWithConversation:self.conversation parts:@[ part ]];
    [self sendMessage:message pushText:@"New Image"];
}

- (void)sendMessageWithLocation:(CLLocation *)location
{
    NSNumber *lat = [NSNumber numberWithDouble:location.coordinate.latitude];
    NSNumber *lon = [NSNumber numberWithDouble:location.coordinate.longitude];
    NSDictionary *locationDictionary = @{@"lat" : lat,
                                         @"lon" : lon};
    
    LYRMessagePart *part = [LYRMessagePart messagePartWithMIMEType:LYRUIMIMETypeLocation data:[NSKeyedArchiver archivedDataWithRootObject:locationDictionary]];
    LYRMessage *message = [LYRMessage messageWithConversation:self.conversation parts:@[ part ]];
  
    [self sendMessage:message pushText:@"New Location"];
}

- (void)sendMessage:(LYRMessage *)message pushText:(NSString *)pushText
{
    dispatch_async(self.messageSendQueue,^{
        id<LYRUIParticipant>sender = [self.dataSource conversationViewController:self participantForIdentifier:self.layerClient.authenticatedUserID];
        NSString *text = [NSString stringWithFormat:@"%@: %@", [sender fullName], pushText];
        [self.layerClient setMetadata:@{LYRMessagePushNotificationAlertMessageKey: text} onObject:message];
        
        NSError *error;
        BOOL success = [self.layerClient sendMessage:message error:&error];
        if (success) {
            NSLog(@"Messages Succesfully Sent");
        } else {
            NSLog(@"The error is %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Messaging Error"
                                                                    message:[error localizedDescription]
                                                                   delegate:nil
                                                          cancelButtonTitle:@"OK"
                                                          otherButtonTitles:nil];
                [alertView show];
            });
        }
    });
}

#pragma mark UIActionSheetDelegate Methods

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex) {
        case 0:
            [self displayImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
            break;
        case 1:
            [self displayImagePickerWithSourceType:UIImagePickerControllerSourceTypeCamera];
            break;
        default:
            break;
    }
}

#pragma mark UIImagePicker Methods

- (void)displayImagePickerWithSourceType:(UIImagePickerControllerSourceType)sourceType;
{
    BOOL pickerSourceTypeAvailable = [UIImagePickerController isSourceTypeAvailable:sourceType];
    
    if (pickerSourceTypeAvailable) {
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.sourceType = sourceType;
        [self.navigationController presentViewController:picker animated:YES completion:nil];
        NSLog(@"Camera is available");
    }
}

#pragma mark UIImagePickerController Delegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    NSString *mediaType = [info objectForKey:@"UIImagePickerControllerMediaType"];
    if ([mediaType isEqualToString:@"public.image"]) {
        
        // Get the selected image
        UIImage *selectedImage = (UIImage *)[info objectForKey:UIImagePickerControllerOriginalImage];
        
        [self.messageInputToolbar insertImage:selectedImage];
    }
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark Notification Observer Delegate Methods

- (void) observerWillChangeContent:(LYRUIChangeNotificationObserver *)observer
{
    //nothing to do for now
}

- (void)observer:(LYRUIChangeNotificationObserver *)observer updateWithChanges:(NSArray *)changes
{   
    [self fetchMessages];
    [self.collectionView reloadData];

        for (LYRUIDataSourceChange *change in changes) {
            switch (change.type) {
                case LYRUIDataSourceChangeTypeInsert:
                    [self scrollToBottomOfCollectionViewAnimated:YES];
                    break;
                default:
                    break;
            }
        }
//    [self.collectionView performBatchUpdates:^{
//        for (LYRUIDataSourceChange *change in changes) {
//            switch (change.type) {
//                case LYRUIDataSourceChangeTypeInsert:
//                    [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:change.newIndex]];
//                    break;
//                case LYRUIDataSourceChangeTypeMove:
////                    [self.collectionView deleteSections:[NSIndexSet indexSetWithIndex:change.oldIndex]];
////                    [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:change.newIndex]];
//                    break;
//                case LYRUIDataSourceChangeTypeUpdate:
//                    [self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:change.newIndex]];
//                    break;
//                case LYRUIDataSourceChangeTypeDelete:
//                    [self.collectionView deleteSections:[NSIndexSet indexSetWithIndex:change.newIndex]];
//                    break;
//                default:
//                    break;
//            }
//        }
//    } completion:^(BOOL finished) {
//        [self scrollToBottomOfCollectionViewAnimated:TRUE];
//    }];
}

- (void)observerDidChangeContent:(LYRUIChangeNotificationObserver *)observer
{
    //
}

#pragma mark CollectionView Content Inset Methods

- (void)updateInsets
{
    UIEdgeInsets existing = self.collectionView.contentInset;
    self.collectionView.contentInset = self.collectionView.scrollIndicatorInsets = UIEdgeInsetsMake(existing.top, 0, self.keyboardHeight, 0);
}

- (CGPoint)bottomOffset
{
    return CGPointMake(0, MAX(-self.collectionView.contentInset.top, self.collectionView.collectionViewLayout.collectionViewContentSize.height - (self.collectionView.frame.size.height - self.collectionView.contentInset.bottom)));
    
}

- (void)scrollToBottomOfCollectionViewAnimated:(BOOL)animated
{
    if (self.messages.count > 1) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.collectionView setContentOffset:[self bottomOffset] animated:animated];
        });
    }
}

- (void)contactsButtonTapped
{
    [self addDoneButton];
    NSMutableSet *participants = [NSMutableSet new];
    for (NSString *identifier in self.conversation.participants) {
        [participants addObject:[self.dataSource conversationViewController:self participantForIdentifier:identifier]];
    }
    
    self.participantTableViewController = [LYRUIParticipantTableViewController participantTableViewControllerWithParticipants:participants sortType:LYRUIParticipantPickerControllerSortTypeFirst];
    self.participantTableViewController.delegate = self;
    self.participantTableViewController.view.frame = CGRectMake(0, 49, 320, 300);
    self.participantTableViewController.participantCellClass = [LYRUIParticipantTableViewCell class];
    
    [self.view addSubview:self.participantTableViewController.view];
    [self addChildViewController:self.participantTableViewController];
    [self.participantTableViewController didMoveToParentViewController:self];
    
//    [UIView animateWithDuration:0.5 animations:^{
//        self.participantTableViewController.view.frame = CGRectMake(0, 49, 320, 300);
//    }];
}

- (void)addContactsButton
{
    // Left bar button item is the text Cancel
    UIBarButtonItem *contactsButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Contacts"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(contactsButtonTapped)];
    contactsButtonItem.accessibilityLabel = @"Contacts";
    self.navigationItem.rightBarButtonItem = contactsButtonItem;
}

- (void)addDoneButton
{
    // Left bar button item is the text Cancel
    UIBarButtonItem *doneButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(doneButtonTapped)];
    doneButtonItem.accessibilityLabel = @"Done";
    self.navigationItem.rightBarButtonItem = doneButtonItem;
}

- (void)doneButtonTapped
{
    [UIView animateWithDuration:0.5 animations:^{
        self.participantTableViewController.view.frame = CGRectMake(0, 0, 320, 0);
    }completion:^(BOOL finished) {
        [self.participantTableViewController.view removeFromSuperview];
        [self.participantTableViewController removeFromParentViewController];
        [self addContactsButton];
    }];
}

- (void)participantTableViewController:(LYRUIParticipantTableViewController *)participantTableViewController didSelectParticipant:(id<LYRUIParticipant>)participant
{
    //
}

#pragma mark Default Message Cell Appearance

- (void)configureMessageBubbleAppearance
{
    [[LYRUIOutgoingMessageCollectionViewCell appearance] setMessageTextColor:[UIColor whiteColor]];
    [[LYRUIOutgoingMessageCollectionViewCell appearance] setMessageTextFont:LSMediumFont(14)];
    
    [[LYRUIIncomingMessageCollectionViewCell appearance] setMessageTextColor:[UIColor blackColor]];
    [[LYRUIIncomingMessageCollectionViewCell appearance] setMessageTextFont:LSMediumFont(14)];
}

@end
