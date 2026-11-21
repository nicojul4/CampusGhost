# Changelog

All notable changes to this project are documented here.

## [Unreleased]

### Added

- Added a redacted `.env.example` for the local API and optional Functions seed script.
- Added security, troubleshooting, and clean-clone verification reports for handover.

### Changed

- Restricted the local API's default bind address and browser origins to local development.
- Limited API request bodies to 1 MiB and removed raw error objects from logs.
- Disabled the API reset endpoint when `NODE_ENV=production`.
- Rewrote the README with tested local setup, run, build, test, and demo-serving instructions.

### Fixed

- Updated vulnerable transitive `body-parser` and `qs` versions in the Functions lockfile.

### Security

- Added security response headers and a local CORS allowlist to the demo API.
