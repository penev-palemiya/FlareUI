import pathlib
import re
import subprocess
import sys

private = re.compile(r'(^|/)(AGENTS\.md|CLAUDE\.md|GEMINI\.md|copilot-instructions\.md|PROMPT_PHASE_[^/]*|\.env(?:\..*)?|\.agent-private|agents|policies|templates)(/|$)', re.I)
secret = re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|(?i:(?:api[_-]?key|secret|password))\s*[:=]\s*["\'][^"\'\s]{12,}["\']')
paths = subprocess.check_output(['git', 'ls-files', '-z']).split(b'\0')
errors = []
for raw in filter(None, paths):
    name = raw.decode('utf-8', 'surrogateescape')
    path = pathlib.Path(name)
    if private.search(name) or (path.is_file() and not path.is_symlink() and secret.search(path.read_bytes())):
        errors.append(name)
if errors:
    print('Private file or possible secret: ' + ', '.join(errors), file=sys.stderr)
    sys.exit(1)
print('Privacy scan passed; patterns cannot detect every secret')
