#import "ElyByAuthenticator.h"
#import "AFNetworking.h"

@implementation ElyByAuthenticator

- (id)initWithData:(NSMutableDictionary *)data {
    self = [super initWithData:data];
    return self;
}

- (id)initWithInput:(NSString *)string {
    self = [super initWithInput:string];
    return self;
}

- (void)loginWithCallback:(Callback)callback {
    NSString *urlString = @"https://authserver.ely.by/auth/authenticate";
    NSDictionary *parameters = @{
        @"username": self.authData[@"input"],
        @"password": self.authData[@"password"],
        @"clientToken": [[NSUUID UUID] UUIDString],
        @"requestUser": @YES
    };

    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    [manager POST:urlString parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        NSDictionary *responseDict = (NSDictionary *)responseObject;
        self.authData[@"accessToken"] = responseDict[@"accessToken"];
        self.authData[@"username"] = responseDict[@"selectedProfile"][@"name"];
        self.authData[@"profilePicURL"] = @"https://ely.by/api/minecraft/profile/texture/uuid"; // Replace with actual URL if available
        callback(responseDict, YES);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        callback(error, NO);
    }];
}

- (void)refreshTokenWithCallback:(Callback)callback {
    NSString *urlString = @"https://authserver.ely.by/auth/refresh";
    NSDictionary *parameters = @{
        @"accessToken": self.authData[@"accessToken"],
        @"clientToken": self.authData[@"clientToken"],
        @"requestUser": @YES
    };

    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    [manager POST:urlString parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        NSDictionary *responseDict = (NSDictionary *)responseObject;
        self.authData[@"accessToken"] = responseDict[@"accessToken"];
        callback(responseDict, YES);
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        callback(error, NO);
    }];
}

@end