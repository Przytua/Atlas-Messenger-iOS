//
//  ATLMConfigurationTests.m
//  Atlas Messenger
//
//  Created by JP McGlone on 2/3/17.
//  Copyright © 2017 Layer, Inc. All rights reserved.
//

#import "ATLMConfiguration.h"
#import "ATLMConfigurationSet.h"
#import <Expecta/Expecta.h>
#import <XCTest/XCTest.h>

@interface ATLMConfigurationTests : XCTestCase

@end

/**
 @abstract Locates and returns the test configuration file used in this test case.
 @param suffix Appends a given string at the end of the filename with a dash ('-')
   in front of it.
 @return Returns a file `NSURL` instance pointing to the test configuration file.
 */
NSURL *ATLMConfigurationTestsDefaultConfigurationPath(NSString *__nullable suffix)
{
    NSBundle *bundle = [NSBundle bundleForClass:[ATLMConfigurationTests class]];
    NSURL *fileURL = [bundle URLForResource:suffix == nil ? @"TestLayerConfiguration": [@"TestLayerConfiguration-" stringByAppendingString:suffix] withExtension:@"json"];
    return fileURL;
}

@implementation ATLMConfigurationTests

- (void)testInitSuccessfullyDeserializesValidConfigurationFile
{
    ATLMConfigurationSet *configuration = [[ATLMConfigurationSet alloc] initWithFileURL:ATLMConfigurationTestsDefaultConfigurationPath(nil)];
    expect(configuration.configurations.anyObject.appID.absoluteString).to.equal(@"layer:///apps/staging/test");
    expect(configuration.configurations.anyObject.identityProviderURL.absoluteString).to.equal(@"https://test.herokuapp.com");
    expect(configuration.configurations.anyObject.name).to.equal(@"TestApp");
}

- (void)testConfigurationWithEndpointOverrides
{
    ATLMConfigurationSet *configuration = [[ATLMConfigurationSet alloc] initWithFileURL:ATLMConfigurationTestsDefaultConfigurationPath(@"withEndpoints")];
    expect(configuration.configurations.anyObject.appID.absoluteString).to.equal(@"layer:///apps/staging/9ec30af8-5591-11e4-af9e-f7a201004a3b");
    expect(configuration.configurations.anyObject.identityProviderURL.absoluteString).to.equal(@"http://layer-identity-provider.herokuapp.com/users/sign_in.json");
    expect(configuration.configurations.anyObject.name).to.equal(@"Prod1-Staging");

    expect(configuration.configurations.anyObject.configurationEndpoint).to.equal([NSURL URLWithString:@"https://conf.lyr8.net/conf"]);
    expect(configuration.configurations.anyObject.certificatesEndpoint).to.equal([NSURL URLWithString:@"https://certs.lyr8.net/certificates"]);
    expect(configuration.configurations.anyObject.authenticationEndpoint).to.equal([NSURL URLWithString:@"https://sync.lyr8.net"]);
    expect(configuration.configurations.anyObject.synchronizationEndpoint).to.equal([NSURL URLWithString:@"https://sync.lyr8.net/"]);
}

#pragma mark - Failure modes
#pragma mark - 

#pragma mark Init

- (void)testInitShouldFail
{
    // Call wrong initialization method
    expect(^{
        id allocatedConfig = [ATLMConfigurationSet alloc];
        __unused id noresult = [allocatedConfig init];
    }).to.raiseWithReason(NSInternalInconsistencyException, @"Failed to call designated initializer. Call the designated initializer 'initWithFileURL:' on the `ATLMConfigurationSet` instead.");
}

- (void)testInitPassingNilShouldFail
{
    // Pass in `nil` as fileURL.
    expect(^{
        __unused id nullVal = nil;
        __unused id noresult = [[ATLMConfigurationSet alloc] initWithFileURL:nullVal];
    }).to.raiseWithReason(NSInvalidArgumentException, @"Failed to initialize `ATLMConfigurationSet` because the `fileURL` argument was `nil`.");
}

- (void)testInitPassingInvalidPathShouldFail
{
    // Pass a non-readable path as fileURL.
    expect(^{
        __unused id noresult = [[ATLMConfigurationSet alloc] initWithFileURL:[NSURL URLWithString:@"/dev/null"]];
    }).to.raiseWithReason(NSInternalInconsistencyException, @"Failed to initialize `ATLMConfigurationSet` because the input file could not be read; error=Error Domain=NSCocoaErrorDomain Code=256 \"The file “null” couldn’t be opened.\" UserInfo={NSURL=/dev/null}");
}

- (void)testInitPassingInvalidJSONShouldFail
{
    // Pass a non-readable path as fileURL.
    expect(^{
        __unused id noresult = [[ATLMConfigurationSet alloc] initWithFileURL:ATLMConfigurationTestsDefaultConfigurationPath(@"invalid")];
    }).to.raiseWithReason(NSInternalInconsistencyException, @"Failed to initialize `ATLMConfigurationSet` because the input file could not be deserialized; error=Error Domain=NSCocoaErrorDomain Code=3840 \"Something looked like a 'null' but wasn't around character 0.\" UserInfo={NSDebugDescription=Something looked like a 'null' but wasn't around character 0.}");
}

#pragma mark Null values

- (void)testInitFailingDueToNullName
{
    // Pass a non-readable path as fileURL.
    expect(^{
        __unused id noresult = [[ATLMConfigurationSet alloc] initWithFileURL:ATLMConfigurationTestsDefaultConfigurationPath(@"nameNull")];
    }).to.raiseWithReason(NSInternalInconsistencyException, @"Failed to initialize `ATLMConfiguration` because `name` key value in the input file was `null`.");
}

- (void)testInitFailingDueToNullAppID
{
    // Pass a non-readable path as fileURL.
    expect(^{
        __unused id noresult = [[ATLMConfigurationSet alloc] initWithFileURL:ATLMConfigurationTestsDefaultConfigurationPath(@"appIDNull")];
    }).to.raiseWithReason(NSInternalInconsistencyException, @"Failed to initialize `ATLMConfiguration` because `app_id` key value in the input file was `null`.");
}

- (void)testInitFailingDueToNullIdentityProviderURL
{
    // Pass a non-readable path as fileURL.
    expect(^{
        __unused id noresult = [[ATLMConfigurationSet alloc] initWithFileURL:ATLMConfigurationTestsDefaultConfigurationPath(@"identityProviderURLNull")];
    }).to.raiseWithReason(NSInternalInconsistencyException, @"Failed to initialize `ATLMConfiguration` because `identity_provider_url` key value in the input file was `null`.");
}

#pragma mark Invalid URLs

- (void)testInitFailingDueToInvalidAppID
{
    // Pass a non-readable path as fileURL.
    expect(^{
        __unused id noresult = [[ATLMConfigurationSet alloc] initWithFileURL:ATLMConfigurationTestsDefaultConfigurationPath(@"appIDInvalid")];
    }).to.raiseWithReason(NSInternalInconsistencyException, @"Failed to initialize `ATLMConfiguration` because `app_id` key value (` `) in the input file was not a valid URL.");
}

- (void)testInitFailingDueToInvalidIdentityProviderURL
{
    // Pass a non-readable path as fileURL.
    expect(^{
        __unused id noresult = [[ATLMConfigurationSet alloc] initWithFileURL:ATLMConfigurationTestsDefaultConfigurationPath(@"identityProviderURLInvalid")];
    }).to.raiseWithReason(NSInternalInconsistencyException, @"Failed to initialize `ATLMConfiguration` because `identity_provider_url` key value (` `) in the input file was not a valid URL.");
}

#pragma mark Missing values

- (void)testInitFailingDueToNameMissing
{
    // Pass a non-readable path as fileURL.
    expect(^{
        __unused id noresult = [[ATLMConfigurationSet alloc] initWithFileURL:ATLMConfigurationTestsDefaultConfigurationPath(@"nameMissing")];
    }).to.raiseWithReason(NSInternalInconsistencyException, @"Failed to initialize `ATLMConfiguration` because `name` key in the input file was not set.");
}

- (void)testInitFailingDueToIdentityProviderURLMissing
{
    // Pass a non-readable path as fileURL.
    expect(^{
        __unused id noresult = [[ATLMConfigurationSet alloc] initWithFileURL:ATLMConfigurationTestsDefaultConfigurationPath(@"identityProviderURLNotSet")];
    }).to.raiseWithReason(NSInternalInconsistencyException, @"Failed to initialize `ATLMConfiguration` because `identity_provider_url` key in the input file was not set.");
}

- (void)testInitFailingDueToAppIDMissing
{
    // Pass a non-readable path as fileURL.
    expect(^{
        __unused id noresult = [[ATLMConfigurationSet alloc] initWithFileURL:ATLMConfigurationTestsDefaultConfigurationPath(@"appIDNotSet")];
    }).to.raiseWithReason(NSInternalInconsistencyException, @"Failed to initialize `ATLMConfiguration` because `app_id` key in the input file was not set.");
}

#pragma mark Type mismatches

- (void)testInitFailingDueToJSONNotAnArray
{
    // Pass a non-readable path as fileURL.
    expect(^{
        __unused id noresult = [[ATLMConfigurationSet alloc] initWithFileURL:ATLMConfigurationTestsDefaultConfigurationPath(@"notArray")];
    }).to.raiseWithReason(NSInternalInconsistencyException, @"Failed to initialize `ATLMConfigurationSet` because the input file JSON root was not an array");
}

- (void)testInitFailingDueToNameNotString
{
    // Pass a non-readable path as fileURL.
    expect(^{
        __unused id noresult = [[ATLMConfigurationSet alloc] initWithFileURL:ATLMConfigurationTestsDefaultConfigurationPath(@"nameNotString")];
    }).to.raiseWithReason(NSInternalInconsistencyException, @"Failed to initialize `ATLMConfiguration` because `name` key in the input file was not an NSString.");
}

@end
