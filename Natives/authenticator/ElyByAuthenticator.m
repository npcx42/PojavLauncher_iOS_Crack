#import "AFNetworking.h"
#import "ElyByAuthenticator.h"
#import "../ios_uikit_bridge.h"
#import "../utils.h"

// URL для скачивания authlib-injector
#define AUTHLIB_INJECTOR_URL @"https://github.com/yushijinhun/authlib-injector/releases/download/v1.2.3/authlib-injector-1.2.3.jar"
#define AUTHLIB_INJECTOR_FILE @"authlib-injector.jar"
#define ELYBY_API_ROOT @"https://authserver.ely.by"

@implementation ElyByAuthenticator

- (NSString *)getAuthlibInjectorPath {
    NSString *path = [NSString stringWithFormat:@"%s/authlib-injector/%@", getenv("POJAV_HOME"), AUTHLIB_INJECTOR_FILE];
    return path;
}

- (BOOL)isAuthlibInjectorDownloaded {
    NSString *path = [self getAuthlibInjectorPath];
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (void)downloadAuthlibInjector:(void (^)(BOOL success, NSError *error))completion {
    NSString *dirPath = [NSString stringWithFormat:@"%s/authlib-injector", getenv("POJAV_HOME")];
    NSString *filePath = [self getAuthlibInjectorPath];
    
    // Создаем директорию если она не существует
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) {
        completion(NO, error);
        return;
    }
    
    // Скачиваем файл authlib-injector
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSURL *URL = [NSURL URLWithString:AUTHLIB_INJECTOR_URL];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:nil destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        return [NSURL fileURLWithPath:filePath];
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        if (error) {
            completion(NO, error);
        } else {
            completion(YES, nil);
        }
    }];
    [downloadTask resume];
}

- (void)ensureAuthlibInjectorWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    if ([self isAuthlibInjectorDownloaded]) {
        completion(YES, nil);
    } else {
        NSLog(@"[ElyByAuthenticator] Downloading authlib-injector from %@", AUTHLIB_INJECTOR_URL);
        [self downloadAuthlibInjector:^(BOOL success, NSError *error) {
            if (!success) {
                NSLog(@"[ElyByAuthenticator] Failed to download authlib-injector: %@", error.localizedDescription);
                
                // Создаем более информативное сообщение об ошибке
                NSString *errorMessage = [NSString stringWithFormat:@"Не удалось загрузить authlib-injector для Ely.by авторизации: %@", error.localizedDescription];
                NSError *customError = [NSError errorWithDomain:@"ElyByAuthenticator" 
                                                          code:1001 
                                                      userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
                
                completion(NO, customError);
            } else {
                NSLog(@"[ElyByAuthenticator] Successfully downloaded authlib-injector");
                completion(YES, nil);
            }
        }];
    }
}

// Метод для получения аргументов JVM для authlib-injector
- (NSArray *)getJvmArgsForAuthlib {
    NSString *injectorPath = [self getAuthlibInjectorPath];
    
    // Проверяем существование файла
    if (![[NSFileManager defaultManager] fileExistsAtPath:injectorPath]) {
        NSLog(@"[ElyByAuthenticator] Warning: authlib-injector file not found at %@", injectorPath);
        return @[];
    }
    
    NSString *jvmArg = [NSString stringWithFormat:@"-javaagent:%@=%@", injectorPath, ELYBY_API_ROOT];
    return @[jvmArg, @"-Dauthlibinjector.side=client"];
}

- (void)loginWithCallback:(Callback)callback {
    // Сначала проверяем/скачиваем authlib-injector
    [self ensureAuthlibInjectorWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            callback(error.localizedDescription, NO);
            return;
        }
        
        // Продолжаем процесс авторизации
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
            
            // Сохраняем информацию для authlib-injector
            self.authData[@"authserver"] = ELYBY_API_ROOT;
            
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
    }];
}

- (void)refreshTokenWithCallback:(Callback)callback {
    // Сначала проверяем/скачиваем authlib-injector
    [self ensureAuthlibInjectorWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            callback(error.localizedDescription, NO);
            return;
        }
        
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
    }];
}

@end 