# Security Policy

## Supported versions

Security fixes are applied to the latest code on `main` and to the most recent published release when a release exists. Older releases may not receive backports.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability.

Use GitHub's **Security > Advisories > Report a vulnerability** flow for this repository. Include:

- the affected version or commit;
- the macOS and hardware version used for testing;
- clear reproduction steps or a proof of concept;
- the expected impact;
- any suggested mitigation, if known.

The maintainer will try to acknowledge a complete report within seven days. Confirmation, remediation, and disclosure timing depend on severity and reproducibility. Please allow time for a signed and notarized replacement build before public disclosure.

## Release trust

Only assets attached to this repository's GitHub Releases are official public binaries. A binary release should include a notarized DMG and its SHA-256 checksum. Never trust an unsigned archive produced by `scripts/build-unsigned.sh` as an end-user distribution.
