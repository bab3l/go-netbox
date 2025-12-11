# Release Process

This document describes how to create a new release of the go-netbox SDK.

## Overview

Releases are automated via GitHub Actions when a version tag is pushed. The SDK follows semantic versioning aligned to NetBox API versions.

## Versioning Strategy

- **Major.Minor.Patch** (e.g., `v0.1.3`)
- **Minor version** tracks NetBox series: `v0.1.x` = NetBox 4.1.x, `v0.2.x` = NetBox 4.2.x
- **Patch version** for bug fixes, post-processing improvements, or documentation updates without API changes

## Pre-Release Checklist

1. **Regenerate SDK** (if targeting a new NetBox version):
   ```powershell
   cd utils
   # Update netbox_major_version file
   ./generate_api.ps1  # or ./generate_api.sh on Unix
   ```

2. **Verify Build**:
   ```powershell
   go mod tidy
   go build ./...
   go test ./... -v
   ```

3. **Run Linting**:
   ```powershell
   golangci-lint run
   ```

4. **Update CHANGELOG.md**:
   - Move items from `[Unreleased]` to a new version section
   - Add release date
   - Note the NetBox version this SDK targets
   - Document any breaking changes, additions, or fixes

5. **Commit Changes**:
   ```powershell
   git add .
   git commit -m "Prepare release v0.X.Y"
   git push origin main
   ```

## Creating a Release

1. **Tag the Release**:
   ```powershell
   git tag -a v0.X.Y -m "Release v0.X.Y - NetBox 4.X.Y support"
   git push origin v0.X.Y
   ```

2. **Automated Release**:
   - GitHub Actions will automatically:
     - Verify `go.mod` is tidy
     - Run tests
     - Extract changelog notes for this version
     - Create a GitHub Release with notes

3. **Verify Release**:
   - Check the [Releases page](https://github.com/bab3l/go-netbox/releases)
   - Verify changelog notes are correct
   - Confirm the tag is published

## Post-Release

1. **Update Unreleased Section**:
   ```markdown
   ## [Unreleased]
   
   ### Added
   ### Changed
   ### Fixed
   ```

2. **Announce**:
   - Update dependent projects (e.g., terraform-provider-netbox)
   - Note compatibility in discussions or README if needed

## Emergency Patch Release

For critical bug fixes:

1. Create a hotfix branch from the tag
2. Apply minimal fixes
3. Update CHANGELOG.md with patch notes
4. Tag the patch version (e.g., `v0.1.4`)
5. Follow normal release process

## Version Compatibility

- Users should pin to a specific minor version (e.g., `v0.1.x`) in `go.mod`
- SDK minor versions align to NetBox API series
- Breaking changes will bump the minor version
