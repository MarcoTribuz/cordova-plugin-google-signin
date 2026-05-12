#import <Cordova/CDVPlugin.h>

@interface GoogleSignInPlugin : CDVPlugin

@property (nonatomic, copy) NSString *callbackId;

- (void)login:(CDVInvokedUrlCommand *)command;
- (void)trySilentLogin:(CDVInvokedUrlCommand *)command;
- (void)logout:(CDVInvokedUrlCommand *)command;
- (void)disconnect:(CDVInvokedUrlCommand *)command;

@end
