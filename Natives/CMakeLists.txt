cmake_minimum_required(VERSION 3.6)
project(PojavLauncher)

configure_file(${CMAKE_CURRENT_LIST_DIR}/config.h.in ${CMAKE_CURRENT_LIST_DIR}/config.h)

# Using our build system, cmake doesn't respect -miphoneos-version-min=14.0
# and instead overrides it with the macOS SDK version when compiled
# in Xcode on a Mac.
set(CMAKE_OSX_DEPLOYMENT_TARGET 14.0)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -target arm64-apple-ios -mcpu=apple-a8 -fcommon -fobjc-arc -ObjC -F'${CMAKE_OSX_SYSROOT}/System/Cryptexes/OS/System/Library/Frameworks'")
set(CMAKE_C_FLAGS_DEBUG "-funwind-tables -g")

if("${CMAKE_HOST_SYSTEM_NAME}" MATCHES "Linux|^GNU$|Android")
set(GLOBAL_LDFLAGS "-isysroot ${CMAKE_OSX_SYSROOT} -Wl,-syslibroot,${CMAKE_OSX_SYSROOT} -fuse-ld=lld")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${GLOBAL_LDFLAGS}")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} ${GLOBAL_LDFLAGS}")
endif()

include_directories(
  "."
  "external/AFNetworking/AFNetworking"
  "external/AFNetworking/UIKit+AFNetworking"
  "external/DBNumberedSlider/Classes"
  "external/NRFileManager"
  "external/UnzipKit"
  "external/fishhook"
  "external/lzma"
  "external/mesa"
  "external/AltKit"
  "external/Apple"
  "external/ballpa1n"
  "external/ballpa1n/wrapped"
)

# For cacio support library
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -rpath @loader_path -rpath @executable_path/java_runtimes/java-8-openjdk/lib -rpath /usr/lib/jvm/java-8-openjdk/lib")

# EXT: stub library, delete after compile awt_xawt
add_library(awt_headless SHARED
  awt_xawt/empty.m
)
target_link_libraries(awt_headless)

# EXT: cacio support library
add_library(awt_xawt SHARED
  awt_xawt/xawt_fake.m
)
target_link_libraries(awt_xawt
  "-L'${CMAKE_CURRENT_LIST_DIR}/build'"
  awt_headless
)

set(CMAKE_FRAMEWORK_PATH "${CMAKE_CURRENT_LIST_DIR}/resources/Frameworks")

set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -rpath @executable_path/Frameworks -rpath @loader_path/Frameworks")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -rpath @executable_path/Frameworks -rpath @loader_path/Frameworks")

# ANGLE wrapper for 1.17+
add_library(tinygl4angle SHARED
  external/gl4es/string_utils.c
  external/gl4es/tinygl4angle.c
)
target_link_libraries(tinygl4angle
  "${GLOBAL_LDFLAGS}"
  "-F'${CMAKE_CURRENT_LIST_DIR}/resources/Frameworks'"
  "-framework libEGL"
  "-framework libGLESv2"
)

# AFNetworking
add_library(AFNetworking SHARED
  external/AFNetworking/AFNetworking/AFSecurityPolicy.m
  external/AFNetworking/AFNetworking/AFHTTPSessionManager.m
  external/AFNetworking/AFNetworking/AFURLRequestSerialization.m
  external/AFNetworking/AFNetworking/AFURLSessionManager.m
  external/AFNetworking/AFNetworking/AFNetworkReachabilityManager.m
  external/AFNetworking/AFNetworking/AFURLResponseSerialization.m
  external/AFNetworking/UIKit+AFNetworking/AFNetworkActivityIndicatorManager.m
  external/AFNetworking/UIKit+AFNetworking/AFAutoPurgingImageCache.m
  external/AFNetworking/UIKit+AFNetworking/AFImageDownloader.m
  external/AFNetworking/UIKit+AFNetworking/UIButton+AFNetworking.m
  external/AFNetworking/UIKit+AFNetworking/UIImageView+AFNetworking.m
)
target_link_libraries(AFNetworking
  "-framework CoreGraphics"
  "-framework CoreServices"
  "-framework Security"
  "-framework SystemConfiguration"
  "-framework UIKit"
)

# MinecraftAccount JNI
add_library(PojavAccountJNI SHARED
  authenticator/MinecraftAccountJNI.m
)
target_link_libraries(PojavAccountJNI)

# PojavLauncher
add_executable(PojavLauncher
  dyld_bypass_validation.m
  dyld_patch_platform.m
  main.m
  main_hook.m
  JavaLauncher.m
  external/fishhook/fishhook.c
  UIKit+hook.m

  authenticator/BaseAuthenticator.m
  authenticator/LocalAuthenticator.m
  authenticator/MicrosoftAuthenticator.m
  authenticator/ElyByAuthenticator.m

  ctxbridges/gl_bridge.m
  ctxbridges/osm_bridge.m
 
  customcontrols/ControlButton.m
  customcontrols/ControlDrawer.m
  customcontrols/ControlJoystick.m
  customcontrols/ControlLayout.m
  customcontrols/ControlSubButton.m
  customcontrols/CustomControlsUtils.m
  customcontrols/NSPredicateUtilitiesExternal.m

  external/DBNumberedSlider/Classes/DBNumberedSlider.m
  external/NRFileManager/NSFileManager+NRFileManager.m
  external/ballpa1n/HostManager.c
  external/ballpa1n/wrapped/HostManagerBridge.m

  installer/FabricInstallViewController.m
  installer/ForgeInstallViewController.m
  installer/ModpackInstallViewController.m
  installer/FabricUtils.m
  installer/modpack/ModpackUtils.m
  installer/modpack/ModpackAPI.m
  installer/modpack/CurseForgeAPI.m
  installer/modpack/ModrinthAPI.m

  input/ControllerInput.m
  input/GyroInput.m
  input/KeyboardInput.m

  AccountListViewController.m
  AppDelegate.m
  CustomControlsViewController.m
  CustomControlsViewController+UndoManager.m
  DownloadProgressViewController.m
  FileListViewController.m
  GameSurfaceView.m
  JavaGUIViewController.m
  LauncherMenuViewController.m
  LauncherNavigationController.m
  LauncherNewsViewController.m
  LauncherPreferences.m
  LauncherPreferencesViewController.m
  LauncherPrefContCfgViewController.m
  LauncherPrefGameDirViewController.m
  LauncherPrefManageJREViewController.m
  LauncherProfileEditorViewController.m
  LauncherProfilesViewController.m
  LauncherSplitViewController.m
  MinecraftResourceDownloadTask.m
  MinecraftResourceUtils.m
  PickTextField.m
  PLLogOutputView.m
  PLPickerView.m
  PLPreferences.m
  PLPrefTableViewController.m
  PLProfiles.m
  SceneDelegate.m
  SceneExternalDelegate.m
  SurfaceViewController.m
  SurfaceViewController+ExternalDisplay.m
  SurfaceViewController+LogView.m
  SurfaceViewController+Navigation.m
  TrackedTextField.m
  egl_bridge.m
  input_bridge_v3.m
  ios_uikit_bridge.m
  utils.m
)

if("${CMAKE_HOST_SYSTEM_NAME}" MATCHES "Linux|^GNU$|Android")
target_sources(PojavLauncher PUBLIC non_darwin_utils.m)
endif()

target_link_libraries(PojavLauncher
  PUBLIC AFNetworking
  lzma
  "-F'${CMAKE_CURRENT_LIST_DIR}/build'"
  "-F'${CMAKE_CURRENT_LIST_DIR}/resources/Frameworks'"
  "-framework AltKit"
  "-framework AuthenticationServices"
  "-framework AVFoundation"
  "-framework CAltKit"
  "-framework CoreFoundation"
  "-framework CoreGraphics"
  "-framework CoreImage"
  "-framework CoreMotion"
  "-framework GameController"
  "-framework IOKit"
  "-framework QuartzCore"
  "-framework UIKit"
  "-framework UniformTypeIdentifiers"
  "-framework UnzipKit"
  "-framework WebKit"
  "-weak_framework SafariServices"
)
set_target_properties(PojavLauncher PROPERTIES
  MACOSX_BUNDLE TRUE
  MACOSX_FRAMEWORK_IDENTIFIER org.cmake.ExecutableTarget
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_LIST_DIR}/Info.plist")

# Копирование файлов локализации в бандл
add_custom_command(TARGET PojavLauncher POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E echo "Copying localization files to app bundle"
  
  # Копирование всех .lproj директорий
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/af.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../af.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/ar.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../ar.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/az.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../az.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/ba.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../ba.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/bn.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../bn.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/bn-IN.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../bn-IN.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/ca.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../ca.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/cs.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../cs.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/da.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../da.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/de.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../de.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/el.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../el.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/en.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../en.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/en-GB.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../en-GB.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/en-PT.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../en-PT.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/en-UD.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../en-UD.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/es.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../es.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/et.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../et.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/fa.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../fa.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/fi.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../fi.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/fil.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../fil.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/fr.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../fr.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/he.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../he.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/hi.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../hi.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/hu.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../hu.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/id.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../id.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/it.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../it.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/ja.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../ja.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/kk.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../kk.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/ko.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../ko.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/la.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../la.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/lol.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../lol.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/lt.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../lt.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/ms.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../ms.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/nl.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../nl.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/no.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../no.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/pl.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../pl.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/pr.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../pr.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/pt.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../pt.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/pt-BR.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../pt-BR.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/ru.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../ru.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/ro.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../ro.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/sk.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../sk.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/sr.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../sr.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/sr-Latn.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../sr-Latn.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/sv.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../sv.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/th.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../th.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/tr.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../tr.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/tt.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../tt.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/uk.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../uk.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/vi.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../vi.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/zh-Hans.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../zh-Hans.lproj"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_LIST_DIR}/resources/zh-Hant.lproj" "$<TARGET_FILE_DIR:PojavLauncher>/../zh-Hant.lproj"
  
  COMMENT "Copying localization files to app bundle"
  VERBATIM
)
