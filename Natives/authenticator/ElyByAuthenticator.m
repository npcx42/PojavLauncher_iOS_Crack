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

// Метод для обработки повторной попытки входа с двухфакторной аутентификацией
- (void)loginWithTwoFactorToken:(NSString *)token callback:(Callback)callback {
    NSString *username = self.authData[@"input"];
    NSString *password = self.authData[@"password"];
    
    if (username.length == 0 || password.length == 0) {
        callback(localize(@"login.error.fields.empty", nil), NO);
        return;
    }
    
    // Добавляем токен двухфакторной аутентификации к паролю
    NSString *passwordWithToken = [NSString stringWithFormat:@"%@:%@", password, token];
    
    NSDictionary *data = @{
        @"username": username,
        @"password": passwordWithToken,
        @"clientToken": [[NSUUID UUID] UUIDString]
    };
    
    AFHTTPSessionManager *manager = AFHTTPSessionManager.manager;
    manager.requestSerializer = AFJSONRequestSerializer.serializer;
    
    [self sendAuthenticateRequest:data manager:manager callback:callback];
}

// Вспомогательный метод для отправки запроса аутентификации
- (void)sendAuthenticateRequest:(NSDictionary *)data manager:(AFHTTPSessionManager *)manager callback:(Callback)callback {
    NSString *authURL = [NSString stringWithFormat:@"%@/auth/authenticate", ELYBY_API_ROOT];
    
    [manager POST:authURL parameters:data headers:nil progress:nil success:^(NSURLSessionDataTask *task, NSDictionary *response) {
        @try {
            // Обработка успешного ответа
            if (![response isKindOfClass:[NSDictionary class]]) {
                callback(localize(@"login.error.invalid_response", @"Invalid server response"), NO);
                return;
            }
            
            if (!response[@"accessToken"] || !response[@"clientToken"] || !response[@"selectedProfile"]) {
                callback(localize(@"login.error.invalid_response", @"Invalid server response"), NO);
                return;
            }
            
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
        } @catch (NSException *exception) {
            NSLog(@"[ElyByAuthenticator] Exception in login success: %@", exception);
            callback([NSString stringWithFormat:@"Error: %@", exception.reason], NO);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSData *errorData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
        NSHTTPURLResponse *response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
        
        if (errorData) {
            @try {
                NSDictionary *errorDict = [NSJSONSerialization JSONObjectWithData:errorData options:kNilOptions error:nil];
                
                // Проверка на двухфакторную аутентификацию (код 401 + определенное сообщение об ошибке)
                if (response.statusCode == 401 && 
                    [errorDict[@"error"] isEqualToString:@"ForbiddenOperationException"] &&
                    [errorDict[@"errorMessage"] isEqualToString:@"Account protected with two factor auth."]) {
                    
                    NSLog(@"[ElyByAuthenticator] Two-factor authentication required");
                    
                    // Запрашиваем TOTP-код через UI
                    // Примечание: здесь нужно добавить диалог для ввода кода
                    // Это упрощенная реализация для демонстрации логики
                    UIAlertController *alert = [UIAlertController 
                        alertControllerWithTitle:localize(@"login.ely.2fa.title", @"Two-Factor Authentication")
                        message:localize(@"login.ely.2fa.message", @"Please enter your two-factor authentication code")
                        preferredStyle:UIAlertControllerStyleAlert];
                    
                    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                        textField.placeholder = localize(@"login.ely.2fa.code", @"Authentication code");
                        textField.keyboardType = UIKeyboardTypeNumberPad;
                    }];
                    
                    UIAlertAction *okAction = [UIAlertAction 
                        actionWithTitle:localize(@"OK", @"OK") 
                        style:UIAlertActionStyleDefault 
                        handler:^(UIAlertAction *action) {
                            NSString *code = alert.textFields.firstObject.text;
                            if (code.length > 0) {
                                [self loginWithTwoFactorToken:code callback:callback];
                            } else {
                                callback(localize(@"login.ely.2fa.empty", @"Authentication code cannot be empty"), NO);
                            }
                        }];
                    
                    UIAlertAction *cancelAction = [UIAlertAction 
                        actionWithTitle:localize(@"Cancel", @"Cancel") 
                        style:UIAlertActionStyleCancel 
                        handler:^(UIAlertAction *action) {
                            callback(localize(@"login.cancelled", @"Login cancelled"), NO);
                        }];
                    
                    [alert addAction:okAction];
                    [alert addAction:cancelAction];
                    
                    // Получаем ViewController для отображения алерта
                    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
                    [rootVC presentViewController:alert animated:YES completion:nil];
                    return;
                }
                
                callback(errorDict[@"errorMessage"] ?: error.localizedDescription, NO);
            } @catch (NSException *exception) {
                callback(error.localizedDescription, NO);
            }
        } else {
            callback(error.localizedDescription, NO);
        }
    }];
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
        
        if (username.length == 0 || password.length == 0) {
            callback(localize(@"login.error.fields.empty", nil), NO);
            return;
        }
        
        NSDictionary *data = @{
            @"username": username,
            @"password": password,
            @"clientToken": [[NSUUID UUID] UUIDString]
        };
        
        AFHTTPSessionManager *manager = AFHTTPSessionManager.manager;
        manager.requestSerializer = AFJSONRequestSerializer.serializer;
        
        [self sendAuthenticateRequest:data manager:manager callback:callback];
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
        
        NSString *accessToken = self.authData[@"accessToken"];
        NSString *clientToken = self.authData[@"clientToken"];
        
        if (accessToken.length == 0 || clientToken.length == 0) {
            callback(localize(@"login.error.token_missing", @"Access token or client token is missing"), NO);
            return;
        }
        
        NSDictionary *data = @{
            @"accessToken": accessToken,
            @"clientToken": clientToken
        };
        
        AFHTTPSessionManager *manager = AFHTTPSessionManager.manager;
        manager.requestSerializer = AFJSONRequestSerializer.serializer;
        
        NSString *refreshURL = [NSString stringWithFormat:@"%@/auth/refresh", ELYBY_API_ROOT];
        
        [manager POST:refreshURL parameters:data headers:nil progress:nil success:^(NSURLSessionDataTask *task, NSDictionary *response) {
            @try {
                // Обновляем токены
                if (![response isKindOfClass:[NSDictionary class]] || !response[@"accessToken"] || !response[@"clientToken"]) {
                    callback(localize(@"login.error.invalid_response", @"Invalid server response"), NO);
                    return;
                }
                
                self.authData[@"accessToken"] = response[@"accessToken"];
                self.authData[@"clientToken"] = response[@"clientToken"];
                
                // Обновляем selectedProfile если оно есть
                if (response[@"selectedProfile"]) {
                    self.authData[@"username"] = response[@"selectedProfile"][@"name"];
                    self.authData[@"uuid"] = response[@"selectedProfile"][@"id"];
                }
                
                // Время истечения токена (24 часа)
                self.authData[@"expiresAt"] = @((long)[NSDate.date timeIntervalSince1970] + 86400);
                
                // Сохраняем изменения
                callback(nil, [self saveChanges]);
            } @catch (NSException *exception) {
                NSLog(@"[ElyByAuthenticator] Exception in refresh success: %@", exception);
                callback([NSString stringWithFormat:@"Error: %@", exception.reason], NO);
            }
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSData *errorData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
            if (errorData) {
                @try {
                    NSDictionary *errorDict = [NSJSONSerialization JSONObjectWithData:errorData options:kNilOptions error:nil];
                    
                    // Проверка на ошибку истекшего токена
                    if ([errorDict[@"error"] isEqualToString:@"ForbiddenOperationException"] && 
                        [errorDict[@"errorMessage"] isEqualToString:@"Token expired."]) {
                        callback(localize(@"login.error.token_expired", @"Authentication token has expired, please log in again"), NO);
                        return;
                    }
                    
                    callback(errorDict[@"errorMessage"] ?: error.localizedDescription, NO);
                } @catch (NSException *exception) {
                    callback(error.localizedDescription, NO);
                }
            } else {
                callback(error.localizedDescription, NO);
            }
        }];
    }];
}

@end 