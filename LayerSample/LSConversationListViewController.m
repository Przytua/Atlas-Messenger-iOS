//
//  LSConversationListVC.m
//  LayerSample
//
//  Created by Kevin Coleman on 6/10/14.
//  Copyright (c) 2014 Layer, Inc. All rights reserved.
//

#import "LSConversationListViewController.h"
#import "LSConversationCell.h"
#import "LYRSampleConversation.h"
#import "LSContactsViewController.h"
#import "LSAppDelegate.h"

@interface LSConversationListViewController ()

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSOrderedSet *conversations;

@end

@implementation LSConversationListViewController

#define kConversationCellIdentifier       @"conversationCell"

- (id) init
{
    self = [super init];
    if(self) {
        self.view.backgroundColor = [UIColor lightGrayColor];
        self.title = @"Conversation";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self addRightBarButton];
    [self addLeftBarButton];
    [self setAccessibilityLabel:@"conversationList"];
    [self addCollectionView];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setLayerController:(LSLayerController *)layerController
{
    if(!_layerController) {
        _layerController = layerController;
    }
    [self fetchLayerConversations];
    [self.collectionView reloadData];
}

- (void)fetchLayerConversations
{
    NSOrderedSet *conversations = [self.layerController.client conversationsForIdentifiers:nil];
    self.conversations = conversations;
}

- (void)addLeftBarButton
{
    UIBarButtonItem *logout = [[UIBarButtonItem alloc] initWithTitle:@"Logout" style:UIBarButtonItemStylePlain target:self action:@selector(logoutTapped)];
    logout.accessibilityLabel = @"logout";
    [self.navigationItem setLeftBarButtonItem:logout];
}

- (void)addRightBarButton
{
    UIBarButtonItem *newConversation = [[UIBarButtonItem alloc] initWithTitle:@"+" style:UIBarButtonItemStylePlain target:self action:@selector(newConversationTapped)];
    newConversation.accessibilityLabel = @"new";
    [self.navigationItem setRightBarButtonItem:newConversation];
}

- (void)addCollectionView
{
    if (!self.collectionView) {
        self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.frame
                                                 collectionViewLayout:[[UICollectionViewFlowLayout alloc] init]];
        self.collectionView.delegate = self;
        self.collectionView.dataSource = self;
        self.collectionView.backgroundColor = [UIColor whiteColor];
        [self.view addSubview:self.collectionView];
    }
    [self.collectionView registerClass:[LSConversationCell class] forCellWithReuseIdentifier:kConversationCellIdentifier];
}

# pragma mark
# pragma mark Collection View Data Source
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.conversations.count;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    LSConversationCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:kConversationCellIdentifier forIndexPath:indexPath];
    [self configureCell:cell forIndexPath:indexPath];
    return cell;
}

- (LSConversationCell *)configureCell:(LSConversationCell *)cell forIndexPath:(NSIndexPath *)indexPath
{
    LYRConversation *conversation = [self.conversations objectAtIndex:indexPath.row];
    [cell updateCellWithConversation:conversation andLayerController:self.layerController];
    [cell setAccessibilityLabel:[self accessibilityLabelForParticipants:[conversation.participants allObjects]]];
    return cell;
}

- (NSString *)accessibilityLabelForParticipants:(NSArray *)participants
{
    NSString *label = @"conversationCell";
    for (NSString *userID in participants) {
        [label stringByAppendingString:[NSString stringWithFormat:@"+%@", userID]];
    }
    return label;
}

#pragma mark
#pragma mark Collection View Delegate
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    LYRConversation *conversation = [self.conversations objectAtIndex:indexPath.row];
    LSConversationViewController *viewController = [[LSConversationViewController alloc] init];
    [viewController setConversation:conversation];
    [viewController setLayerController:self.layerController];
    [self.navigationController pushViewController:viewController animated:TRUE];
}

#pragma mark – UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return CGSizeMake(320, 80);
}

- (UIEdgeInsets)collectionView: (UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsMake(0, 0, 0, 0);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
    return 0;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section
{
    return 0;
}

- (void)logoutTapped
{
    [self.delegate logout];
}

- (void)newConversationTapped
{
    LSContactsViewController *contactsViewController = [[LSContactsViewController alloc] init];
    contactsViewController.layerController = self.layerController;
    
    [self.navigationController pushViewController:contactsViewController animated:TRUE];
}

@end
