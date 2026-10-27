# Security Policy

## Supported version

Security fixes apply to the current `main` branch.

## Reporting

Do not disclose a suspected vulnerability in ordinary issue or pull-request
discussion. Contact the repository owner through an existing private channel,
or use GitHub's private vulnerability reporting or security advisory flow when
it is available for this repository.

Include the affected revision, reproduction steps, expected and observed
behavior, impact, and any suggested mitigation. Do not include real
credentials, tokens, keys, machine identifiers, or unrelated personal data.

## Secret handling

Never commit secrets. If a secret enters Git history, stop publication work,
notify the owner privately, revoke or rotate the secret immediately, and then
clean every reachable ref.

If any history containing the secret was pushed, coordinate cleanup of
remote cached views, pull requests, forks, clones, and other copies.
Treat the credential as compromised even after Git cleanup.
