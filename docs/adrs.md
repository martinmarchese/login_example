# Architecture Decision Record: Authentication Library Selection

## Status

Accepted

## Context

We are building a Rails application that requires authentication for both API and web access. The application needs a simple User entity with basic fields (name, email) and must support the following requirements:

**Current Requirements:**
- Email/password authentication for both API and web interfaces
- User registration and login
- User deletion endpoint (API only)
- Simple web interface with sign-in form
- Post-login redirect to personalized welcome screen
- Sign-out functionality

**Future Requirements:**
- Email verification upon sign-up
- Password reset/recovery flow
- Multi-factor authentication (MFA/2FA) support
- Social login (OAuth providers like Google, Facebook)
- Role-based access control (e.g., admin users, normal users)

**Technical Constraints:**
- Ruby on Rails framework
- Both API and web access must be supported
- Code reuse between API and web implementations following Rails best practices
- Tailwind CSS for styling
- Modular design to easily add features over time

### Alternatives Considered

We evaluated four authentication solutions for Rails:

#### 1. Rodauth
**Description:** A comprehensive authentication framework built on Roda and Sequel, with Rails integration via `rodauth-rails` gem.

**Pros:**
- Excellent built-in support for both API (JWT/JSON) and web (session) authentication
- Native support for email verification and password reset
- Best-in-class MFA support (TOTP, SMS codes, recovery codes, WebAuthn/passkeys)
- Social login support via `rodauth-omniauth` gem
- Maximum security by default with HMAC token protection
- Modular design - enable only features you need
- All features work seamlessly with both API and web
- Complete UI templates included (customizable)

**Cons:**
- Uses Sequel for database operations (though configured to reuse Active Record connections)
- Less mainstream than Devise
- Slightly different architecture than typical Rails auth

**Documentation:**
- Main site: https://rodauth.jeremyevans.net/
- Rails integration: https://github.com/janko/rodauth-rails

#### 2. Devise + Extensions
**Description:** The most popular Rails authentication solution with modular design.

**Pros:**
- Most widely used, extensive community and documentation
- Built-in modules for confirmable (email verification) and recoverable (password reset)
- Works with OmniAuth for social login
- Well-documented patterns with Pundit/CanCanCan for authorization
- Large ecosystem of extensions

**Cons:**
- Using both API and web authentication requires additional configuration complexity
- MFA requires external gem (devise-two-factor) with manual UI implementation
- Heavier dependency footprint
- More opinionated, harder to customize
- Potential security issues with token leakage in logs (needs configuration)

**Documentation:**
- Main gem: https://github.com/heartcombo/devise
- MFA extension: https://github.com/devise-two-factor/devise-two-factor

#### 3. has_secure_password (Rails Built-in)
**Description:** Minimal password authentication built into Rails using BCrypt.

**Pros:**
- Built into Rails, no external dependencies (except bcrypt gem)
- Full control over implementation
- Lightweight
- Rails 7.1+ added password reset token support

**Cons:**
- Manual implementation required for all features
- No built-in email verification
- No built-in MFA support
- No built-in social login support
- Must build all UI, routes, mailers, and controllers manually
- Most work required for current and future features

**Documentation:**
- Rails API: https://api.rubyonrails.org/classes/ActiveModel/SecurePassword/ClassMethods.html

#### 4. Authentication Zero (Rails 8+)
**Description:** Generator-based approach that creates authentication code following Rails best practices.

**Pros:**
- Modern Rails 8+ approach
- Password reset included in generated code
- You own the generated code
- Built-in 2FA support with flags

**Cons:**
- Rails 8+ only
- Email verification not included by default
- Social login must be added manually
- Newer solution with smaller community
- Modifications after generation can be complex

**Documentation:**
- GitHub: https://github.com/lazaronixon/authentication-zero

### Feature Comparison Matrix

| Feature | Rodauth | Devise | has_secure_password | Auth Zero (Rails 8) |
|---------|---------|--------|-------------------|-------------------|
| **Email Verification** | ✅ Built-in | ✅ Built-in (`:confirmable`) | ❌ Build manually | ⚠️ Build manually |
| **Password Reset** | ✅ Built-in | ✅ Built-in (`:recoverable`) | ⚠️ Token helper only | ✅ Generated |
| **MFA/2FA** | ✅ Excellent (TOTP, SMS, WebAuthn) | ⚠️ External gem needed | ❌ Build manually | ⚠️ Flag available |
| **Social Login** | ✅ rodauth-omniauth gem | ✅ OmniAuth integration | ❌ Build manually | ❌ Build manually |
| **Roles/Authorization** | Use Pundit/CanCanCan | Use Pundit/CanCanCan | Use Pundit/CanCanCan | Use Pundit/CanCanCan |
| **API + Web Together** | ✅ Excellent | ⚠️ Requires configuration | ⚠️ Manual work | ✅ Good |
| **Setup Complexity** | Low (generator) | Medium | High (all manual) | Low (generator) |
| **Security Features** | ✅ Excellent (HMAC, etc.) | ✅ Good | ⚠️ Basic | ✅ Good |
| **Maintenance** | Active | Active | Rails core | Rails 8+ only |
| **Community Size** | Medium | Very Large | N/A | Small |

## Decision

We will use **Rodauth** with the `rodauth-rails` integration gem as our authentication solution.

**Rationale:**

1. **Complete Feature Set**: Rodauth provides built-in, production-ready solutions for all our current and future requirements, minimizing custom code and potential security issues.

2. **API + Web Excellence**: Unlike other solutions, Rodauth natively handles both API (JWT/JSON) and web (session-based) authentication seamlessly without additional configuration.

3. **Future-Proof**: The modular design allows us to add features (MFA, social login, email verification) with simple configuration changes rather than architectural refactoring.

4. **Security First**: Rodauth ships with maximum security by default, including HMAC token protection, timing-safe comparisons, and secure token generation.

5. **Maintainability**: All authentication logic is centralized in a single configuration file, making it easier to understand and modify compared to scattered controllers and models.

6. **Best MFA Support**: When we need to add MFA, Rodauth's built-in support for multiple methods (TOTP, SMS, WebAuthn) with complete UI templates will save significant development time.

## Consequences

### Positive

- **Rapid Implementation**: Built-in features for email verification, password reset, and login/logout mean faster time to market.

- **Reduced Security Risk**: Battle-tested authentication flows with secure defaults reduce the likelihood of security vulnerabilities.

- **Easy Feature Addition**: Future requirements (MFA, social login, roles) can be added incrementally without architectural changes.

- **Code Reuse**: Single configuration serves both API and web interfaces, reducing duplication and maintenance burden.

- **Comprehensive Documentation**: While less mainstream than Devise, Rodauth has excellent documentation and a supportive maintainer.

### Negative

- **Learning Curve**: Team members familiar with Devise will need to learn Rodauth's patterns and configuration DSL.

- **Sequel Usage**: Rodauth uses Sequel for database operations, though `rodauth-rails` configures it to reuse Active Record connections, so this is mostly transparent.

- **Smaller Community**: Fewer Stack Overflow answers and third-party tutorials compared to Devise, though official documentation is comprehensive.

- **Different Architecture**: Authentication handled via Roda middleware rather than traditional Rails controllers, which may be unfamiliar initially.

### Mitigation Strategies

- **Documentation**: Create internal documentation for common Rodauth patterns and configurations specific to our application.

- **Training**: Allocate time for team members to review Rodauth documentation and understand its architecture.

- **Gradual Adoption**: Start with basic features (login/logout) and add complexity incrementally as team becomes comfortable.

- **Community Engagement**: Leverage Rodauth's GitHub issues and maintainer support for questions and guidance.

## Implementation Notes

The User model will have the following fields:
- `name`: string
- `email`: string
- Additional Rodauth fields (e.g., `status`, `password_hash`) added via migrations

Authorization (roles) will be handled separately using Pundit or CanCanCan, following the standard Rails pattern of separating authentication from authorization.

For detailed implementation steps, see `IMPLEMENTATION.md`.

## References

- Rodauth documentation: https://rodauth.jeremyevans.net/
- Rodauth-Rails gem: https://github.com/janko/rodauth-rails
- Rodauth-OmniAuth (future): https://github.com/janko/rodauth-omniauth
- Multifactor Authentication tutorial: https://janko.io/adding-multifactor-authentication-in-rails-with-rodauth/
- Social Login tutorial: https://janko.io/social-login-in-rails-with-rodauth/
