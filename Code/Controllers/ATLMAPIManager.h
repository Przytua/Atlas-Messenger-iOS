//
//  ATLMAPIManager.h
//  Atlas Messenger
//
//  Created by Kevin Coleman on 6/12/14.
//  Copyright (c) 2014 Layer, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>
#import <LayerKit/LayerKit.h>
#import "ATLMUser.h"
#import "ATLMPersistenceManager.h"

extern NSString *const ATLMUserDidAuthenticateNotification;
extern NSString *const ATLMUserDidDeauthenticateNotification;

/**
 @abstract The `ATLMAPIManager` class provides an interface for interacting with the Layer Identity Provider JSON API and managing 
 the Layer sample app authentication state.
 */
@interface ATLMAPIManager : NSObject

///--------------------------------
/// @name Initializing a Manager
///--------------------------------

+ (instancetype)managerWithBaseURL:(NSURL *)baseURL layerClient:(LYRClient *)layerClient;

/**
 @abstract The current authenticated session or `nil` if not yet authenticated.
 */
@property (nonatomic, readonly) ATLMSession *authenticatedSession;

/**
 @abstract The current authenticated URL session configuration or `nil` if not yet authenticated.
 */
@property (nonatomic, readonly) NSURLSessionConfiguration *authenticatedURLSessionConfiguration;


///------------------------------------
/// @name JSON API Interface
///------------------------------------

/**
 @abstract Registers a new user with the Layer sample backend Rails application.
 @param user The model object representing the user attempting to authenticate.
 @param completion The completion block that will be called upon completion of the registration operation. Completion block cannot be `nil`.
 */
- (void)registerUser:(ATLMUser *)user completion:(void(^)(ATLMUser *user, NSError *error))completion;

/**
 @abstract Authenticates an existing user with the Layer sample backend Rails application. This method takes a nonce value that must be
 obtained from LayerKit. It returns an identity token in the completion block that can be used to authenticate LayerKit.
 @param email The email address for the user attempting to authenticate.
 @param password The password for the user attempting to authenticate.
 @param nonce The nonce obtained from LayerKit.
 @param completion The completion block that is called upon completion of the authentication operation. Upon succesful authentication, 
 an identityToken will be returned. Completion block cannot be `nil`.
 */
- (void)authenticateWithEmail:(NSString *)email password:(NSString *)password nonce:(NSString *)nonce completion:(void(^)(NSString *identityToken, NSError *error))completion;

/**
 @abstract Loads all contacts from the Layer sample backend Rails application.
 @param completion The completion block that is called upon successfully loading contacts. Completion block cannot be `nil`.
 */
- (void)loadContactsWithCompletion:(void(^)(NSSet *contacts, NSError *error))completion;

/**
 @abstract Deletes all contacts from the Layer sample backend Rails application.
 @param completion The completion block that is call upon successful deletion of all contacts. Completion block cannot be `nil`.
 */
- (void)deleteAllContactsWithCompletion:(void(^)(BOOL completion, NSError *error))completion;

///------------------------------
/// @name Authentication State
///------------------------------

/**
 @abstract Resumes a Layer sample app session.
 @param session The model object for the current session.
 @param error A reference to an `NSError` object that will contain error information in case the action was not successful.
 @return A boolean value that indicates if the manager has a valid session.
 @discussion Note that if the manager already has a session, the manager will continue to use the existing session (ignoring the passed session) and this method will return `YES`.
 */
- (BOOL)resumeSession:(ATLMSession *)session error:(NSError **)error;

/**
 @abstract Deauthenticates the Layer sample app by discarding its `ATLMSession` object.
 */
- (void)deauthenticate;

@end
