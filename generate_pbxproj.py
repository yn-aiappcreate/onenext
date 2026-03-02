#!/usr/bin/env python3
import uuid

def make_id(seed):
    return uuid.uuid5(uuid.NAMESPACE_DNS, f"onenext.{seed}").hex[:24].upper()

ids = {}

# File References
for key in [
    "fr_app_swift", "fr_content_view", "fr_assets", "fr_preview_assets",
    "fr_goal", "fr_step", "fr_planslot", "fr_reviewlog",
    "fr_backlog_tab", "fr_goal_form", "fr_goal_detail",
    "fr_plan_tab", "fr_review_tab", "fr_settings_tab",
    "fr_empty_state",
    "fr_template_engine", "fr_notification_manager", "fr_csv_exporter", "fr_date_helper", "fr_constants",
    "fr_onboarding_view",
    "fr_ai_models", "fr_ai_service", "fr_redactor",
    "fr_ai_consent_view", "fr_ai_step_sheet",
    "fr_product_app", "fr_product_tests",
    "fr_model_tests", "fr_template_tests", "fr_datehelper_tests",
]:
    ids[key] = make_id(key)

# Build Files
for key in [
    "bf_app_swift", "bf_content_view", "bf_assets",
    "bf_goal", "bf_step", "bf_planslot", "bf_reviewlog",
    "bf_backlog_tab", "bf_goal_form", "bf_goal_detail",
    "bf_plan_tab", "bf_review_tab", "bf_settings_tab",
    "bf_empty_state",
    "bf_template_engine", "bf_notification_manager", "bf_csv_exporter", "bf_date_helper", "bf_constants",
    "bf_onboarding_view",
    "bf_ai_models", "bf_ai_service", "bf_redactor",
    "bf_ai_consent_view", "bf_ai_step_sheet",
    "bf_model_tests", "bf_template_tests", "bf_datehelper_tests",
]:
    ids[key] = make_id(key)

# Groups, Targets, Phases, Configs, Lists, Other
for key in [
    "gr_main", "gr_onenext", "gr_app", "gr_models", "gr_views",
    "gr_backlog", "gr_plan", "gr_review", "gr_settings", "gr_components",
    "gr_services", "gr_utilities", "gr_preview", "gr_tests", "gr_products",
    "gr_onboarding",
    "gr_ai",
    "tg_app", "tg_tests",
    "bp_app_sources", "bp_app_frameworks", "bp_app_resources",
    "bp_tests_sources", "bp_tests_frameworks", "bp_tests_resources",
    "bc_proj_debug", "bc_proj_release", "bc_app_debug", "bc_app_release",
    "bc_tests_debug", "bc_tests_release",
    "cl_project", "cl_app", "cl_tests",
    "project", "proxy", "dependency",
]:
    ids[key] = make_id(key)

# Build file -> file ref mappings
bf_to_fr = {
    "bf_app_swift": ("fr_app_swift", "TsugiIchiApp.swift"),
    "bf_content_view": ("fr_content_view", "ContentView.swift"),
    "bf_assets": ("fr_assets", "Assets.xcassets"),
    "bf_goal": ("fr_goal", "Goal.swift"),
    "bf_step": ("fr_step", "Step.swift"),
    "bf_planslot": ("fr_planslot", "PlanSlot.swift"),
    "bf_reviewlog": ("fr_reviewlog", "ReviewLog.swift"),
    "bf_backlog_tab": ("fr_backlog_tab", "BacklogTab.swift"),
    "bf_goal_form": ("fr_goal_form", "GoalFormSheet.swift"),
    "bf_goal_detail": ("fr_goal_detail", "GoalDetailView.swift"),
    "bf_plan_tab": ("fr_plan_tab", "PlanTab.swift"),
    "bf_review_tab": ("fr_review_tab", "ReviewTab.swift"),
    "bf_settings_tab": ("fr_settings_tab", "SettingsTab.swift"),
    "bf_template_engine": ("fr_template_engine", "TemplateEngine.swift"),
    "bf_notification_manager": ("fr_notification_manager", "NotificationManager.swift"),
    "bf_csv_exporter": ("fr_csv_exporter", "CSVExporter.swift"),
    "bf_date_helper": ("fr_date_helper", "DateHelper.swift"),
    "bf_constants": ("fr_constants", "Constants.swift"),
    "bf_empty_state": ("fr_empty_state", "EmptyStateView.swift"),
    "bf_onboarding_view": ("fr_onboarding_view", "OnboardingView.swift"),
    "bf_ai_models": ("fr_ai_models", "AIModels.swift"),
    "bf_ai_service": ("fr_ai_service", "AIService.swift"),
    "bf_redactor": ("fr_redactor", "Redactor.swift"),
    "bf_ai_consent_view": ("fr_ai_consent_view", "AIConsentView.swift"),
    "bf_ai_step_sheet": ("fr_ai_step_sheet", "AIStepSheet.swift"),
    "bf_model_tests": ("fr_model_tests", "ModelTests.swift"),
    "bf_template_tests": ("fr_template_tests", "TemplateEngineTests.swift"),
    "bf_datehelper_tests": ("fr_datehelper_tests", "DateHelperTests.swift"),
}

app_sources = [
    "bf_app_swift", "bf_content_view", "bf_goal", "bf_step", "bf_planslot",
    "bf_reviewlog", "bf_backlog_tab", "bf_goal_form", "bf_goal_detail",
    "bf_plan_tab", "bf_review_tab",
    "bf_settings_tab", "bf_template_engine", "bf_notification_manager", "bf_csv_exporter",
    "bf_date_helper", "bf_constants",
    "bf_empty_state", "bf_onboarding_view",
    "bf_ai_models", "bf_ai_service", "bf_redactor",
    "bf_ai_consent_view", "bf_ai_step_sheet",
]
app_resources = ["bf_assets"]
test_sources = ["bf_model_tests", "bf_template_tests", "bf_datehelper_tests"]

# Helper
def I(key):
    return ids[key]

lines = []
def w(s=""):
    lines.append(s)

w("// !$*UTF8*$!")
w("{")
w("\tarchiveVersion = 1;")
w("\tclasses = {")
w("\t};")
w("\tobjectVersion = 56;")
w("\tobjects = {")
w()

# PBXBuildFile
w("/* Begin PBXBuildFile section */")
for bf_key, (fr_key, name) in bf_to_fr.items():
    phase = "Resources" if bf_key in app_resources else "Sources"
    w(f"\t\t{I(bf_key)} /* {name} in {phase} */ = {{isa = PBXBuildFile; fileRef = {I(fr_key)} /* {name} */; }};")
w("/* End PBXBuildFile section */")
w()

# PBXContainerItemProxy
w("/* Begin PBXContainerItemProxy section */")
w(f"\t\t{I('proxy')} /* PBXContainerItemProxy */ = {{")
w(f"\t\t\tisa = PBXContainerItemProxy;")
w(f"\t\t\tcontainerPortal = {I('project')} /* Project object */;")
w(f"\t\t\tproxyType = 1;")
w(f"\t\t\tremoteGlobalIDString = {I('tg_app')};")
w(f"\t\t\tremoteInfo = TsugiIchi;")
w(f"\t\t}};")
w("/* End PBXContainerItemProxy section */")
w()

# PBXFileReference
w("/* Begin PBXFileReference section */")
fr_info = [
    ("fr_app_swift", "lastKnownFileType = sourcecode.swift", "TsugiIchiApp.swift", '"<group>"'),
    ("fr_content_view", "lastKnownFileType = sourcecode.swift", "ContentView.swift", '"<group>"'),
    ("fr_assets", "lastKnownFileType = folder.assetcatalog", "Assets.xcassets", '"<group>"'),
    ("fr_preview_assets", "lastKnownFileType = folder.assetcatalog", '"Preview Assets.xcassets"', '"<group>"'),
    ("fr_goal", "lastKnownFileType = sourcecode.swift", "Goal.swift", '"<group>"'),
    ("fr_step", "lastKnownFileType = sourcecode.swift", "Step.swift", '"<group>"'),
    ("fr_planslot", "lastKnownFileType = sourcecode.swift", "PlanSlot.swift", '"<group>"'),
    ("fr_reviewlog", "lastKnownFileType = sourcecode.swift", "ReviewLog.swift", '"<group>"'),
    ("fr_backlog_tab", "lastKnownFileType = sourcecode.swift", "BacklogTab.swift", '"<group>"'),
    ("fr_goal_form", "lastKnownFileType = sourcecode.swift", "GoalFormSheet.swift", '"<group>"'),
    ("fr_goal_detail", "lastKnownFileType = sourcecode.swift", "GoalDetailView.swift", '"<group>"'),
    ("fr_plan_tab", "lastKnownFileType = sourcecode.swift", "PlanTab.swift", '"<group>"'),
    ("fr_review_tab", "lastKnownFileType = sourcecode.swift", "ReviewTab.swift", '"<group>"'),
    ("fr_settings_tab", "lastKnownFileType = sourcecode.swift", "SettingsTab.swift", '"<group>"'),
    ("fr_template_engine", "lastKnownFileType = sourcecode.swift", "TemplateEngine.swift", '"<group>"'),
    ("fr_notification_manager", "lastKnownFileType = sourcecode.swift", "NotificationManager.swift", '"<group>"'),
    ("fr_csv_exporter", "lastKnownFileType = sourcecode.swift", "CSVExporter.swift", '"<group>"'),
    ("fr_onboarding_view", "lastKnownFileType = sourcecode.swift", "OnboardingView.swift", '"<group>"'),
    ("fr_ai_models", "lastKnownFileType = sourcecode.swift", "AIModels.swift", '"<group>"'),
    ("fr_ai_service", "lastKnownFileType = sourcecode.swift", "AIService.swift", '"<group>"'),
    ("fr_redactor", "lastKnownFileType = sourcecode.swift", "Redactor.swift", '"<group>"'),
    ("fr_ai_consent_view", "lastKnownFileType = sourcecode.swift", "AIConsentView.swift", '"<group>"'),
    ("fr_ai_step_sheet", "lastKnownFileType = sourcecode.swift", "AIStepSheet.swift", '"<group>"'),
    ("fr_date_helper", "lastKnownFileType = sourcecode.swift", "DateHelper.swift", '"<group>"'),
    ("fr_constants", "lastKnownFileType = sourcecode.swift", "Constants.swift", '"<group>"'),
    ("fr_empty_state", "lastKnownFileType = sourcecode.swift", "EmptyStateView.swift", '"<group>"'),
    ("fr_product_app", "explicitFileType = wrapper.application", "TsugiIchi.app", "BUILT_PRODUCTS_DIR"),
    ("fr_product_tests", "explicitFileType = wrapper.cfbundle", "TsugiIchiTests.xctest", "BUILT_PRODUCTS_DIR"),
    ("fr_model_tests", "lastKnownFileType = sourcecode.swift", "ModelTests.swift", '"<group>"'),
    ("fr_template_tests", "lastKnownFileType = sourcecode.swift", "TemplateEngineTests.swift", '"<group>"'),
    ("fr_datehelper_tests", "lastKnownFileType = sourcecode.swift", "DateHelperTests.swift", '"<group>"'),
]
for key, ftype, path, stree in fr_info:
    name = path.strip('"')
    extra = " includeInIndex = 0;" if "explicitFileType" in ftype else ""
    w(f'\t\t{I(key)} /* {name} */ = {{isa = PBXFileReference; {ftype};{extra} path = {path}; sourceTree = {stree}; }};')
w("/* End PBXFileReference section */")
w()

# PBXFrameworksBuildPhase
w("/* Begin PBXFrameworksBuildPhase section */")
for phase_key in ["bp_app_frameworks", "bp_tests_frameworks"]:
    w(f"\t\t{I(phase_key)} /* Frameworks */ = {{")
    w(f"\t\t\tisa = PBXFrameworksBuildPhase;")
    w(f"\t\t\tbuildActionMask = 2147483647;")
    w(f"\t\t\tfiles = (")
    w(f"\t\t\t);")
    w(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w(f"\t\t}};")
w("/* End PBXFrameworksBuildPhase section */")
w()

# PBXGroup
w("/* Begin PBXGroup section */")

def write_group(key, name, children, path=None, is_name=False):
    w(f"\t\t{I(key)} /* {name} */ = {{")
    w(f"\t\t\tisa = PBXGroup;")
    w(f"\t\t\tchildren = (")
    for cid, cname in children:
        w(f"\t\t\t\t{I(cid)} /* {cname} */,")
    w(f"\t\t\t);")
    if is_name:
        w(f'\t\t\tname = {name};')
    elif path:
        if " " in path:
            w(f'\t\t\tpath = "{path}";')
        else:
            w(f"\t\t\tpath = {path};")
    w(f'\t\t\tsourceTree = "<group>";')
    w(f"\t\t}};")

write_group("gr_main", "", [
    ("gr_onenext", "TsugiIchi"),
    ("gr_tests", "TsugiIchiTests"),
    ("gr_products", "Products"),
])

write_group("gr_onenext", "TsugiIchi", [
    ("gr_app", "App"),
    ("gr_models", "Models"),
    ("gr_views", "Views"),
    ("gr_services", "Services"),
    ("gr_utilities", "Utilities"),
], path="TsugiIchi")

write_group("gr_app", "App", [
    ("fr_app_swift", "TsugiIchiApp.swift"),
    ("fr_content_view", "ContentView.swift"),
    ("fr_assets", "Assets.xcassets"),
    ("gr_preview", "Preview Content"),
], path="App")

write_group("gr_preview", "Preview Content", [
    ("fr_preview_assets", "Preview Assets.xcassets"),
], path="Preview Content")

write_group("gr_models", "Models", [
    ("fr_goal", "Goal.swift"),
    ("fr_step", "Step.swift"),
    ("fr_planslot", "PlanSlot.swift"),
    ("fr_reviewlog", "ReviewLog.swift"),
    ("fr_ai_models", "AIModels.swift"),
], path="Models")

write_group("gr_views", "Views", [
    ("gr_backlog", "Backlog"),
    ("gr_plan", "Plan"),
    ("gr_review", "Review"),
    ("gr_settings", "Settings"),
    ("gr_components", "Components"),
    ("gr_onboarding", "Onboarding"),
    ("gr_ai", "AI"),
], path="Views")

write_group("gr_backlog", "Backlog", [
    ("fr_backlog_tab", "BacklogTab.swift"),
    ("fr_goal_form", "GoalFormSheet.swift"),
    ("fr_goal_detail", "GoalDetailView.swift"),
], path="Backlog")

write_group("gr_components", "Components", [
    ("fr_empty_state", "EmptyStateView.swift"),
], path="Components")

for grp, fr, fname, path in [
    ("gr_plan", "fr_plan_tab", "PlanTab.swift", "Plan"),
    ("gr_review", "fr_review_tab", "ReviewTab.swift", "Review"),
    ("gr_settings", "fr_settings_tab", "SettingsTab.swift", "Settings"),
]:
    write_group(grp, path, [(fr, fname)], path=path)

write_group("gr_onboarding", "Onboarding", [
    ("fr_onboarding_view", "OnboardingView.swift"),
], path="Onboarding")

write_group("gr_ai", "AI", [
    ("fr_ai_consent_view", "AIConsentView.swift"),
    ("fr_ai_step_sheet", "AIStepSheet.swift"),
], path="AI")

write_group("gr_services", "Services", [
    ("fr_template_engine", "TemplateEngine.swift"),
    ("fr_notification_manager", "NotificationManager.swift"),
    ("fr_csv_exporter", "CSVExporter.swift"),
    ("fr_ai_service", "AIService.swift"),
    ("fr_redactor", "Redactor.swift"),
], path="Services")

write_group("gr_utilities", "Utilities", [
    ("fr_date_helper", "DateHelper.swift"),
    ("fr_constants", "Constants.swift"),
], path="Utilities")

write_group("gr_tests", "TsugiIchiTests", [
    ("fr_model_tests", "ModelTests.swift"),
    ("fr_template_tests", "TemplateEngineTests.swift"),
    ("fr_datehelper_tests", "DateHelperTests.swift"),
], path="TsugiIchiTests")

write_group("gr_products", "Products", [
    ("fr_product_app", "TsugiIchi.app"),
    ("fr_product_tests", "TsugiIchiTests.xctest"),
], is_name=True)

w("/* End PBXGroup section */")
w()

# PBXNativeTarget
w("/* Begin PBXNativeTarget section */")
w(f"\t\t{I('tg_app')} /* TsugiIchi */ = {{")
w(f"\t\t\tisa = PBXNativeTarget;")
w(f'\t\t\tbuildConfigurationList = {I("cl_app")} /* Build configuration list for PBXNativeTarget "TsugiIchi" */;')
w(f"\t\t\tbuildPhases = (")
w(f"\t\t\t\t{I('bp_app_sources')} /* Sources */,")
w(f"\t\t\t\t{I('bp_app_frameworks')} /* Frameworks */,")
w(f"\t\t\t\t{I('bp_app_resources')} /* Resources */,")
w(f"\t\t\t);")
w(f"\t\t\tbuildRules = (")
w(f"\t\t\t);")
w(f"\t\t\tdependencies = (")
w(f"\t\t\t);")
w(f"\t\t\tname = TsugiIchi;")
w(f"\t\t\tproductName = TsugiIchi;")
w(f"\t\t\tproductReference = {I('fr_product_app')} /* TsugiIchi.app */;")
w(f'\t\t\tproductType = "com.apple.product-type.application";')
w(f"\t\t}};")

w(f"\t\t{I('tg_tests')} /* TsugiIchiTests */ = {{")
w(f"\t\t\tisa = PBXNativeTarget;")
w(f'\t\t\tbuildConfigurationList = {I("cl_tests")} /* Build configuration list for PBXNativeTarget "TsugiIchiTests" */;')
w(f"\t\t\tbuildPhases = (")
w(f"\t\t\t\t{I('bp_tests_sources')} /* Sources */,")
w(f"\t\t\t\t{I('bp_tests_frameworks')} /* Frameworks */,")
w(f"\t\t\t\t{I('bp_tests_resources')} /* Resources */,")
w(f"\t\t\t);")
w(f"\t\t\tbuildRules = (")
w(f"\t\t\t);")
w(f"\t\t\tdependencies = (")
w(f"\t\t\t\t{I('dependency')} /* PBXTargetDependency */,")
w(f"\t\t\t);")
w(f"\t\t\tname = TsugiIchiTests;")
w(f"\t\t\tproductName = TsugiIchiTests;")
w(f"\t\t\tproductReference = {I('fr_product_tests')} /* TsugiIchiTests.xctest */;")
w(f'\t\t\tproductType = "com.apple.product-type.bundle.unit-test";')
w(f"\t\t}};")
w("/* End PBXNativeTarget section */")
w()

# PBXProject
w("/* Begin PBXProject section */")
w(f"\t\t{I('project')} /* Project object */ = {{")
w(f"\t\t\tisa = PBXProject;")
w(f"\t\t\tattributes = {{")
w(f"\t\t\t\tBuildIndependentTargetsInParallel = 1;")
w(f"\t\t\t\tLastSwiftUpdateCheck = 1520;")
w(f"\t\t\t\tLastUpgradeCheck = 1520;")
w(f"\t\t\t\tTargetAttributes = {{")
w(f"\t\t\t\t\t{I('tg_app')} = {{")
w(f"\t\t\t\t\t\tCreatedOnToolsVersion = 15.2;")
w(f"\t\t\t\t\t}};")
w(f"\t\t\t\t\t{I('tg_tests')} = {{")
w(f"\t\t\t\t\t\tCreatedOnToolsVersion = 15.2;")
w(f"\t\t\t\t\t\tTestTargetID = {I('tg_app')};")
w(f"\t\t\t\t\t}};")
w(f"\t\t\t\t}};")
w(f"\t\t\t}};")
w(f'\t\t\tbuildConfigurationList = {I("cl_project")} /* Build configuration list for PBXProject "TsugiIchi" */;')
w(f'\t\t\tcompatibilityVersion = "Xcode 14.0";')
w(f"\t\t\tdevelopmentRegion = ja;")
w(f"\t\t\thasScannedForEncodings = 0;")
w(f"\t\t\tknownRegions = (")
w(f"\t\t\t\tja,")
w(f"\t\t\t\tBase,")
w(f"\t\t\t);")
w(f"\t\t\tmainGroup = {I('gr_main')};")
w(f"\t\t\tproductRefGroup = {I('gr_products')} /* Products */;")
w(f'\t\t\tprojectDirPath = "";')
w(f'\t\t\tprojectRoot = "";')
w(f"\t\t\ttargets = (")
w(f"\t\t\t\t{I('tg_app')} /* TsugiIchi */,")
w(f"\t\t\t\t{I('tg_tests')} /* TsugiIchiTests */,")
w(f"\t\t\t);")
w(f"\t\t}};")
w("/* End PBXProject section */")
w()

# PBXResourcesBuildPhase
w("/* Begin PBXResourcesBuildPhase section */")
w(f"\t\t{I('bp_app_resources')} /* Resources */ = {{")
w(f"\t\t\tisa = PBXResourcesBuildPhase;")
w(f"\t\t\tbuildActionMask = 2147483647;")
w(f"\t\t\tfiles = (")
w(f"\t\t\t\t{I('bf_assets')} /* Assets.xcassets in Resources */,")
w(f"\t\t\t);")
w(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w(f"\t\t}};")
w(f"\t\t{I('bp_tests_resources')} /* Resources */ = {{")
w(f"\t\t\tisa = PBXResourcesBuildPhase;")
w(f"\t\t\tbuildActionMask = 2147483647;")
w(f"\t\t\tfiles = (")
w(f"\t\t\t);")
w(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w(f"\t\t}};")
w("/* End PBXResourcesBuildPhase section */")
w()

# PBXSourcesBuildPhase
w("/* Begin PBXSourcesBuildPhase section */")
w(f"\t\t{I('bp_app_sources')} /* Sources */ = {{")
w(f"\t\t\tisa = PBXSourcesBuildPhase;")
w(f"\t\t\tbuildActionMask = 2147483647;")
w(f"\t\t\tfiles = (")
for bf in app_sources:
    _, name = bf_to_fr[bf]
    w(f"\t\t\t\t{I(bf)} /* {name} in Sources */,")
w(f"\t\t\t);")
w(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w(f"\t\t}};")
w(f"\t\t{I('bp_tests_sources')} /* Sources */ = {{")
w(f"\t\t\tisa = PBXSourcesBuildPhase;")
w(f"\t\t\tbuildActionMask = 2147483647;")
w(f"\t\t\tfiles = (")
for bf in test_sources:
    _, name = bf_to_fr[bf]
    w(f"\t\t\t\t{I(bf)} /* {name} in Sources */,")
w(f"\t\t\t);")
w(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w(f"\t\t}};")
w("/* End PBXSourcesBuildPhase section */")
w()

# PBXTargetDependency
w("/* Begin PBXTargetDependency section */")
w(f"\t\t{I('dependency')} /* PBXTargetDependency */ = {{")
w(f"\t\t\tisa = PBXTargetDependency;")
w(f"\t\t\ttarget = {I('tg_app')} /* TsugiIchi */;")
w(f"\t\t\ttargetProxy = {I('proxy')} /* PBXContainerItemProxy */;")
w(f"\t\t}};")
w("/* End PBXTargetDependency section */")
w()

# XCBuildConfiguration
w("/* Begin XCBuildConfiguration section */")

# Shared warning settings
warn_settings = [
    "ALWAYS_SEARCH_USER_PATHS = NO;",
    "ASYNCHRONOUS_SYMBOL_CREATION = YES;",
    "CLANG_ANALYZER_NONNULL = YES;",
    "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;",
    'CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";',
    "CLANG_ENABLE_MODULES = YES;",
    "CLANG_ENABLE_OBJC_ARC = YES;",
    "CLANG_ENABLE_OBJC_WEAK = YES;",
    "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;",
    "CLANG_WARN_BOOL_CONVERSION = YES;",
    "CLANG_WARN_COMMA = YES;",
    "CLANG_WARN_CONSTANT_CONVERSION = YES;",
    "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;",
    "CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;",
    "CLANG_WARN_DOCUMENTATION_COMMENTS = YES;",
    "CLANG_WARN_EMPTY_BODY = YES;",
    "CLANG_WARN_ENUM_CONVERSION = YES;",
    "CLANG_WARN_INFINITE_RECURSION = YES;",
    "CLANG_WARN_INT_CONVERSION = YES;",
    "CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;",
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;",
    "CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;",
    "CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;",
    "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;",
    "CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;",
    "CLANG_WARN_STRICT_PROTOTYPES = YES;",
    "CLANG_WARN_SUSPICIOUS_MOVE = YES;",
    "CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;",
    "CLANG_WARN_UNREACHABLE_CODE = YES;",
    "CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;",
    "COPY_PHASE_STRIP = NO;",
    "ENABLE_STRICT_OBJC_MSGSEND = YES;",
    "ENABLE_USER_SCRIPT_SANDBOXING = YES;",
    "GCC_C_LANGUAGE_STANDARD = gnu17;",
    "GCC_NO_COMMON_BLOCKS = YES;",
    "GCC_WARN_64_TO_32_BIT_CONVERSION = YES;",
    "GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;",
    "GCC_WARN_UNDECLARED_SELECTOR = YES;",
    "GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;",
    "GCC_WARN_UNUSED_FUNCTION = YES;",
    "GCC_WARN_UNUSED_VARIABLE = YES;",
    "IPHONEOS_DEPLOYMENT_TARGET = 17.0;",
    "LOCALIZATION_PREFERS_STRING_CATALOGS = YES;",
    "MTL_FAST_MATH = YES;",
    "SDKROOT = iphoneos;",
]

# Project Debug
w(f"\t\t{I('bc_proj_debug')} /* Debug */ = {{")
w(f"\t\t\tisa = XCBuildConfiguration;")
w(f"\t\t\tbuildSettings = {{")
for s in warn_settings:
    w(f"\t\t\t\t{s}")
w(f"\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
w(f"\t\t\t\tENABLE_TESTABILITY = YES;")
w(f"\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;")
w(f"\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
w(f"\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (")
w(f'\t\t\t\t\t"DEBUG=1",')
w(f'\t\t\t\t\t"$(inherited)",')
w(f"\t\t\t\t);")
w(f"\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
w(f"\t\t\t\tONLY_ACTIVE_ARCH = YES;")
w(f'\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";')
w(f'\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";')
w(f"\t\t\t}};")
w(f"\t\t\tname = Debug;")
w(f"\t\t}};")

# Project Release
w(f"\t\t{I('bc_proj_release')} /* Release */ = {{")
w(f"\t\t\tisa = XCBuildConfiguration;")
w(f"\t\t\tbuildSettings = {{")
for s in warn_settings:
    w(f"\t\t\t\t{s}")
w(f'\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";')
w(f"\t\t\t\tENABLE_NS_ASSERTIONS = NO;")
w(f"\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
w(f"\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
w(f"\t\t\t\tVALIDATE_PRODUCT = YES;")
w(f"\t\t\t}};")
w(f"\t\t\tname = Release;")
w(f"\t\t}};")

# App target settings (shared between debug and release)
app_settings = [
    "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;",
    "INFOPLIST_KEY_CFBundleIconName = AppIcon;",
    "CODE_SIGN_STYLE = Automatic;",
    "CURRENT_PROJECT_VERSION = 1;",
    'DEVELOPMENT_ASSET_PATHS = "\\"TsugiIchi/App/Preview Content\\"";',
    "ENABLE_PREVIEWS = YES;",
    "GENERATE_INFOPLIST_FILE = YES;",
    '"INFOPLIST_KEY_CFBundleDisplayName" = "\\U30c4\\U30ae\\U30a4\\U30c1";',
    "INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;",
    "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;",
    "INFOPLIST_KEY_UILaunchScreen_Generation = YES;",
    '"INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad" = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";',
    '"INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone" = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";',
    "MARKETING_VERSION = 1.0;",
    "PRODUCT_BUNDLE_IDENTIFIER = com.ynlabs.tsugiichi;",
    '"PRODUCT_NAME" = "$(TARGET_NAME)";',
    "SWIFT_EMIT_LOC_STRINGS = YES;",
    "SWIFT_VERSION = 5.0;",
    '"TARGETED_DEVICE_FAMILY" = "1,2";',
]

for config_key, config_name in [("bc_app_debug", "Debug"), ("bc_app_release", "Release")]:
    w(f"\t\t{I(config_key)} /* {config_name} */ = {{")
    w(f"\t\t\tisa = XCBuildConfiguration;")
    w(f"\t\t\tbuildSettings = {{")
    for s in app_settings:
        w(f"\t\t\t\t{s}")
    w(f"\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
    w(f'\t\t\t\t\t"$(inherited)",')
    w(f'\t\t\t\t\t"@executable_path/Frameworks",')
    w(f"\t\t\t\t);")
    w(f"\t\t\t}};")
    w(f"\t\t\tname = {config_name};")
    w(f"\t\t}};")

# Test target settings
test_settings = [
    '"BUNDLE_LOADER" = "$(TEST_HOST)";',
    "CODE_SIGN_STYLE = Automatic;",
    "CURRENT_PROJECT_VERSION = 1;",
    "GENERATE_INFOPLIST_FILE = YES;",
    "IPHONEOS_DEPLOYMENT_TARGET = 17.0;",
    "MARKETING_VERSION = 1.0;",
    "PRODUCT_BUNDLE_IDENTIFIER = com.ynlabs.TsugiIchiTests;",
    '"PRODUCT_NAME" = "$(TARGET_NAME)";',
    "SWIFT_EMIT_LOC_STRINGS = NO;",
    "SWIFT_VERSION = 5.0;",
    '"TARGETED_DEVICE_FAMILY" = "1,2";',
    '"TEST_HOST" = "$(BUILT_PRODUCTS_DIR)/TsugiIchi.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/TsugiIchi";',
]

for config_key, config_name in [("bc_tests_debug", "Debug"), ("bc_tests_release", "Release")]:
    w(f"\t\t{I(config_key)} /* {config_name} */ = {{")
    w(f"\t\t\tisa = XCBuildConfiguration;")
    w(f"\t\t\tbuildSettings = {{")
    for s in test_settings:
        w(f"\t\t\t\t{s}")
    w(f"\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
    w(f'\t\t\t\t\t"$(inherited)",')
    w(f'\t\t\t\t\t"@executable_path/Frameworks",')
    w(f'\t\t\t\t\t"@loader_path/Frameworks",')
    w(f"\t\t\t\t);")
    w(f"\t\t\t}};")
    w(f"\t\t\tname = {config_name};")
    w(f"\t\t}};")

w("/* End XCBuildConfiguration section */")
w()

# XCConfigurationList
w("/* Begin XCConfigurationList section */")
for cl_key, cl_name, bc_debug, bc_release in [
    ("cl_project", 'PBXProject "TsugiIchi"', "bc_proj_debug", "bc_proj_release"),
    ("cl_app", 'PBXNativeTarget "TsugiIchi"', "bc_app_debug", "bc_app_release"),
    ("cl_tests", 'PBXNativeTarget "TsugiIchiTests"', "bc_tests_debug", "bc_tests_release"),
]:
    w(f"\t\t{I(cl_key)} /* Build configuration list for {cl_name} */ = {{")
    w(f"\t\t\tisa = XCConfigurationList;")
    w(f"\t\t\tbuildConfigurations = (")
    w(f"\t\t\t\t{I(bc_debug)} /* Debug */,")
    w(f"\t\t\t\t{I(bc_release)} /* Release */,")
    w(f"\t\t\t);")
    w(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    w(f"\t\t\tdefaultConfigurationName = Release;")
    w(f"\t\t}};")
w("/* End XCConfigurationList section */")

w(f"\t}};")
w(f"\trootObject = {I('project')} /* Project object */;")
w("}")

with open("/home/ubuntu/repos/onenext/TsugiIchi.xcodeproj/project.pbxproj", "w") as f:
    f.write("\n".join(lines) + "\n")

print(f"Generated project.pbxproj with {len(ids)} unique IDs")
