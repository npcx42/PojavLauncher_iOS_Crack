// PLLocalizationUtils.h
#ifndef PLLocalizationUtils_h
#define PLLocalizationUtils_h

#import <Foundation/Foundation.h>

/**
 * Утилиты для работы с локализацией в PojavLauncher
 * Включает инструменты для валидации, исправления и конвертации файлов локализации
 */
@interface PLLocalizationUtils : NSObject

/**
 * Проверить файл локализации на наличие ошибок
 * @param path Путь к файлу локализации
 * @return Словарь с описанием ошибок или nil если ошибок нет
 */
+ (NSDictionary *)validateLocalizationFile:(NSString *)path;

/**
 * Исправить распространенные синтаксические ошибки в файле локализации
 * @param path Путь к файлу локализации
 * @param backupPath Путь для резервной копии (nil чтобы не создавать)
 * @return YES при успешном исправлении
 */
+ (BOOL)fixLocalizationFile:(NSString *)path backupPath:(NSString *)backupPath;

/**
 * Добавить ключ в файл локализации (если он отсутствует)
 * @param key Ключ локализации
 * @param value Значение (перевод)
 * @param path Путь к файлу локализации
 * @return YES при успешной операции
 */
+ (BOOL)addLocalizationKey:(NSString *)key value:(NSString *)value toFile:(NSString *)path;

/**
 * Получить словарь из всех локализованных строк в файле
 * @param path Путь к файлу локализации
 * @return Словарь ключ-значение или nil при ошибке
 */
+ (NSDictionary *)dictionaryFromLocalizationFile:(NSString *)path;

/**
 * Конвертировать словарь в формат файла локализации
 * @param dictionary Словарь с локализованными строками
 * @param path Путь для сохранения файла
 * @return YES при успешной операции
 */
+ (BOOL)saveDictionary:(NSDictionary *)dictionary toLocalizationFile:(NSString *)path;

/**
 * Экспортировать отсутствующие в переводе ключи по сравнению с исходным
 * @param sourcePath Путь к исходному файлу локализации (обычно английский)
 * @param targetPath Путь к целевому файлу локализации (перевод)
 * @param outputPath Путь для сохранения выходного файла с отсутствующими ключами
 * @return YES при успешной операции
 */
+ (BOOL)exportMissingKeys:(NSString *)sourcePath targetPath:(NSString *)targetPath outputPath:(NSString *)outputPath;

/**
 * Получить список языков с доступными локализациями
 * @return Массив кодов языков
 */
+ (NSArray<NSString *> *)availableLanguages;

/**
 * Проверить и исправить все файлы локализации в приложении
 * @return Словарь с результатами проверки для каждого языка
 */
+ (NSDictionary *)validateAndFixAllLocalizations;

@end

#endif /* PLLocalizationUtils_h */ 