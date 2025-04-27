#import "PLLocalization.h"
#import <UIKit/UIKit.h>

// Константы
#define PL_LOCALIZATION_VERSION 1
#define PL_LOCALIZATION_CACHE_EXPIRATION 3600.0 // 1 час
#define PL_LOCALIZATION_DEBUG NO // Включить режим отладки

@implementation PLLocalization

// Статические переменные для кэширования
static NSMutableDictionary *_stringCache;
static NSMutableDictionary *_fallbackStrings;
static NSMutableDictionary *_missingKeys;
static NSDate *_lastCacheUpdateTime;
static NSString *_currentLanguage;
static BOOL _hasLoadedBaseFallbacks;
static BOOL _hasRegisteredNotifications;

#pragma mark - Инициализация

+ (void)initialize {
    if (self == [PLLocalization class]) {
        _stringCache = [NSMutableDictionary dictionary];
        _fallbackStrings = [NSMutableDictionary dictionary];
        _missingKeys = [NSMutableDictionary dictionary];
        _lastCacheUpdateTime = [NSDate date];
        _hasLoadedBaseFallbacks = NO;
        _hasRegisteredNotifications = NO;
        
        // Загружаем критичные строки при инициализации
        [self loadBaseFallbacks];
        
        // Регистрируем уведомления об изменении языка
        [self registerForNotifications];
    }
}

+ (void)registerForNotifications {
    if (_hasRegisteredNotifications) return;
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    // Отслеживаем смену языка
    [center addObserver:self 
               selector:@selector(handleLanguageChange:) 
                   name:NSCurrentLocaleDidChangeNotification 
                 object:nil];
    
    // Отслеживаем низкую память
    [center addObserver:self 
               selector:@selector(handleLowMemory:) 
                   name:UIApplicationDidReceiveMemoryWarningNotification 
                 object:nil];
    
    _hasRegisteredNotifications = YES;
}

+ (void)handleLanguageChange:(NSNotification *)notification {
    // Сбрасываем кэш при смене языка
    [self reloadLocalizations];
}

+ (void)handleLowMemory:(NSNotification *)notification {
    // Освобождаем часть кэша при низкой памяти
    @synchronized(_stringCache) {
        [_stringCache removeAllObjects];
    }
    
    _lastCacheUpdateTime = [NSDate dateWithTimeIntervalSince1970:0];
}

#pragma mark - Загрузка базовых строк

+ (void)loadBaseFallbacks {
    if (_hasLoadedBaseFallbacks) return;
    
    // Критические UI-строки, которые всегда должны быть доступны
    NSDictionary *criticalStrings = @{
        @"OK": @"OK",
        @"Cancel": @"Cancel",
        @"Yes": @"Yes",
        @"No": @"No",
        @"Error": @"Error",
        @"Warning": @"Warning",
        @"Done": @"Done",
        @"Play": @"Play",
        @"Settings": @"Settings"
    };
    
    [criticalStrings enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [self registerFallbackString:value forKey:key];
    }];
    
    _hasLoadedBaseFallbacks = YES;
}

#pragma mark - Публичные методы

+ (NSString *)stringForKey:(NSString *)key defaultValue:(NSString *)defaultValue {
    // Проверка параметров
    if (!key) return defaultValue ?: @"";
    
    // Проверка необходимости перезагрузки кэша
    if ([self shouldReloadCache]) {
        [self reloadLocalizations];
    }
    
    // 1. Проверка кэша
    NSString *cachedValue = [self cachedStringForKey:key];
    if (cachedValue) return cachedValue;
    
    @try {
        // 2. Попытка получить строку из основного бандла для текущего языка
        NSString *value = NSLocalizedString(key, nil);
        if (value && ![value isEqualToString:key]) {
            [self cacheString:value forKey:key];
            return value;
        }
        
        // 3. Попытка получить строку из резервного словаря
        NSString *fallbackValue = [self fallbackStringForKey:key];
        if (fallbackValue) {
            [self cacheString:fallbackValue forKey:key];
            return fallbackValue;
        }
        
        // 4. Попытка получить строку из английской локализации
        NSString *englishValue = [self englishStringForKey:key];
        if (englishValue && ![englishValue isEqualToString:key]) {
            [self cacheString:englishValue forKey:key];
            return englishValue;
        }
        
        // 5. Попытка получить строку из UIKit
        NSString *uikitValue = [self uikitStringForKey:key];
        if (uikitValue && ![uikitValue isEqualToString:key]) {
            [self cacheString:uikitValue forKey:key];
            return uikitValue;
        }
        
        // 6. Регистрируем отсутствующий ключ для будущего экспорта
        [self registerMissingKey:key];
        
        // 7. Возвращаем значение по умолчанию или сам ключ
        return defaultValue ?: key;
    } @catch (NSException *exception) {
        NSLog(@"[PLLocalization] Exception when localizing %@: %@", key, exception);
        return defaultValue ?: key;
    }
}

+ (NSString *)localizeKey:(NSString *)key comment:(NSString *)comment {
    // Обертка для совместимости с текущим кодом
    return [self stringForKey:key defaultValue:comment];
}

+ (void)reloadLocalizations {
    @synchronized(_stringCache) {
        [_stringCache removeAllObjects];
    }
    
    _currentLanguage = nil;
    _lastCacheUpdateTime = [NSDate date];
    
    if (PL_LOCALIZATION_DEBUG) {
        NSLog(@"[PLLocalization] Cache reloaded at %@", _lastCacheUpdateTime);
    }
}

+ (BOOL)validateAndFixLocalizationFile:(NSString *)path {
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSLog(@"[PLLocalization] File not found: %@", path);
        return NO;
    }
    
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:path 
                                                 encoding:NSUTF8StringEncoding 
                                                    error:&error];
    
    if (error) {
        NSLog(@"[PLLocalization] Error reading file: %@", error);
        return NO;
    }
    
    // Проверка базового синтаксиса
    BOOL hasValidSyntax = YES;
    BOOL needsFixing = NO;
    
    NSMutableString *fixedContent = [NSMutableString string];
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    
    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        // Пропускаем пустые строки и комментарии
        if ([trimmedLine length] == 0 || [trimmedLine hasPrefix:@"/*"] || [trimmedLine hasPrefix:@"*"] || [trimmedLine hasPrefix:@"*/"]) {
            [fixedContent appendFormat:@"%@\n", line];
            continue;
        }
        
        if ([trimmedLine hasPrefix:@"//"]) {
            [fixedContent appendFormat:@"%@\n", line];
            continue;
        }
        
        // Проверка наличия открывающей и закрывающей кавычки
        NSUInteger openQuotes = 0;
        NSUInteger closeQuotes = 0;
        BOOL inString = NO;
        BOOL isEscaped = NO;
        
        for (NSUInteger i = 0; i < [trimmedLine length]; i++) {
            unichar c = [trimmedLine characterAtIndex:i];
            
            if (c == '\\' && !isEscaped) {
                isEscaped = YES;
            } else if (c == '"' && !isEscaped) {
                if (!inString) {
                    inString = YES;
                    openQuotes++;
                } else {
                    inString = NO;
                    closeQuotes++;
                }
            } else {
                isEscaped = NO;
            }
        }
        
        // Проверка наличия точки с запятой в конце
        BOOL hasSemicolon = [trimmedLine hasSuffix:@";"];
        
        if (openQuotes != 2 || closeQuotes != 2 || !hasSemicolon) {
            hasValidSyntax = NO;
            needsFixing = YES;
            
            // Попытка исправить простые проблемы
            if (openQuotes == 2 && closeQuotes == 2 && !hasSemicolon) {
                // Добавляем точку с запятой
                [fixedContent appendFormat:@"%@;\n", trimmedLine];
            } else {
                // Неисправимая ошибка, просто комментируем строку
                [fixedContent appendFormat:@"// ERROR: %@\n", line];
            }
        } else {
            [fixedContent appendFormat:@"%@\n", line];
        }
    }
    
    // Если требуются исправления, записываем исправленный файл
    if (needsFixing) {
        error = nil;
        BOOL success = [fixedContent writeToFile:path 
                                      atomically:YES 
                                        encoding:NSUTF8StringEncoding 
                                           error:&error];
        
        if (!success) {
            NSLog(@"[PLLocalization] Error writing fixed file: %@", error);
            return NO;
        }
        
        NSLog(@"[PLLocalization] Fixed localization file: %@", path);
    }
    
    return hasValidSyntax || needsFixing;
}

+ (NSArray<NSString *> *)availableLanguages {
    NSArray *localizations = [NSBundle mainBundle].localizations;
    
    // Фильтруем только локализации с файлами Localizable.strings
    NSMutableArray *availableLanguages = [NSMutableArray array];
    
    for (NSString *locale in localizations) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"Localizable" 
                                                         ofType:@"strings" 
                                                    inDirectory:nil 
                                                forLocalization:locale];
        
        if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
            [availableLanguages addObject:locale];
        }
    }
    
    return [availableLanguages copy];
}

+ (NSString *)currentLanguage {
    // Кэшируем текущий язык
    if (!_currentLanguage) {
        NSArray *preferredLanguages = [NSLocale preferredLanguages];
        if ([preferredLanguages count] > 0) {
            _currentLanguage = preferredLanguages[0];
        } else {
            _currentLanguage = @"en";
        }
    }
    
    return _currentLanguage;
}

+ (void)registerFallbackString:(NSString *)value forKey:(NSString *)key {
    if (!key || !value) return;
    
    @synchronized(_fallbackStrings) {
        _fallbackStrings[key] = value;
    }
}

+ (NSString *)exportMissingKeysForLanguage:(NSString *)language {
    if ([_missingKeys count] == 0) {
        NSLog(@"[PLLocalization] No missing keys to export");
        return nil;
    }
    
    NSMutableString *content = [NSMutableString string];
    [content appendString:@"/*\n  Exported missing localization keys\n*/\n\n"];
    
    [_missingKeys enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *count, BOOL *stop) {
        [content appendFormat:@"\"%@\" = \"\";\n", key];
    }];
    
    NSString *documentsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *exportPath = [documentsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"missing_keys_%@.strings", language]];
    
    NSError *error = nil;
    BOOL success = [content writeToFile:exportPath 
                             atomically:YES 
                               encoding:NSUTF8StringEncoding 
                                  error:&error];
    
    if (!success) {
        NSLog(@"[PLLocalization] Error exporting missing keys: %@", error);
        return nil;
    }
    
    return exportPath;
}

+ (NSString *)stringWithFormat:(NSString *)format, ... {
    if (!format) return @"";
    
    va_list args;
    va_start(args, format);
    
    NSString *result = [[NSString alloc] initWithFormat:format arguments:args];
    
    va_end(args);
    return result;
}

#pragma mark - Вспомогательные методы

+ (BOOL)shouldReloadCache {
    // Проверка необходимости обновления кэша
    NSTimeInterval timeSinceLastUpdate = -[_lastCacheUpdateTime timeIntervalSinceNow];
    return timeSinceLastUpdate > PL_LOCALIZATION_CACHE_EXPIRATION;
}

+ (NSString *)cachedStringForKey:(NSString *)key {
    @synchronized(_stringCache) {
        return _stringCache[key];
    }
}

+ (void)cacheString:(NSString *)string forKey:(NSString *)key {
    @synchronized(_stringCache) {
        _stringCache[key] = string;
    }
}

+ (NSString *)fallbackStringForKey:(NSString *)key {
    @synchronized(_fallbackStrings) {
        return _fallbackStrings[key];
    }
}

+ (NSString *)englishStringForKey:(NSString *)key {
    NSString* path = [NSBundle.mainBundle pathForResource:@"en" ofType:@"lproj"];
    if (!path) return nil;
    
    NSBundle* englishBundle = [NSBundle bundleWithPath:path];
    if (!englishBundle) return nil;
    
    NSString *value = [englishBundle localizedStringForKey:key value:nil table:nil];
    return ([value isEqualToString:key]) ? nil : value;
}

+ (NSString *)uikitStringForKey:(NSString *)key {
    NSString *value = [[NSBundle bundleWithIdentifier:@"com.apple.UIKit"] localizedStringForKey:key value:nil table:nil];
    return ([value isEqualToString:key]) ? nil : value;
}

+ (void)registerMissingKey:(NSString *)key {
    @synchronized(_missingKeys) {
        NSNumber *count = _missingKeys[key];
        if (count) {
            _missingKeys[key] = @([count intValue] + 1);
        } else {
            _missingKeys[key] = @1;
        }
    }
    
    if (PL_LOCALIZATION_DEBUG) {
        NSLog(@"[PLLocalization] Missing key: %@", key);
    }
}

@end 