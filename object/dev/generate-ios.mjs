import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import xcode from 'xcode';

const root = fileURLToPath(new URL('../ios/', import.meta.url));
const projectFile = root + 'SafeOrbit.xcodeproj/project.pbxproj';
if (existsSync(projectFile) && !process.argv.includes('--force')) {
  throw new Error('Project already exists. Edit it in Xcode; use --force only to regenerate the initial skeleton.');
}
const objects = {};
const id = name => createHash('sha1').update('safeorbit:' + name).digest('hex').slice(0, 24).toUpperCase();
const ref = (name, comment = name) => ({ value: id(name), comment });
function add(isa, name, data) {
  objects[isa] ??= {};
  objects[isa][id(name)] = { isa, ...data };
  objects[isa][id(name) + '_comment'] = name;
  return id(name);
}
const sources = ['SafeOrbit/SafeOrbitApp.swift', 'SafeOrbit/ServerConfiguration.swift', 'SafeOrbit/OnboardingModels.swift', 'SafeOrbit/OnboardingAPI.swift', 'SafeOrbit/OnboardingStore.swift', 'SafeOrbit/OnboardingUI.swift', 'SafeOrbit/QRScanner.swift', 'SafeOrbit/LocationModels.swift', 'SafeOrbit/LocationUI.swift', 'SafeOrbit/SafeZoneSelectionMap.swift', 'SafeOrbit/CaregiverChrome.swift', 'SafeOrbit/WalkingNavigation.swift', 'SafeOrbit/RecordsDemoData.swift', 'SafeOrbit/RecordsUI.swift', 'SafeOrbit/AgentChatUI.swift', 'SafeOrbit/SpeechInput.swift'];
const tests = ['SafeOrbitTests/ServerConfigurationTests.swift', 'SafeOrbitTests/OnboardingTests.swift', 'SafeOrbitTests/LocationTests.swift', 'SafeOrbitTests/RecordsTests.swift'];
const resources = ['SafeOrbit/Assets.xcassets', 'SafeOrbit/Localizable.xcstrings', 'SafeOrbit/InfoPlist.xcstrings'];
const files = [...sources, ...tests, ...resources, 'SafeOrbit/SafeOrbit.entitlements', 'SafeOrbit/Info.plist', 'Config/Debug.xcconfig', 'Config/Release.xcconfig'];
for (const file of files) {
  add('PBXFileReference', file, { path: '"' + file + '"', sourceTree: '"<group>"',
    lastKnownFileType: file.endsWith('.xcassets') ? 'folder.assetcatalog' : file.endsWith('.swift') ? 'sourcecode.swift' : file.endsWith('.xcstrings') ? 'text.json.xcstrings' : file.endsWith('.entitlements') ? 'text.plist.entitlements' : file.endsWith('.plist') ? 'text.plist.xml' : 'text.xcconfig' });
}
for (const file of [...sources, ...tests]) {
  add('PBXBuildFile', file + ' in Sources', { fileRef: id(file), fileRef_comment: file });
}
for (const file of resources) add('PBXBuildFile', file + ' in Resources', { fileRef: id(file), fileRef_comment: file });
add('PBXFileReference', 'SafeOrbit.app', { path: 'SafeOrbit.app', sourceTree: 'BUILT_PRODUCTS_DIR', explicitFileType: 'wrapper.application', includeInIndex: 0 });
add('PBXFileReference', 'SafeOrbitTests.xctest', { path: 'SafeOrbitTests.xctest', sourceTree: 'BUILT_PRODUCTS_DIR', explicitFileType: 'wrapper.cfbundle', includeInIndex: 0 });
add('PBXGroup', 'Products', { children: [ref('SafeOrbit.app'), ref('SafeOrbitTests.xctest')], name: 'Products', sourceTree: '"<group>"' });
add('PBXGroup', 'Main', { children: [...files.map(f => ref(f)), ref('Products')], sourceTree: '"<group>"' });

for (const target of ['SafeOrbit', 'SafeOrbitTests']) {
  const isTest = target.endsWith('Tests');
  add('PBXSourcesBuildPhase', target + ' Sources', { buildActionMask: 2147483647,
    files: (isTest ? tests : sources).map(f => ref(f + ' in Sources')), runOnlyForDeploymentPostprocessing: 0 });
  add('PBXFrameworksBuildPhase', target + ' Frameworks', { buildActionMask: 2147483647,
    files: [], runOnlyForDeploymentPostprocessing: 0 });
  add('PBXResourcesBuildPhase', target + ' Resources', { buildActionMask: 2147483647, files: [], runOnlyForDeploymentPostprocessing: 0 });
  objects.PBXResourcesBuildPhase[id(target + ' Resources')].files = isTest ? [] : resources.map(f => ref(f + ' in Resources'));
  for (const config of ['Debug', 'Release']) {
    add('XCBuildConfiguration', target + ' ' + config, {
      baseConfigurationReference: id('Config/' + config + '.xcconfig'),
      baseConfigurationReference_comment: config + '.xcconfig', name: config,
      buildSettings: { PRODUCT_NAME: '"$(TARGET_NAME)"', PRODUCT_BUNDLE_IDENTIFIER: isTest ? 'org.safeorbit.demo.tests' : 'org.safeorbit.demo',
        SDKROOT: 'iphoneos', SUPPORTED_PLATFORMS: '"iphoneos iphonesimulator"', CODE_SIGN_STYLE: 'Automatic',
        SWIFT_VERSION: '5.0', IPHONEOS_DEPLOYMENT_TARGET: '17.0', TARGETED_DEVICE_FAMILY: '1',
        ENABLE_TESTABILITY: config === 'Debug' ? 'YES' : 'NO', SWIFT_OPTIMIZATION_LEVEL: config === 'Debug' ? '"-Onone"' : '"-O"',
        LD_RUNPATH_SEARCH_PATHS: '"$(inherited) @executable_path/Frameworks @loader_path/Frameworks"',
        ...(isTest ? { GENERATE_INFOPLIST_FILE: 'YES', TEST_HOST: '"$(BUILT_PRODUCTS_DIR)/SafeOrbit.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/SafeOrbit"', BUNDLE_LOADER: '"$(TEST_HOST)"' }
                   : { CODE_SIGN_ENTITLEMENTS: 'SafeOrbit/SafeOrbit.entitlements', INFOPLIST_FILE: 'SafeOrbit/Info.plist', GENERATE_INFOPLIST_FILE: 'NO', SWIFT_EMIT_LOC_STRINGS: 'YES' }),
      },
    });
  }
  add('XCConfigurationList', target + ' Configurations', { buildConfigurations: ['Debug', 'Release'].map(c => ref(target + ' ' + c)), defaultConfigurationIsVisible: 0, defaultConfigurationName: 'Release' });
  add('PBXNativeTarget', target, { buildConfigurationList: id(target + ' Configurations'),
    buildPhases: ['Sources','Frameworks','Resources'].map(phase => ref(target + ' ' + phase)), buildRules: [],
    dependencies: isTest ? [ref('AppDependency')] : [], name: target, productName: target,
    productReference: id(isTest ? 'SafeOrbitTests.xctest' : 'SafeOrbit.app'),
    productType: isTest ? '"com.apple.product-type.bundle.unit-test"' : '"com.apple.product-type.application"' });
}
add('PBXContainerItemProxy', 'AppProxy', { containerPortal: id('Project'), proxyType: 1, remoteGlobalIDString: id('SafeOrbit'), remoteInfo: 'SafeOrbit' });
add('PBXTargetDependency', 'AppDependency', { target: id('SafeOrbit'), targetProxy: id('AppProxy') });
for (const config of ['Debug','Release']) {
  add('XCBuildConfiguration', 'Project ' + config, { name: config, buildSettings: {
    CLANG_ENABLE_MODULES: 'YES', CLANG_ENABLE_OBJC_ARC: 'YES', GCC_C_LANGUAGE_STANDARD: 'gnu17',
    SWIFT_ACTIVE_COMPILATION_CONDITIONS: config === 'Debug' ? 'DEBUG' : '""',
    DEBUG_INFORMATION_FORMAT: config === 'Debug' ? 'dwarf' : '"dwarf-with-dsym"',
  } });
}
add('XCConfigurationList', 'Project Configurations', { buildConfigurations: ['Debug','Release'].map(c => ref('Project ' + c)), defaultConfigurationIsVisible: 0, defaultConfigurationName: 'Release' });
add('PBXProject', 'Project', { attributes: { LastUpgradeCheck: 2700, TargetAttributes: {
  [id('SafeOrbit')]: { CreatedOnToolsVersion: '27.0', SystemCapabilities: { 'com.apple.SignInWithApple': { enabled: 1 } } },
  [id('SafeOrbitTests')]: { CreatedOnToolsVersion: '27.0', TestTargetID: id('SafeOrbit') },
} }, buildConfigurationList: id('Project Configurations'), compatibilityVersion: '"Xcode 14.0"', developmentRegion: 'en',
  hasScannedForEncodings: 0, knownRegions: ['en', 'Base'], mainGroup: id('Main'), productRefGroup: id('Products'),
  projectDirPath: '""', projectRoot: '""', targets: [ref('SafeOrbit'),ref('SafeOrbitTests')] });
const project = xcode.project(projectFile);
project.hash = { project: { archiveVersion: 1, classes: {}, objectVersion: 56, objects, rootObject: id('Project'), rootObject_comment: 'Project object' } };
mkdirSync(root + 'SafeOrbit.xcodeproj/xcshareddata/xcschemes', { recursive: true });
writeFileSync(projectFile, project.writeSync());
const buildable = (name, file) => `<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${id(name)}" BuildableName="${file}" BlueprintName="${name}" ReferencedContainer="container:SafeOrbit.xcodeproj"/>`;
writeFileSync(root + 'SafeOrbit.xcodeproj/xcshareddata/xcschemes/SafeOrbit.xcscheme', `<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">${buildable('SafeOrbit','SafeOrbit.app')}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>
<TestableReference skipped="NO">${buildable('SafeOrbitTests','SafeOrbitTests.xctest')}</TestableReference>
</Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">${buildable('SafeOrbit','SafeOrbit.app')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">${buildable('SafeOrbit','SafeOrbit.app')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>\n`);
console.log('Generated SafeOrbit.xcodeproj and shared scheme');
