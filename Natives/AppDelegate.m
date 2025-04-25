#import "AppDelegate.h"
#import "SceneDelegate.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

// SurfaceViewController
extern dispatch_group_t fatalExitGroup;

@implementation AppDelegate

#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    if (fatalExitGroup != nil) {
        dispatch_group_leave(fatalExitGroup);
        fatalExitGroup = nil;
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Проверяем корректность файлов локализации
    validateAllLocalizations();
    
    // Инициализируем локализацию в начале запуска приложения
    NSString *languageCode = [[NSLocale preferredLanguages] firstObject];
    NSString *resourcePath = [NSBundle.mainBundle pathForResource:languageCode ofType:@"lproj"];
    
    // Если не найден язык пользователя, используем английский по умолчанию
    if (!resourcePath || !validateLocalizationFile(languageCode)) {
        // Если основной язык не прошел валидацию, пробуем английский
        resourcePath = [NSBundle.mainBundle pathForResource:@"en" ofType:@"lproj"];
    }
    
    // Загружаем бандл с локализацией и устанавливаем его
    if (resourcePath) {
        NSBundle *localizationBundle = [NSBundle bundleWithPath:resourcePath];
        [[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithObject:[localizationBundle preferredLocalizations].firstObject] forKey:@"AppleLanguages"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    return YES;
}

@end
