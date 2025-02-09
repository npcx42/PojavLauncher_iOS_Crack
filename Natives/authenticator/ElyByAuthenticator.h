#import "BaseAuthenticator.h"

@interface ElyByAuthenticator : BaseAuthenticator

- (id)initWithData:(NSMutableDictionary *)data;
- (id)initWithInput:(NSString *)string;
- (void)loginWithCallback:(Callback)callback;
- (void)refreshTokenWithCallback:(Callback)callback;

@end