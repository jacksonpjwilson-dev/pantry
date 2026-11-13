#!/usr/bin/env python3
"""Prepare personal signing/Firebase configuration locally; never contacts Firebase."""
import argparse
import plistlib
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def configuration(team, bundle, group, firebase=None):
    if not re.fullmatch(r'[A-Z0-9]{10}', team):
        raise ValueError('Apple Team ID must contain 10 uppercase letters/digits (not the team display name).')
    for label, value in [('bundle ID', bundle), ('App Group', group)]:
        if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', value):
            raise ValueError(f'Invalid {label}; use a reverse-DNS identifier without spaces or build variables.')
    if not group.startswith('group.'):
        raise ValueError('App Group must start with group.')
    scheme = 'pantry-google-unconfigured'
    if firebase is not None:
        if firebase.get('PROJECT_ID') != 'logbook-e784a':
            raise ValueError('Firebase plist must belong to the existing logbook-e784a project.')
        if firebase.get('BUNDLE_ID') != bundle:
            raise ValueError('Firebase BUNDLE_ID does not match the selected iOS bundle ID. Register that iOS app in the existing project.')
        for key in ['GOOGLE_APP_ID', 'API_KEY', 'GCM_SENDER_ID', 'CLIENT_ID', 'REVERSED_CLIENT_ID']:
            if not isinstance(firebase.get(key), str) or not firebase[key].strip():
                raise ValueError(f'Firebase plist is missing {key}. Enable Google sign-in and download the iOS plist again.')
        scheme = firebase['REVERSED_CLIENT_ID']
        if not re.fullmatch(r'[A-Za-z][A-Za-z0-9.+-]*', scheme):
            raise ValueError('Invalid REVERSED_CLIENT_ID URL scheme.')
    return f'DEVELOPMENT_TEAM = {team}\nPANTRY_BUNDLE_ID = {bundle}\nPANTRY_APP_GROUP = {group}\nPANTRY_GOOGLE_URL_SCHEME = {scheme}\n'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--team', required=True)
    parser.add_argument('--bundle-id', default='dev.jacksonwilson.pantry')
    parser.add_argument('--app-group', default='group.dev.jacksonwilson.pantry')
    parser.add_argument('--firebase-plist', type=Path)
    args = parser.parse_args()
    destination = ROOT/'Pantry/GoogleService-Info.plist'
    # Revalidate an existing local plist too; changing bundle ID must not silently strand authentication.
    source = args.firebase_plist or (destination if destination.exists() else None)
    try:
        firebase = plistlib.loads(source.read_bytes()) if source else None
        contents = configuration(args.team, args.bundle_id, args.app_group, firebase)
    except (ValueError, OSError, plistlib.InvalidFileException) as error:
        parser.error(str(error))
    (ROOT/'Configuration/Local.xcconfig').write_text('// Personal configuration. Do not commit.\n'+contents)
    if source and source.resolve() != destination.resolve():
        shutil.copyfile(source, destination)
    subprocess.run(['python3', str(ROOT/'scripts/generate-project.py')], check=True)
    print('Prepared automatic signing for all targets. Open native/Pantry.xcodeproj; select Pantry and your iPhone.')
    print('Firebase configured locally.' if firebase else 'Device-only mode: rerun with --firebase-plist when the registered iOS plist is available.')

if __name__ == '__main__':
    main()
