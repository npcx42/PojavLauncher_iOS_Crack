#import "AFNetworking.h"
#import "ElyByAuthenticator.h"
#import "../ios_uikit_bridge.h"
#import "../utils.h"

@implementation ElyByAuthenticator

- (void)loginWithCallback:(Callback)callback {
    callback(localize(@"login.ely.progress.auth", nil), YES);
    
    NSString *username = self.authData[@"input"];
    NSString *password = self.authData[@"password"];
    
    if (username == nil || password == nil) {
        callback(@"Username or password is missing", NO);
        return;
    }
    
    NSDictionary *data = @{
        @"username": username,
        @"password": password,
        @"clientToken": [[NSUUID UUID] UUIDString]
    };
    
    AFHTTPSessionManager *manager = AFHTTPSessionManager.manager;
    manager.requestSerializer = AFJSONRequestSerializer.serializer;
    
    [manager POST:@"https://authserver.ely.by/auth/authenticate" parameters:data headers:nil progress:nil success:^(NSURLSessionDataTask *task, NSDictionary *response) {
        // Обработка успешного ответа
        self.authData[@"accessToken"] = response[@"accessToken"];
        self.authData[@"clientToken"] = response[@"clientToken"];
        self.authData[@"username"] = response[@"selectedProfile"][@"name"];
        self.authData[@"uuid"] = response[@"selectedProfile"][@"id"];
        self.authData[@"profileId"] = response[@"selectedProfile"][@"id"];
        
        // Форматирование UUID с дефисами
        NSString *uuid = response[@"selectedProfile"][@"id"];
        if (uuid.length == 32) { // Если UUID без дефисов
            self.authData[@"profileId"] = [NSString stringWithFormat:@"%@-%@-%@-%@-%@",
                [uuid substringWithRange:NSMakeRange(0, 8)],
                [uuid substringWithRange:NSMakeRange(8, 4)],
                [uuid substringWithRange:NSMakeRange(12, 4)],
                [uuid substringWithRange:NSMakeRange(16, 4)],
                [uuid substringWithRange:NSMakeRange(20, 12)]
            ];
        }
        
        // Установка URL аватара
        self.authData[@"profilePicURL"] = [NSString stringWithFormat:@"https://mc-heads.net/head/%@/120", self.authData[@"profileId"]];
        
        // Время истечения токена (24 часа)
        self.authData[@"expiresAt"] = @((long)[NSDate.date timeIntervalSince1970] + 86400);
        
        // Сохраняем изменения
        callback(nil, [self saveChanges]);
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSData *errorData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
        if (errorData) {
            NSDictionary *errorDict = [NSJSONSerialization JSONObjectWithData:errorData options:kNilOptions error:nil];
            callback(errorDict[@"errorMessage"] ?: error.localizedDescription, NO);
        } else {
            callback(error.localizedDescription, NO);
        }
    }];
}

- (void)refreshTokenWithCallback:(Callback)callback {
    callback(localize(@"login.ely.progress.refresh", nil), YES);
    
    NSDictionary *data = @{
        @"accessToken": self.authData[@"accessToken"],
        @"clientToken": self.authData[@"clientToken"]
    };
    
    AFHTTPSessionManager *manager = AFHTTPSessionManager.manager;
    manager.requestSerializer = AFJSONRequestSerializer.serializer;
    
    [manager POST:@"https://authserver.ely.by/auth/refresh" parameters:data headers:nil progress:nil success:^(NSURLSessionDataTask *task, NSDictionary *response) {
        // Обновляем токены
        self.authData[@"accessToken"] = response[@"accessToken"];
        self.authData[@"clientToken"] = response[@"clientToken"];
        
        // Время истечения токена (24 часа)
        self.authData[@"expiresAt"] = @((long)[NSDate.date timeIntervalSince1970] + 86400);
        
        // Сохраняем изменения
        callback(nil, [self saveChanges]);
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSData *errorData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
        if (errorData) {
            NSDictionary *errorDict = [NSJSONSerialization JSONObjectWithData:errorData options:kNilOptions error:nil];
            callback(errorDict[@"errorMessage"] ?: error.localizedDescription, NO);
        } else {
            callback(error.localizedDescription, NO);
        }
    }];
}

@end 