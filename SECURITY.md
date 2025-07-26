# Security Policy

## Supported Versions

We support security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this homelab infrastructure project, please report it responsibly:

### For Security Issues:

1. **Do NOT create a public GitHub issue** for security vulnerabilities
2. **Email the maintainer** directly with details
3. **Include the following information**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fixes (if any)

### What to Expect:

- **Acknowledgment** within 48 hours
- **Initial assessment** within 7 days
- **Regular updates** on remediation progress
- **Public disclosure** only after fix is available

## Security Measures in Place

### Automated Security Scanning:
- **CodeQL** - Static code analysis for Python
- **Bandit** - Python security linter
- **Safety** - Python dependency vulnerability scanning
- **Trivy** - Infrastructure as Code security scanning
- **Checkov** - Terraform security analysis
- **TruffleHog** - Secret scanning
- **Dependabot** - Automated dependency updates

### Security Best Practices:
- No secrets committed to repository
- All credentials stored in gitignored files
- Terraform state contains prevent_destroy guards
- Network access restricted to known hosts
- Regular security updates via Dependabot

### Infrastructure Security:
- Proxmox API access over HTTPS
- K3s cluster with RBAC enabled
- Network segmentation via VLANs
- Regular security monitoring and health checks

## Scope

This security policy covers:
- Infrastructure as Code (Terraform)
- Discovery and automation scripts (Python)
- CI/CD workflows (GitHub Actions)
- Configuration files and templates

**Out of Scope:**
- Vulnerabilities in third-party dependencies (report to upstream)
- Issues in Proxmox or K3s themselves (report to respective projects)
- General homelab security advice

## Security Contacts

For security-related questions or to report vulnerabilities:
- **Primary Contact**: Repository owner
- **Response Time**: Within 48 hours
- **Encryption**: PGP key available upon request