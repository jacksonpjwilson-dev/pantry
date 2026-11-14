#!/usr/bin/env python3
"""Bound each diagnostic: an unhealthy simulator must not hang failure reporting."""
import os
import subprocess
from pathlib import Path
sim = os.environ.get('PANTRY_SIMULATOR', '')
commands = [
    ('simulator-devices.log', ['xcrun','simctl','list','devices'], 20),
    ('simulator-capture.log', ['xcrun','simctl','io',sim,'screenshot','simulator-failure.png'], 20),
    ('simulator-ui.log', ['xcrun','simctl','spawn',sim,'log','show','--last','5m','--style','compact','--predicate','process == "SpringBoard" OR process == "Pantry" OR process == "PantryUITests-Runner"'], 30),
    ('ui-summary.json', ['xcrun','xcresulttool','get','test-results','summary','--path','native/TestResults/PantryUITests.xcresult'], 20),
]
for filename, command, limit in commands:
    with Path(filename).open('w') as output:
        try:
            subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, timeout=limit, check=False)
        except (subprocess.TimeoutExpired, OSError) as error:
            output.write(f'\nDiagnostic unavailable: {error}\n')
