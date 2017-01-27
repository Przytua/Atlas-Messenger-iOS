//
//  ATLMAuthenticationProvider.m
//  Atlas Messenger
//
//  Created by Kevin Coleman on 5/26/16.
//  Copyright © 2016 Layer, Inc. All rights reserved.
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


#import "ATLMAuthenticationProvider.h"
#import "ATLMHTTPResponseSerializer.h"
#import "ATLMConstants.h"

NSString *const ATLMEmailKey = @"ATLMEmailKey";
NSString *const ATLMPasswordKey = @"ATLMPasswordKey";
NSString *const ATLMCredentialsKey = @"DIMCredentialsKey";
static NSString *const ATLMAtlasIdentityTokenKey = @"identity_token";

@interface ATLMAuthenticationProvider ();

@property (strong, nonnull) NSURL *baseURL;

- (NSString *)authenticateEndpoint;
- (NSString *)listUsersEndpoint;

@end

@implementation ATLMAuthenticationProvider

+ (instancetype)defaultProvider {
    return [self providerWithBaseURL:[NSURL URLWithString:ATLMIdentityProviderRoot]];
}

+ (nonnull instancetype)providerWithBaseURL:(nonnull NSURL *)baseURL
{
    return  [[self alloc] initWithBaseURL:baseURL];
}

- (id)initWithBaseURL:(nonnull NSURL *)baseURL;
{
    self = [super init];
    if (self) {
        _baseURL = baseURL;
    }
    return self;
}

- (NSString *)authenticateEndpoint {
    return @"/authenticate";
}

- (NSString *)listUsersEndpoint {
    return @"/users.json";
}

- (void)authenticateWithCredentials:(NSDictionary *)credentials nonce:(NSString *)nonce completion:(void (^)(NSString *identityToken, NSError *error))completion {
    NSURL *authenticateURL = [NSURL URLWithString:[self authenticateEndpoint] relativeToURL:self.baseURL];
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:credentials];
    [payload setObject:nonce forKey:@"nonce"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:authenticateURL];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        
        [[NSUserDefaults standardUserDefaults] setValue:credentials forKey:ATLMCredentialsKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        // TODO: Basic response and content checks — status and length
        NSError *serializationError;
        NSDictionary *rawResponse = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:0 error:&serializationError];
        if (serializationError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, serializationError);
            });
        }
        
        NSString *identityToken = rawResponse[@"identity_token"];
        // TODO: completion with error if identityToken is nil
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(identityToken, nil);
        });
    }] resume];
}

- (void)refreshAuthenticationWithNonce:(NSString *)nonce completion:(void (^)(NSString *identityToken, NSError *error))completion
{
    NSDictionary *credentials = [[NSUserDefaults standardUserDefaults] objectForKey:ATLMCredentialsKey];
    [self authenticateWithCredentials:credentials nonce:nonce completion:^(NSString * _Nonnull identityToken, NSError * _Nonnull error) {
        completion(identityToken, error);
    }];
}

- (void)getUsersAuthenticatedUserCanChatWith:(NSString *)authenticatedUserID completion:(void (^)(NSArray *users, NSError *error))completion {
    NSURL *listUsersURL = [NSURL URLWithString:[self listUsersEndpoint] relativeToURL:self.baseURL];
    NSURLComponents *components = [NSURLComponents componentsWithURL:listUsersURL resolvingAgainstBaseURL:YES];
    [components setQuery:[NSString stringWithFormat:@"requester=%@", authenticatedUserID]];
    listUsersURL = [components URL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:listUsersURL];
    request.HTTPMethod = @"GET";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        
        NSError *serializationError;
        NSArray *usersList = (NSArray *)[[NSJSONSerialization JSONObjectWithData:data options:0 error:&serializationError] objectForKey:@"users"];
        if (serializationError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, serializationError);
            });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(usersList, nil);
        });
    }] resume];
}

@end