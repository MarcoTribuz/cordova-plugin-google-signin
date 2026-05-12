#import "GoogleSignInPlugin.h"
@import GoogleSignIn;

@implementation GoogleSignInPlugin

// ─── Lifecycle ────────────────────────────────────────────────────────────────

- (void)pluginInitialize {
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(handleOpenURLWithAppSourceAndAnnotation:)
               name:CDVPluginHandleOpenURLWithAppSourceAndAnnotationNotification
             object:nil];
}

// Handles the OAuth redirect URL (REVERSED_CLIENT_ID scheme).
- (void)handleOpenURLWithAppSourceAndAnnotation:(NSNotification *)notification {
    NSDictionary *options = notification.object;
    NSURL *url = options[@"url"];
    if (url) {
        [GIDSignIn.sharedInstance handleURL:url];
    }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

- (NSString *)reversedClientId {
    NSArray *urlTypes = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleURLTypes"];
    for (NSDictionary *dict in urlTypes) {
        if ([dict[@"CFBundleURLName"] isEqualToString:@"REVERSED_CLIENT_ID"]) {
            NSArray *schemes = dict[@"CFBundleURLSchemes"];
            if (schemes.count > 0) return schemes[0];
        }
    }
    return nil;
}

- (NSString *)clientIdFromReversed:(NSString *)reversed {
    NSArray *parts = [reversed componentsSeparatedByString:@"."];
    return [[[parts reverseObjectEnumerator] allObjects] componentsJoinedByString:@"."];
}

- (void)sendError:(CDVInvokedUrlCommand *)command message:(NSString *)message {
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                               messageAsString:message];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)sendSuccess:(CDVInvokedUrlCommand *)command dict:(NSDictionary *)dict {
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                            messageAsDictionary:dict];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (NSDictionary *)buildResult:(GIDGoogleUser *)user serverAuthCode:(NSString *)serverAuthCode {
    NSURL *imageURL = [user.profile imageURLWithDimension:120];
    return @{
        @"email":          user.profile.email         ?: @"",
        @"idToken":        user.idToken.tokenString   ?: @"",
        @"accessToken":    user.accessToken.tokenString ?: @"",
        @"serverAuthCode": serverAuthCode             ?: @"",
        @"userId":         user.userID                ?: @"",
        @"displayName":    user.profile.name          ?: [NSNull null],
        @"givenName":      user.profile.givenName     ?: [NSNull null],
        @"familyName":     user.profile.familyName    ?: [NSNull null],
        @"imageUrl":       imageURL ? imageURL.absoluteString : [NSNull null],
    };
}

// ─── Actions ─────────────────────────────────────────────────────────────────

- (void)login:(CDVInvokedUrlCommand *)command {
    NSDictionary *options = command.arguments.firstObject;

    NSString *reversedClientId = [self reversedClientId];
    if (!reversedClientId) {
        [self sendError:command message:@"REVERSED_CLIENT_ID not found in Info.plist"];
        return;
    }

    NSString *clientId    = [self clientIdFromReversed:reversedClientId];
    NSString *serverClientId = options[@"webClientId"];
    BOOL offline          = [options[@"offline"] boolValue];

    // GIDConfiguration carries both clientID and serverClientID (needed for serverAuthCode)
    GIDConfiguration *config = serverClientId && offline
        ? [[GIDConfiguration alloc] initWithClientID:clientId serverClientID:serverClientId]
        : [[GIDConfiguration alloc] initWithClientID:clientId];
    GIDSignIn.sharedInstance.configuration = config;

    // Build additional scopes beyond the default (email + profile)
    NSMutableArray *additionalScopes = [NSMutableArray array];
    NSString *scopesString = options[@"scopes"];
    if (scopesString) {
        for (NSString *s in [scopesString componentsSeparatedByString:@" "]) {
            if (![s isEqualToString:@"email"] && ![s isEqualToString:@"profile"]) {
                [additionalScopes addObject:s];
            }
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [GIDSignIn.sharedInstance signInWithPresentingViewController:self.viewController
                                                                hint:nil
                                                    additionalScopes:additionalScopes
                                                          completion:^(GIDSignInResult *result, NSError *error) {
            if (error) {
                [self sendError:command message:error.localizedDescription];
                return;
            }
            [self sendSuccess:command dict:[self buildResult:result.user
                                              serverAuthCode:result.serverAuthCode]];
        }];
    });
}

- (void)trySilentLogin:(CDVInvokedUrlCommand *)command {
    NSDictionary *options = command.arguments.firstObject;

    NSString *reversedClientId = [self reversedClientId];
    if (reversedClientId) {
        NSString *clientId    = [self clientIdFromReversed:reversedClientId];
        NSString *serverClientId = options[@"webClientId"];
        BOOL offline          = [options[@"offline"] boolValue];
        GIDConfiguration *config = serverClientId && offline
            ? [[GIDConfiguration alloc] initWithClientID:clientId serverClientID:serverClientId]
            : [[GIDConfiguration alloc] initWithClientID:clientId];
        GIDSignIn.sharedInstance.configuration = config;
    }

    [GIDSignIn.sharedInstance restorePreviousSignInWithCompletion:^(GIDGoogleUser *user, NSError *error) {
        if (error) {
            [self sendError:command message:error.localizedDescription];
            return;
        }
        // serverAuthCode not available on silent restore — server uses cached tokens
        [self sendSuccess:command dict:[self buildResult:user serverAuthCode:@""]];
    }];
}

- (void)logout:(CDVInvokedUrlCommand *)command {
    [GIDSignIn.sharedInstance signOut];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                               messageAsString:@"logged out"];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)disconnect:(CDVInvokedUrlCommand *)command {
    [GIDSignIn.sharedInstance disconnectWithCompletion:^(NSError *error) {
        if (error) {
            [self sendError:command message:error.localizedDescription];
            return;
        }
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                   messageAsString:@"disconnected"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
}

@end
