# CI/CD Setup Guide

This document explains the minimal GitHub Actions workflows and Ruby setup.

## Workflows Overview

### 1. `ruby.yml` - Main CI Pipeline
- **Trigger**: Push/PR to main branch
- **Ruby Versions**: 3.1, 3.2, 3.3, 3.4
- **Lint**: RuboCop gate (zero offenses enforced)
- **Actions**: Test, lint, and build gem
- **Status**: ✅ Minimal and reliable

### 2. `release.yml` - Automated Releases
- **Trigger**: Git tags (v*)
- **Actions**: Test, build, create GitHub release
- **Artifacts**: Uploads gem file to release

### 3. `manual-test.yml` - Manual Testing
- **Trigger**: Manual workflow dispatch
- **Features**: 
  - Choose Ruby version (3.1, 3.2, 3.3)
  - Optional demo runs
  - Full CLI testing

## Ruby Version Support

### Supported Versions
- ✅ **Ruby 3.1**: Fully supported and tested
- ✅ **Ruby 3.2**: Fully supported and tested  
- ✅ **Ruby 3.3**: Fully supported and tested

### Requirements
- Minimum Ruby version: 3.1.0
- Minitest: ~> 5.20 (for Ruby 3.3+ compatibility)
- Additional gems for Ruby 3.3+: mutex_m (automatically included)

## Ruby Setup Issues

### Problem: Self-Hosted Runner Detection
```
Error: The current runner (ubuntu-24.04-x64) was detected as self-hosted
```

### Solutions:

#### Option 1: Use Updated Workflow (Recommended)
The `ruby.yml` workflow uses `ruby/setup-ruby@v1` which handles newer Ubuntu versions.

#### Option 2: Manual Ruby Installation (Self-Hosted Runners)
```bash
# Run the setup script
./scripts/setup-ruby-self-hosted.sh 3.3.0

# Or manually:
ruby-build 3.3.0 /opt/hostedtoolcache/Ruby/3.3.0/x64
touch /opt/hostedtoolcache/Ruby/3.3.0/x64.complete
```

#### Option 3: Use Different Runner
```yaml
runs-on: ubuntu-22.04  # Instead of ubuntu-latest
```
## Testing Locally

Before pushing, test locally:
```bash
# Run all tests
bundle exec rake test

# Build gem
bundle exec rake build

# Install and test CLI
bundle exec rake install_local
anki_generator help
```

## Release Process

1. **Update version** in `anki_generator.gemspec`
2. **Update CHANGELOG.md** with new version
3. **Commit changes**:
   ```bash
   git add .
   git commit -m "Bump version to 1.2.0"
   ```
4. **Create and push tag**:
   ```bash
   git tag v1.2.0
   git push origin v1.2.0
   ```
5. **GitHub Actions will**:
   - Run tests on Ruby 3.1, 3.2, 3.3
   - Build gem
   - Create GitHub release
   - Upload gem artifact

## Troubleshooting

### Ruby Version Issues
- Supported: Ruby 3.1, 3.2, 3.3
- Use `ruby scripts/debug-ruby-version.rb` to diagnose issues
- Ensure bundler compatibility

### Dependency Issues
- Run `bundle update` to update dependencies
- Check for security vulnerabilities: `bundle audit`

### Build Issues
- Ensure all files are included in gemspec
- Check for missing dependencies
- Verify executable permissions on scripts

## Best Practices

1. **Test locally** before pushing
2. **Use supported Ruby versions** (3.1-3.3)
3. **Update CHANGELOG.md** for each release
4. **Monitor CI pipeline** health regularly