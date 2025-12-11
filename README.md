# go-netbox

[![CI](https://github.com/bab3l/go-netbox/actions/workflows/ci.yml/badge.svg)](https://github.com/bab3l/go-netbox/actions/workflows/ci.yml)
[![CodeQL](https://github.com/bab3l/go-netbox/actions/workflows/codeql.yml/badge.svg)](https://github.com/bab3l/go-netbox/actions/workflows/codeql.yml)
[![Go Report Card](https://goreportcard.com/badge/github.com/bab3l/go-netbox)](https://goreportcard.com/report/github.com/bab3l/go-netbox)
[![Go Version](https://img.shields.io/github/go-mod/go-version/bab3l/go-netbox)](https://github.com/bab3l/go-netbox/blob/main/go.mod)
[![License: MPL-2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)

A Go client library (SDK) for the NetBox API, auto-generated from the NetBox OpenAPI specification.

License: This project is licensed under the Mozilla Public License 2.0 (MPL-2.0). See `LICENSE`.

[Contributing Guidelines](CONTRIBUTING.md) • [Security Policy](SECURITY.md)

## CI & Quality

- CI: Build, test, lint (`golangci-lint`), and security scan (`gosec`) on PRs and `main`.
- CodeQL: Automated code analysis runs on push/PR and weekly schedule.
- Dependabot: Weekly updates for Go modules and GitHub Actions.

## Compatibility Matrix

This SDK tracks NetBox API releases. Use versions aligned to your NetBox deployment.

| SDK Version | NetBox Version | Notes |
|-------------|----------------|-------|
| v0.1.x      | 4.1.11         | Current series generated against NetBox 4.1.11 OpenAPI. |

Guidance:
- Pin a specific tag (e.g., `v0.1.3`) in `go.mod`.
- Future SDK minors (e.g., `v0.2.x`) will align to newer NetBox series (e.g., `4.2.x`).
- Breaking API changes will be reflected in a new minor (`v0.y.x`). Patch releases (`x`) are backwards compatible.

## Regeneration Process

This SDK is generated from the NetBox OpenAPI specification for a target NetBox release.

- Source: NetBox OpenAPI for the target version (e.g., 4.1.11)
- Generation: use scripts in `utils/` (`generate_api.ps1` / `generate_api.sh`) to generate `api_*.go`, `model_*.go`, and client scaffolding
- Inputs: version tracked in `utils/netbox_major_version`
- Post-processing: minimal fixes if needed to satisfy linters and Go best practices (`utils/fix-spec.py` for spec adjustments)
- Tagging: create a release tag for the generated SDK (`v0.y.z`) aligned to the NetBox series

We keep generation inputs pinned per series and note any manual adjustments in the release notes.

See [RELEASE.md](RELEASE.md) for the full release process and versioning strategy.

## Contributing (Local Quality Checks)

Before opening a PR, please run:

```powershell
# Lint (requires golangci-lint installed)
golangci-lint run

# Security scan (optional)
go install github.com/securego/gosec/v2/cmd/gosec@latest
gosec ./...

# Tests
go test ./... -v
```

## Installation

```bash
go get github.com/bab3l/go-netbox
```

## Basic Usage

```go
package main

import (
    "context"
    "fmt"
    netbox "github.com/bab3l/go-netbox"
)

func main() {
    cfg := netbox.NewConfiguration()
    cfg.Servers[0].URL = "https://netbox.example.com"
    cfg.AddDefaultHeader("Authorization", "Token YOUR_API_TOKEN")

    client := netbox.NewAPIClient(cfg)

    list, _, err := client.DcimAPI.DcimSitesList(context.Background()).Execute()
    if err != nil {
        panic(err)
    }

    for _, s := range list.Results {
        fmt.Println(s.Name)
    }
}
```
