#import "PLLocalizationUtils.h"
#import "PLLocalization.h"

@implementation PLLocalizationUtils

#pragma mark - Валидация и исправление файлов

+ (NSDictionary *)validateLocalizationFile:(NSString *)path {
    if (!path || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return @{@"error": @"Файл не существует"};
    }
    
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:path 
                                                 encoding:NSUTF8StringEncoding 
                                                    error:&error];
    
    if (error) {
        return @{@"error": [NSString stringWithFormat:@"Не удалось прочитать файл: %@", error.localizedDescription]};
    }
    
    // Проверка на наличие синтаксических ошибок
    NSMutableArray *errors = [NSMutableArray array];
    NSUInteger lineNumber = 0;
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    
    for (NSString *line in lines) {
        lineNumber++;
        
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        // Пропускаем пустые строки и комментарии
        if ([trimmedLine length] == 0 || [trimmedLine hasPrefix:@"/*"] || 
            [trimmedLine hasPrefix:@"*"] || [trimmedLine hasPrefix:@"*/"] || 
            [trimmedLine hasPrefix:@"//"]) {
            continue;
        }
        
        // Проверка синтаксиса строки локализации
        NSArray *issues = [self validateLocalizationLine:trimmedLine lineNumber:lineNumber];
        
        if ([issues count] > 0) {
            [errors addObjectsFromArray:issues];
        }
    }
    
    if ([errors count] > 0) {
        return @{@"errors": errors};
    }
    
    return nil;
}

+ (NSArray *)validateLocalizationLine:(NSString *)line lineNumber:(NSUInteger)lineNumber {
    NSMutableArray *issues = [NSMutableArray array];
    
    // Подсчёт кавычек
    NSUInteger openQuotes = 0;
    NSUInteger closeQuotes = 0;
    BOOL inString = NO;
    BOOL isEscaped = NO;
    
    for (NSUInteger i = 0; i < [line length]; i++) {
        unichar c = [line characterAtIndex:i];
        
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
    
    // Проверка формата "ключ" = "значение";
    if (openQuotes != 2 || closeQuotes != 2) {
        [issues addObject:@{
            @"line": @(lineNumber),
            @"text": line,
            @"error": @"Неправильное количество кавычек",
            @"details": [NSString stringWithFormat:@"Открывающих: %lu, закрывающих: %lu", (unsigned long)openQuotes, (unsigned long)closeQuotes]
        }];
    }
    
    // Проверка наличия оператора присваивания
    if ([line rangeOfString:@"="].location == NSNotFound) {
        [issues addObject:@{
            @"line": @(lineNumber),
            @"text": line,
            @"error": @"Отсутствует оператор присваивания '='",
        }];
    }
    
    // Проверка наличия точки с запятой в конце
    if (![line hasSuffix:@";"]) {
        [issues addObject:@{
            @"line": @(lineNumber),
            @"text": line,
            @"error": @"Отсутствует точка с запятой в конце строки",
        }];
    }
    
    return issues;
}

+ (BOOL)fixLocalizationFile:(NSString *)path backupPath:(NSString *)backupPath {
    if (!path || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return NO;
    }
    
    // Создание резервной копии, если указан путь
    if (backupPath) {
        NSError *copyError = nil;
        [[NSFileManager defaultManager] copyItemAtPath:path toPath:backupPath error:&copyError];
        
        if (copyError) {
            NSLog(@"[PLLocalizationUtils] Warning: Could not create backup: %@", copyError);
            // Продолжаем, даже если не удалось создать резервную копию
        }
    }
    
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:path 
                                                 encoding:NSUTF8StringEncoding 
                                                    error:&error];
    
    if (error) {
        NSLog(@"[PLLocalizationUtils] Error reading file: %@", error);
        return NO;
    }
    
    // Исправление ошибок
    NSMutableString *fixedContent = [NSMutableString string];
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    BOOL madeChanges = NO;
    
    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        // Пропускаем пустые строки и комментарии
        if ([trimmedLine length] == 0 || [trimmedLine hasPrefix:@"/*"] || 
            [trimmedLine hasPrefix:@"*"] || [trimmedLine hasPrefix:@"*/"] || 
            [trimmedLine hasPrefix:@"//"]) {
            [fixedContent appendFormat:@"%@\n", line];
            continue;
        }
        
        // Попытка исправить строку
        NSString *fixedLine = [self fixLocalizationLine:line];
        
        if (![fixedLine isEqualToString:line]) {
            madeChanges = YES;
        }
        
        [fixedContent appendFormat:@"%@\n", fixedLine];
    }
    
    // Сохраняем только если были сделаны изменения
    if (madeChanges) {
        error = nil;
        BOOL success = [fixedContent writeToFile:path 
                                      atomically:YES 
                                        encoding:NSUTF8StringEncoding 
                                           error:&error];
        
        if (!success) {
            NSLog(@"[PLLocalizationUtils] Error writing fixed file: %@", error);
            return NO;
        }
        
        NSLog(@"[PLLocalizationUtils] Successfully fixed localization file: %@", path);
    } else {
        NSLog(@"[PLLocalizationUtils] No changes needed for file: %@", path);
    }
    
    return YES;
}

+ (NSString *)fixLocalizationLine:(NSString *)line {
    NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    // Если строка пустая или комментарий - не трогаем
    if ([trimmedLine length] == 0 || [trimmedLine hasPrefix:@"/*"] || 
        [trimmedLine hasPrefix:@"*"] || [trimmedLine hasPrefix:@"*/"] || 
        [trimmedLine hasPrefix:@"//"]) {
        return line;
    }
    
    // Подсчет и проверка кавычек
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
    
    // Если строка имеет серьезные проблемы с синтаксисом - комментируем её
    if ((openQuotes != 2 && closeQuotes != 2) || [trimmedLine rangeOfString:@"="].location == NSNotFound) {
        // Строка не подлежит автоматическому исправлению
        return [NSString stringWithFormat:@"// ERROR: %@", line];
    }
    
    // Добавление точки с запятой, если отсутствует
    if (![trimmedLine hasSuffix:@";"]) {
        return [NSString stringWithFormat:@"%@;", trimmedLine];
    }
    
    // Если никаких исправлений не требуется
    return line;
}

#pragma mark - Работа с локализационными файлами

+ (BOOL)addLocalizationKey:(NSString *)key value:(NSString *)value toFile:(NSString *)path {
    if (!key || !value || !path) {
        return NO;
    }
    
    // Загружаем существующие строки
    NSDictionary *existingDict = [self dictionaryFromLocalizationFile:path];
    NSMutableDictionary *newDict;
    
    if (existingDict) {
        newDict = [existingDict mutableCopy];
    } else {
        newDict = [NSMutableDictionary dictionary];
    }
    
    // Добавляем новую строку, если она отсутствует
    if (!newDict[key]) {
        newDict[key] = value;
        return [self saveDictionary:newDict toLocalizationFile:path];
    }
    
    // Ключ уже существует, ничего не делаем
    return YES;
}

+ (NSDictionary *)dictionaryFromLocalizationFile:(NSString *)path {
    if (!path || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return nil;
    }
    
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:path 
                                                 encoding:NSUTF8StringEncoding 
                                                    error:&error];
    
    if (error) {
        NSLog(@"[PLLocalizationUtils] Error reading file: %@", error);
        return nil;
    }
    
    // Разбор файла .strings
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    
    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        // Пропускаем пустые строки и комментарии
        if ([trimmedLine length] == 0 || [trimmedLine hasPrefix:@"/*"] || 
            [trimmedLine hasPrefix:@"*"] || [trimmedLine hasPrefix:@"*/"] || 
            [trimmedLine hasPrefix:@"//"]) {
            continue;
        }
        
        // Парсинг в формате "ключ" = "значение";
        NSArray *parts = [self parseLocalizationLine:trimmedLine];
        
        if (parts && [parts count] == 2) {
            NSString *key = parts[0];
            NSString *value = parts[1];
            
            if (key && value) {
                dict[key] = value;
            }
        }
    }
    
    return dict;
}

+ (NSArray *)parseLocalizationLine:(NSString *)line {
    // Регулярное выражение для извлечения ключа и значения
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\"(.+?)\"\\s*=\\s*\"(.+?)\"\\s*;"
                                                                           options:0
                                                                             error:&error];
    
    if (error) {
        NSLog(@"[PLLocalizationUtils] Regex error: %@", error);
        return nil;
    }
    
    NSTextCheckingResult *match = [regex firstMatchInString:line
                                                    options:0
                                                      range:NSMakeRange(0, [line length])];
    
    if (match && [match numberOfRanges] == 3) {
        NSString *key = [line substringWithRange:[match rangeAtIndex:1]];
        NSString *value = [line substringWithRange:[match rangeAtIndex:2]];
        
        return @[key, value];
    }
    
    return nil;
}

+ (BOOL)saveDictionary:(NSDictionary *)dictionary toLocalizationFile:(NSString *)path {
    if (!dictionary || !path) {
        return NO;
    }
    
    NSMutableString *content = [NSMutableString string];
    [content appendString:@"/*\n  Localizable.strings\n*/\n\n"];
    
    // Получаем отсортированные ключи для организованного вывода
    NSArray *sortedKeys = [[dictionary allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    for (NSString *key in sortedKeys) {
        NSString *value = dictionary[key];
        
        // Экранируем кавычки и обратные слеши в строках
        NSString *escapedKey = [self escapeString:key];
        NSString *escapedValue = [self escapeString:value];
        
        [content appendFormat:@"\"%@\" = \"%@\";\n", escapedKey, escapedValue];
    }
    
    NSError *error = nil;
    BOOL success = [content writeToFile:path 
                             atomically:YES 
                               encoding:NSUTF8StringEncoding 
                                  error:&error];
    
    if (!success) {
        NSLog(@"[PLLocalizationUtils] Error writing localization file: %@", error);
        return NO;
    }
    
    return YES;
}

+ (NSString *)escapeString:(NSString *)string {
    NSString *escaped = [string stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    return escaped;
}

+ (BOOL)exportMissingKeys:(NSString *)sourcePath targetPath:(NSString *)targetPath outputPath:(NSString *)outputPath {
    // Загружаем словари исходного и целевого языков
    NSDictionary *sourceDict = [self dictionaryFromLocalizationFile:sourcePath];
    NSDictionary *targetDict = [self dictionaryFromLocalizationFile:targetPath];
    
    if (!sourceDict) {
        NSLog(@"[PLLocalizationUtils] Could not load source dictionary from %@", sourcePath);
        return NO;
    }
    
    if (!targetDict) {
        NSLog(@"[PLLocalizationUtils] Could not load target dictionary from %@", targetPath);
        return NO;
    }
    
    // Находим отсутствующие ключи
    NSMutableDictionary *missingKeys = [NSMutableDictionary dictionary];
    
    for (NSString *key in sourceDict) {
        if (!targetDict[key]) {
            missingKeys[key] = sourceDict[key];
        }
    }
    
    if ([missingKeys count] == 0) {
        NSLog(@"[PLLocalizationUtils] No missing keys found");
        return YES; // Успешно, но нет отсутствующих ключей
    }
    
    // Сохраняем отсутствующие ключи в выходной файл
    return [self saveDictionary:missingKeys toLocalizationFile:outputPath];
}

#pragma mark - Общие методы

+ (NSArray<NSString *> *)availableLanguages {
    return [PLLocalization availableLanguages];
}

+ (NSDictionary *)validateAndFixAllLocalizations {
    NSArray *languages = [self availableLanguages];
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    
    for (NSString *language in languages) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"Localizable" 
                                                         ofType:@"strings" 
                                                    inDirectory:nil 
                                                forLocalization:language];
        
        if (path) {
            // Создаем резервную копию
            NSString *backupPath = [path stringByAppendingString:@".backup"];
            
            // Пытаемся исправить локализацию
            BOOL fixed = [self fixLocalizationFile:path backupPath:backupPath];
            
            // Проверяем результат после исправления
            NSDictionary *validationResult = [self validateLocalizationFile:path];
            
            if (validationResult) {
                results[language] = @{@"status": @"error", @"details": validationResult};
            } else {
                results[language] = @{@"status": @"ok", @"fixed": @(fixed)};
            }
        }
    }
    
    return results;
}

@end 