// PLLocalization.h
#ifndef PLLocalization_h
#define PLLocalization_h

#import <Foundation/Foundation.h>

/**
 * Современный менеджер локализации для PojavLauncher.
 * Разработан для обеспечения надежного доступа к строкам локализации
 * с защитой от ошибок и кэшированием для производительности.
 */
@interface PLLocalization : NSObject

/**
 * Получить локализованную строку.
 * @param key Ключ локализации
 * @param defaultValue Значение по умолчанию, если строка не найдена
 * @return Локализованную строку или defaultValue
 */
+ (NSString *)stringForKey:(NSString *)key defaultValue:(NSString *)defaultValue;

/**
 * Метод-обертка для поддержания обратной совместимости с текущим кодом
 * @param key Ключ локализации
 * @param comment Комментарий (используется как fallback)
 * @return Локализованную строку
 */
+ (NSString *)localizeKey:(NSString *)key comment:(NSString *)comment;

/**
 * Принудительно перезагрузить все кэши локализаций
 */
+ (void)reloadLocalizations;

/**
 * Проверить и исправить файл локализации
 * @param path Путь к файлу локализации
 * @return YES если файл валиден или был исправлен, NO если не удалось исправить
 */
+ (BOOL)validateAndFixLocalizationFile:(NSString *)path;

/**
 * Получить доступные языки
 * @return Массив доступных языковых кодов
 */
+ (NSArray<NSString *> *)availableLanguages;

/**
 * Получить текущий язык
 * @return Код текущего языка
 */
+ (NSString *)currentLanguage;

/**
 * Добавить резервную локализованную строку
 * @param value Значение строки
 * @param key Ключ строки
 */
+ (void)registerFallbackString:(NSString *)value forKey:(NSString *)key;

/**
 * Экспортировать отсутствующие ключи для перевода
 * @param language Код языка
 * @return Путь к созданному файлу с ключами или nil при ошибке
 */
+ (NSString *)exportMissingKeysForLanguage:(NSString *)language;

/**
 * Безопасный метод форматирования строк
 */
+ (NSString *)stringWithFormat:(NSString *)format, ...;

@end

// Макрос для упрощенного доступа к локализованным строкам
#define PLLocalizedString(key, comment) [PLLocalization stringForKey:(key) defaultValue:(comment)]

#endif /* PLLocalization_h */ 