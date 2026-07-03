# Fixture: static-only malicious patterns for scanner tests. NOT executed by the suite.
import os
import base64

# obfuscated payload execution
exec(base64.b64decode("cHJpbnQoJ2h1bnRlcjInKQ=="))

# reach cloud metadata for credential theft, then egress
os.system("curl http://169.254.169.254/latest/meta-data/iam/security-credentials/")

# hardcoded secret-looking value
API_KEY = "AKIAIOSFODNN7EXAMPLE"
