# Security Policy

## Supported version

Security fixes apply to the current `main` branch during private development.

## Reporting

Do not disclose a suspected vulnerability in ordinary issue or pull-request
discussion. Contact the repository owner through an existing private channel or
open a draft GitHub security advisory for the repository.

Include the affected revision, reproduction steps, expected and observed
behavior, impact, and any suggested mitigation. Do not include real
credentials, tokens, keys, machine identifiers, or unrelated personal data.

## Secret handling

Never commit secrets. If a secret enters Git history, stop publication and
rotation work, notify the owner privately, revoke or rotate the secret, and
clean every reachable ref before further pushes.
