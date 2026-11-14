import importlib.util
import unittest
import re
import plistlib
from pathlib import Path
spec = importlib.util.spec_from_file_location('configure_ios', Path(__file__).with_name('configure-ios.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ConfigurationTests(unittest.TestCase):
    def test_checked_in_project_enables_debug_backend_only_in_debug(self):
        project = (Path(__file__).resolve().parents[1]/'Pantry.xcodeproj/project.pbxproj').read_text()
        configurations = re.findall(r'isa = XCBuildConfiguration;.*?buildSettings = \{(.*?)\}; name = (Debug|Release);', project)
        self.assertEqual(len(configurations), 10)
        for settings, mode in configurations:
            flag = re.search(r'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "([^"]*)"', settings)
            self.assertIsNotNone(flag)
            self.assertEqual('DEBUG' in flag.group(1).split(), mode == 'Debug')
    def test_simulator_keychain_identity_is_scoped_to_each_bundle(self):
        root = Path(__file__).resolve().parents[1]
        entitlements = plistlib.loads((root/'Configuration/Simulator.entitlements').read_bytes())
        self.assertEqual(entitlements['application-identifier'], '$(PRODUCT_BUNDLE_IDENTIFIER)')
        self.assertEqual(entitlements['keychain-access-groups'], ['$(PRODUCT_BUNDLE_IDENTIFIER)'])
        project = (root/'Pantry.xcodeproj/project.pbxproj').read_text()
        self.assertEqual(project.count('"CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]" = "Configuration/Simulator.entitlements"'), 4)
    def test_personal_settings_share_identifiers(self):
        text = module.configuration('ABCDE12345', 'dev.example.pantry', 'group.dev.example.pantry')
        self.assertIn('DEVELOPMENT_TEAM = ABCDE12345', text)
        self.assertIn('PANTRY_BUNDLE_ID = dev.example.pantry', text)
    def test_rejects_build_setting_injection(self):
        for bundle in ['dev.example\nOTHER = YES', '$(SECRET)', 'dev.example;foo']:
            with self.assertRaises(ValueError): module.configuration('ABCDE12345', bundle, 'group.dev.example')
    def test_refuses_wrong_firebase_project_or_bundle(self):
        for data in [{'PROJECT_ID':'other'}, {'PROJECT_ID':'logbook-e784a','BUNDLE_ID':'other'}]:
            with self.assertRaises(ValueError): module.configuration('ABCDE12345','dev.example','group.dev.example',data)
    def test_valid_google_configuration_and_missing_fields(self):
        data = dict(PROJECT_ID='logbook-e784a', BUNDLE_ID='dev.example', GOOGLE_APP_ID='1:123:ios:abc', API_KEY='synthetic', GCM_SENDER_ID='123', CLIENT_ID='123.apps.googleusercontent.com', REVERSED_CLIENT_ID='com.googleusercontent.apps.123')
        self.assertIn('PANTRY_GOOGLE_URL_SCHEME = com.googleusercontent.apps.123', module.configuration('ABCDE12345','dev.example','group.dev.example',data))
        del data['CLIENT_ID']
        with self.assertRaises(ValueError): module.configuration('ABCDE12345','dev.example','group.dev.example',data)

if __name__ == '__main__': unittest.main()
