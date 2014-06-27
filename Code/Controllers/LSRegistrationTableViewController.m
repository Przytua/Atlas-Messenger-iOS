//
//  LSRegistrationTableViewController.m
//  LayerSample
//
//  Created by Kevin Coleman on 6/10/14.
//  Copyright (c) 2014 Layer, Inc. All rights reserved.
//

#import "LSRegistrationTableViewController.h"
#import "LSInputTableViewCell.h"
#import "LSButton.h"
#import "LSAlertView.h"
#import "LSConversationListViewController.h"
#import "LSAppDelegate.h"
#import "LSUserManager.h"
#import "LSUser.h"

@interface LSRegistrationTableViewController () <UITextFieldDelegate>

@property (nonatomic, strong) LSButton *registerButton;
@property (nonatomic, strong) LSAlertView *alertView;

@end

@implementation LSRegistrationTableViewController

static NSString *const LSRegistrationCellIdentifier = @"registrationCellIdentifier";

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Register";
    self.accessibilityLabel = @"Register Screen";
    
    [self initializeRegisterButton];
    [self configureLayoutConstraints];
    [self.tableView registerClass:[LSInputTableViewCell class] forCellReuseIdentifier:LSRegistrationCellIdentifier];
    self.alertView = [[LSAlertView alloc] init];
}

- (void)initializeRegisterButton
{
    self.registerButton = [[LSButton alloc] initWithText:@"Register"];
    [self.registerButton addTarget:self action:@selector(registerTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.registerButton];
}

- (void)configureLayoutConstraints
{
    self.registerButton.frame = CGRectMake(0, 0, 280, 60);
    self.registerButton.center = CGPointMake(self.view.center.x, 360);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 5;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 52;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    LSInputTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:LSRegistrationCellIdentifier forIndexPath:indexPath];
    [self configureCell:cell forIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(LSInputTableViewCell *)cell forIndexPath:(NSIndexPath *)path
{
    switch (path.row) {
        case 0:
            [cell setText:@"First Name"];
            cell.textField.accessibilityLabel = @"First Name";
            break;
        case 1:
            [cell setText:@"Last Name"];
            cell.textField.accessibilityLabel = @"Last Name";
        case 2:
            [cell setText:@"Email Address"];
            cell.textField.accessibilityLabel = @"Email";
            break;
        case 3:
            [cell setText:@"Password"];
            cell.textField.secureTextEntry = TRUE;
            cell.textField.accessibilityLabel = @"Password";
            break;
        case 4:
            [cell setText:@"Confirm"];
            cell.textField.secureTextEntry = TRUE;
            cell.textField.accessibilityLabel = @"Confirm";
            break;
        default:
            break;
    }
    cell.textField.delegate = self;
}

- (void)registerTapped
{
    LSInputTableViewCell *firstNameCell = (LSInputTableViewCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    LSInputTableViewCell *lastNameCell = (LSInputTableViewCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
    LSInputTableViewCell *emailCell = (LSInputTableViewCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:0]];
    LSInputTableViewCell *passwordCell = (LSInputTableViewCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:3 inSection:0]];
    LSInputTableViewCell *confirmationCell = (LSInputTableViewCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:0]];

    LSUser *user = [[LSUser alloc] init];
    [user setFirstName:firstNameCell.textField.text];
    [user setLastName:lastNameCell.textField.text];
    [user setEmail:emailCell.textField.text];
    [user setPassword:passwordCell.textField.text];
    [user setConfirmation:confirmationCell.textField.text];
    [user setIdentifier:[[NSUUID UUID] UUIDString]];
    
    [self.authenticationManager signUpUser:user completion:^(BOOL success, NSError *error) {
        if (!error && success) {
            [self.delegate registrationViewControllerDidFinish];
        } else {
            [self.delegate registrationViewControllerDidFailWithError:error];
        }
    }];
}

#pragma mark
#pragma mark UITextFieldDelegate Methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

@end
