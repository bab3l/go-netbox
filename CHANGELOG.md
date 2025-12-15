# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2025-12-15

### Changed
- Added CI/CD workflows (linting, security scanning, CodeQL)
- Added Dependabot configuration for Go modules and GitHub Actions
- Added production-ready governance documents (CONTRIBUTING, SECURITY)
- Enhanced README with compatibility matrix and regeneration process

## [0.1.0] - 2024-12-11

### Added
- Initial public release of go-netbox SDK
- Generated from NetBox 4.1.11 OpenAPI specification
- Full API coverage for NetBox 4.1.11:
  - DCIM (Data Center Infrastructure Management)
  - IPAM (IP Address Management)
  - Circuits
  - Tenancy
  - Virtualization
  - VPN (IPSec, Tunnels, L2VPN)
  - Wireless
  - Extras (Custom fields, Tags, Webhooks, etc.)
  - Users and Core APIs
- Auto-generated Go client with type-safe models
- Support for all NetBox CRUD operations
- Pagination support via `PaginatedXList` types
- MPL-2.0 license

[Unreleased]: https://github.com/bab3l/go-netbox/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bab3l/go-netbox/releases/tag/v0.1.0
