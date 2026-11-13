#!/usr/bin/env python3
"""Generate the checked-in Xcode project without third-party generator dependencies."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parents[1]
def ident(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
objects = {}
def obj(name, value):
    key = ident(name); objects[key] = value; return key
def quote(s): return '"' + s.replace('"', '\\"') + '"'
def arr(values): return '(' + ', '.join(values) + ')'
def settings(values): return '{' + ' '.join(k + ' = ' + quote(str(v)) + ';' for k,v in values.items()) + '}'
app = ident('app'); widget = ident('widget'); watch = ident('watch'); uitests = ident('uitests')
configref = obj('sharedconfig', '{isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = "Configuration/Shared.xcconfig"; sourceTree = "<group>";}')
files=[configref]; appbuild=[]; widgetbuild=[]; watchbuild=[]; uitestbuild=[]; resources=[]
for folder in ['Pantry','PantryCore','PantryWidgets','PantryWatch','Shared','PantryUITests']:
    for p in sorted((root/folder).glob('*')):
        if p.suffix not in ['.swift','.js']: continue
        path = str(p.relative_to(root))
        ref = obj(path, '{isa = PBXFileReference; lastKnownFileType = '+ ('sourcecode.swift' if p.suffix=='.swift' else 'sourcecode.javascript') + '; path = '+quote(path)+'; sourceTree = "<group>";}')
        build = obj('build'+path, '{isa = PBXBuildFile; fileRef = '+ref+';}')
        files.append(ref)
        if folder=='Shared':
            appbuild.append(build)
            widgetbuild.append(obj('widgetbuild'+path, '{isa = PBXBuildFile; fileRef = '+ref+';}'))
        elif folder=='PantryUITests': uitestbuild.append(build)
        elif folder=='PantryWatch': watchbuild.append(build)
        elif folder=='PantryWidgets': widgetbuild.append(build)
        elif p.suffix=='.js': resources.append(build)
        else: appbuild.append(build)
plist = root/'Pantry'/'GoogleService-Info.plist'
if plist.exists():
    ref = obj('firebaseplist','{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "Pantry/GoogleService-Info.plist"; sourceTree = "<group>";}');files.append(ref)
    resources.append(obj('buildplist','{isa = PBXBuildFile; fileRef = '+ref+';}'))
appProduct=obj('appproduct','{isa = PBXFileReference; explicitFileType = wrapper.application; path = Pantry.app; sourceTree = BUILT_PRODUCTS_DIR;}')
widgetProduct=obj('widgetproduct','{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; path = PantryWidgets.appex; sourceTree = BUILT_PRODUCTS_DIR;}')
watchProduct=obj('watchproduct','{isa = PBXFileReference; explicitFileType = wrapper.application; path = PantryWatch.app; sourceTree = BUILT_PRODUCTS_DIR;}')
uitestProduct=obj('uitestproduct','{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = PantryUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;}')
products=obj('products','{isa = PBXGroup; children = '+arr([appProduct,widgetProduct,watchProduct,uitestProduct])+'; name = Products; sourceTree = "<group>";}')
group=obj('group','{isa = PBXGroup; children = '+arr(files+[products])+'; sourceTree = "<group>";}')
firebase=obj('firebase','{isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/firebase/firebase-ios-sdk.git"; requirement = {kind = upToNextMajorVersion; minimumVersion = 11.0.0;};}')
google=obj('google','{isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/google/GoogleSignIn-iOS.git"; requirement = {kind = upToNextMajorVersion; minimumVersion = 8.0.0;};}')
packages=[]; frameworkbuild=[]
for product, package in [('FirebaseCore',firebase),('FirebaseAuth',firebase),('FirebaseFirestore',firebase),('GoogleSignIn',google)]:
    ref=obj(product,'{isa = XCSwiftPackageProductDependency; package = '+package+'; productName = '+product+';}');packages.append(ref)
    frameworkbuild.append(obj('framework'+product,'{isa = PBXBuildFile; productRef = '+ref+';}'))
def phase(name,isa,builds,extra=''):
    return obj(name,'{isa = '+isa+'; buildActionMask = 2147483647; files = '+arr(builds)+'; runOnlyForDeploymentPostprocessing = 0; '+extra+'}')
asource=phase('appsources','PBXSourcesBuildPhase',appbuild);wsource=phase('widgetsources','PBXSourcesBuildPhase',widgetbuild)
aresource=phase('appresources','PBXResourcesBuildPhase',resources);wresource=phase('widgetresources','PBXResourcesBuildPhase',[])
aframework=phase('appframeworks','PBXFrameworksBuildPhase',frameworkbuild);wframework=phase('widgetframeworks','PBXFrameworksBuildPhase',[])
embedbuild=obj('embedbuild','{isa = PBXBuildFile; fileRef = '+widgetProduct+'; settings = {ATTRIBUTES = (RemoveHeadersOnCopy,);};}')
embed=phase('embed','PBXCopyFilesBuildPhase',[embedbuild],'dstPath = ""; dstSubfolderSpec = 13; name = "Embed App Extensions";')
proxy=obj('proxy','{isa = PBXContainerItemProxy; containerPortal = '+ident('project')+'; proxyType = 1; remoteGlobalIDString = '+widget+'; remoteInfo = PantryWidgets;}')
dep=obj('dependency','{isa = PBXTargetDependency; target = '+widget+'; targetProxy = '+proxy+';}')
watchsource=phase('watchsources','PBXSourcesBuildPhase',watchbuild)
watchresource=phase('watchresources','PBXResourcesBuildPhase',[])
watchframework=phase('watchframeworks','PBXFrameworksBuildPhase',[])
watchembedbuild=obj('watchembedbuild','{isa = PBXBuildFile; fileRef = '+watchProduct+'; settings = {ATTRIBUTES = (RemoveHeadersOnCopy,);};}')
watchembed=phase('watchembed','PBXCopyFilesBuildPhase',[watchembedbuild],'dstPath = "$(CONTENTS_FOLDER_PATH)/Watch"; dstSubfolderSpec = 16; name = "Embed Watch Content";')
watchproxy=obj('watchproxy','{isa = PBXContainerItemProxy; containerPortal = '+ident('project')+'; proxyType = 1; remoteGlobalIDString = '+watch+'; remoteInfo = PantryWatch;}')
watchdep=obj('watchdependency','{isa = PBXTargetDependency; target = '+watch+'; targetProxy = '+watchproxy+';}')
uitestsource=phase('uitestsources','PBXSourcesBuildPhase',uitestbuild)
uitestframework=phase('uitestframeworks','PBXFrameworksBuildPhase',[])
uitestproxy=obj('uitestproxy','{isa = PBXContainerItemProxy; containerPortal = '+ident('project')+'; proxyType = 1; remoteGlobalIDString = '+app+'; remoteInfo = Pantry;}')
uitestdep=obj('uitestdependency','{isa = PBXTargetDependency; target = '+app+'; targetProxy = '+uitestproxy+';}')
base={'SWIFT_VERSION':'5.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SDKROOT':'iphoneos','TARGETED_DEVICE_FAMILY':'1,2','CODE_SIGN_STYLE':'Automatic','CLANG_ENABLE_MODULES':'YES','SWIFT_STRICT_CONCURRENCY':'minimal','MARKETING_VERSION':'0.1.0','CURRENT_PROJECT_VERSION':'1'}
def configlist(name,extra):
    configs=[]
    for mode in ['Debug','Release']:
        values=base | extra | {'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O', 'ONLY_ACTIVE_ARCH':'YES' if mode=='Debug' else 'NO'}
        configs.append(obj(name+mode,'{isa = XCBuildConfiguration; baseConfigurationReference = '+configref+'; buildSettings = '+settings(values)+'; name = '+mode+';}'))
    return obj(name+'configlist','{isa = XCConfigurationList; buildConfigurations = '+arr(configs)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}')
projectconfig=configlist('project',{})
appconfig=configlist('app',{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'$(PANTRY_BUNDLE_ID)','INFOPLIST_FILE':'Configuration/App-Info.plist','CODE_SIGN_ENTITLEMENTS':'Configuration/Pantry.entitlements','GENERATE_INFOPLIST_FILE':'NO'})
widgetconfig=configlist('widget',{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'$(PANTRY_BUNDLE_ID).widgets','INFOPLIST_FILE':'Configuration/Widget-Info.plist','CODE_SIGN_ENTITLEMENTS':'Configuration/Pantry.entitlements','APPLICATION_EXTENSION_API_ONLY':'YES','SKIP_INSTALL':'YES','GENERATE_INFOPLIST_FILE':'NO'})
watchconfig=configlist('watch',{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'$(PANTRY_BUNDLE_ID).watchkitapp','INFOPLIST_FILE':'Configuration/Watch-Info.plist','SDKROOT':'watchos','SUPPORTED_PLATFORMS':'watchos watchsimulator','WATCHOS_DEPLOYMENT_TARGET':'10.0','TARGETED_DEVICE_FAMILY':'4','SKIP_INSTALL':'YES','GENERATE_INFOPLIST_FILE':'NO'})
obj('watch','{isa = PBXNativeTarget; buildConfigurationList = '+watchconfig+'; buildPhases = '+arr([watchsource,watchframework,watchresource])+'; dependencies = (); name = PantryWatch; productName = PantryWatch; productReference = '+watchProduct+'; productType = "com.apple.product-type.application";}')
uitestconfig=configlist('uitest',{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'$(PANTRY_BUNDLE_ID).uitests','GENERATE_INFOPLIST_FILE':'YES','TEST_TARGET_NAME':'Pantry','ENABLE_TESTING_SEARCH_PATHS':'YES'})
obj('uitests','{isa = PBXNativeTarget; buildConfigurationList = '+uitestconfig+'; buildPhases = '+arr([uitestsource,uitestframework])+'; dependencies = '+arr([uitestdep])+'; name = PantryUITests; productName = PantryUITests; productReference = '+uitestProduct+'; productType = "com.apple.product-type.bundle.ui-testing";}')
obj('app','{isa = PBXNativeTarget; buildConfigurationList = '+appconfig+'; buildPhases = '+arr([asource,aframework,aresource,embed,watchembed])+'; dependencies = '+arr([dep,watchdep])+'; name = Pantry; productName = Pantry; productReference = '+appProduct+'; productType = "com.apple.product-type.application"; packageProductDependencies = '+arr(packages)+';}')
obj('widget','{isa = PBXNativeTarget; buildConfigurationList = '+widgetconfig+'; buildPhases = '+arr([wsource,wframework,wresource])+'; dependencies = (); name = PantryWidgets; productName = PantryWidgets; productReference = '+widgetProduct+'; productType = "com.apple.product-type.app-extension";}')
project=obj('project','{isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {'+app+' = {ProvisioningStyle = Automatic; SystemCapabilities = {com.apple.ApplicationGroups.iOS = {enabled = 1;};};}; '+widget+' = {ProvisioningStyle = Automatic; SystemCapabilities = {com.apple.ApplicationGroups.iOS = {enabled = 1;};};}; '+watch+' = {ProvisioningStyle = Automatic;};};}; buildConfigurationList = '+projectconfig+'; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, Base); mainGroup = '+group+'; productRefGroup = '+products+'; projectDirPath = ""; projectRoot = ""; targets = '+arr([app,widget,watch,uitests])+'; packageReferences = '+arr([firebase,google])+';}')
path=root/'Pantry.xcodeproj';path.mkdir(exist_ok=True)
(path/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(k+' = '+v+';' for k,v in objects.items())+'\n}; rootObject = '+project+';}\n')
schemes=path/'xcshareddata'/'xcschemes';schemes.mkdir(parents=True,exist_ok=True)
(schemes/'Pantry.xcscheme').write_text('''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+app+'''" BuildableName="Pantry.app" BlueprintName="Pantry" ReferencedContainer="container:Pantry.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+uitests+'''" BuildableName="PantryUITests.xctest" BlueprintName="PantryUITests" ReferencedContainer="container:Pantry.xcodeproj"/></TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+app+'''" BuildableName="Pantry.app" BlueprintName="Pantry" ReferencedContainer="container:Pantry.xcodeproj"/></BuildableProductRunnable></LaunchAction><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')

(schemes/'PantryWatch.xcscheme').write_text('''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="NO" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="NO" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+watch+'''" BuildableName="PantryWatch.app" BlueprintName="PantryWatch" ReferencedContainer="container:Pantry.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+watch+'''" BuildableName="PantryWatch.app" BlueprintName="PantryWatch" ReferencedContainer="container:Pantry.xcodeproj"/></BuildableProductRunnable></LaunchAction></Scheme>''')
