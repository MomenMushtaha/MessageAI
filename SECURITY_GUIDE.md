# Security Guide for MessageAI

This document outlines security best practices and how to properly configure sensitive data in the MessageAI project.

## Table of Contents
1. [API Keys and Secrets Management](#api-keys-and-secrets-management)
2. [Firebase Configuration](#firebase-configuration)
3. [Git Security](#git-security)
4. [Best Practices](#best-practices)
5. [Security Checklist](#security-checklist)

## API Keys and Secrets Management

### OpenAI API Key Configuration

The OpenAI API key should NEVER be committed to version control. Follow these steps to configure it properly:

#### Option 1: Using Info.plist (Recommended for Xcode)

1. Open your `Info.plist` file in Xcode
2. Add a new key `OPENAI_API_KEY` with your actual API key as the value
3. Make sure `Info.plist` is in your `.gitignore` if it contains secrets

#### Option 2: Using Config.xcconfig

1. Copy `Config.example.xcconfig` to `Config.xcconfig`:
   ```bash
   cp Config.example.xcconfig Config.xcconfig
   ```

2. Edit `Config.xcconfig` and replace `YOUR_OPENAI_API_KEY_HERE` with your actual API key

3. In Xcode, go to your project settings:
   - Select your target
   - Go to Build Settings
   - Search for "Info.plist Preprocessor"
   - Add `$(OPENAI_API_KEY)` from your config file

**IMPORTANT:**
- `Config.xcconfig` is already in `.gitignore` and should NEVER be committed
- `Config.example.xcconfig` is safe to commit as it contains no real secrets

### Environment Variables

For development and testing, you can also use environment variables:

```bash
export OPENAI_API_KEY="your-actual-api-key"
```

## Firebase Configuration

### GoogleService-Info.plist

The `GoogleService-Info.plist` file contains your Firebase project configuration. While Firebase client API keys are designed to be included in apps, you should still protect this file from public repositories.

**Current Status:**
- ✅ `GoogleService-Info.plist` is in `.gitignore`
- ✅ File is NOT tracked by git
- ✅ Safe from accidental commits

**Security Measures:**

1. **API Key Restrictions (Recommended):**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Navigate to APIs & Services > Credentials
   - Find your iOS API key
   - Add restrictions:
     - **Application restrictions:** iOS apps
     - **Bundle ID:** `com.gauntletai.messagingai` or `com.gauntletai.messageAI`
     - **API restrictions:** Limit to required Firebase APIs only

2. **Firebase Security Rules:**
   - Ensure your Firestore and Storage rules require authentication
   - Never allow public read/write access in production
   - Review rules regularly

## Git Security

### What's Protected

Your `.gitignore` currently protects:

```
# Sensitive data
Config.plist
secrets.plist
ApiKeys.plist
GoogleService-Info.plist
Config.xcconfig
```

### Verify No Secrets in Git History

Run these commands periodically to check for accidentally committed secrets:

```bash
# Check for sensitive files in history
git log --all --pretty=format: --name-only --diff-filter=A | sort -u | grep -E '(\.env|credentials|secrets|\.pem|\.key)'

# Search for API key patterns
git log -p --all -S 'AKIA' # AWS keys
git log -p --all -S 'sk-'  # OpenAI keys
```

### Pre-commit Hook (Optional but Recommended)

Install `gitleaks` to prevent accidental secret commits:

```bash
# Install gitleaks
brew install gitleaks

# Add to your pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
gitleaks detect --staged --verbose --no-git
if [ $? -eq 1 ]; then
    echo "❌ Gitleaks detected secrets in your commit!"
    echo "Please remove them before committing."
    exit 1
fi
EOF

chmod +x .git/hooks/pre-commit
```

## Best Practices

### 1. Never Hardcode Secrets

❌ **BAD:**
```swift
let apiKey = "sk-1234567890abcdef"
```

✅ **GOOD:**
```swift
let apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String
```

### 2. Use Different Keys for Different Environments

- Development keys for testing
- Production keys for release
- Rotate keys if compromised

### 3. Minimum Privilege Principle

- Only grant necessary permissions to API keys
- Use Firebase security rules to restrict access
- Implement server-side validation for critical operations

### 4. Regular Security Audits

Run security checks monthly:

```bash
# Check for exposed secrets in codebase
grep -r "api[_-]?key\|secret\|password" --include="*.swift" .

# Review git ignore effectiveness
git ls-files | grep -i "secret\|credential\|config"
```

### 5. Dependency Security

Regularly update dependencies and check for vulnerabilities:

```bash
# Check for outdated pods (if using CocoaPods)
pod outdated

# Review security advisories for your dependencies
```

## Security Checklist

Before deploying or making repository public:

- [ ] No hardcoded API keys in source code
- [ ] `GoogleService-Info.plist` is in `.gitignore`
- [ ] `Config.xcconfig` is in `.gitignore`
- [ ] Firebase API keys have proper restrictions
- [ ] Firestore security rules are properly configured
- [ ] Storage security rules are properly configured
- [ ] All test passwords are placeholders
- [ ] No real credentials in test files
- [ ] Git history doesn't contain secrets
- [ ] `.env` files (if any) are in `.gitignore`
- [ ] Pre-commit hooks are set up (optional)
- [ ] Team members are trained on security practices

## If You Accidentally Commit a Secret

1. **Immediately rotate/revoke the compromised key**
2. **Remove from git history:**
   ```bash
   # Using git filter-branch (for small repos)
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch path/to/secret/file" \
     --prune-empty --tag-name-filter cat -- --all

   # Force push (if already pushed)
   git push origin --force --all
   ```

3. **Alternative: Use BFG Repo-Cleaner** (faster for large repos)
   ```bash
   brew install bfg
   bfg --delete-files secret-file.txt
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   ```

4. **Verify the secret is gone:**
   ```bash
   git log --all --full-history -- path/to/secret/file
   ```

## Additional Resources

- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Firebase Security Best Practices](https://firebase.google.com/docs/rules/best-practices)
- [Apple Security Guidelines](https://developer.apple.com/security/)
- [Git Security](https://git-scm.com/book/en/v2/Git-Tools-Credential-Storage)

## Support

If you discover a security vulnerability, please:
1. Do NOT open a public issue
2. Contact the development team directly
3. Provide details of the vulnerability
4. Allow time for a fix before public disclosure

---

**Last Updated:** 2025-10-23
**Security Contact:** [Your security contact email]
