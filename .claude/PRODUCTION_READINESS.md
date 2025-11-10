# Trivia Advisor V2 - Production Readiness Checklist

This checklist ensures Trivia Advisor V2 is production-ready before launch.

## 1. Configuration

### Environment Variables
- [ ] `SECRET_KEY_BASE` generated (use `mix phx.gen.secret`)
- [ ] `DATABASE_URL` or `SUPABASE_DATABASE_URL` configured
- [ ] `PHX_HOST` set to production domain (quizadvisor.com)
- [ ] `BASE_URL` set to https://quizadvisor.com
- [ ] `PORT` configured (default: 4000)
- [ ] `POOL_SIZE` set appropriately (default: 10, adjust for load)
- [ ] `PHX_SERVER=true` for release mode
- [ ] All environment variables validated in production environment

### Configuration Files
- [ ] `config/prod.exs` - Force SSL enabled with HSTS
- [ ] `config/prod.exs` - Gzip compression enabled
- [ ] `config/prod.exs` - Debug features disabled
- [ ] `config/runtime.exs` - Production database configuration
- [ ] `config/runtime.exs` - Base URL configuration

## 2. Database

### Connection
- [ ] Database connection successful
- [ ] Read-only user permissions verified (`pg_read_all_data` role)
- [ ] Connection pool size appropriate for expected load
- [ ] Database timezone configuration verified
- [ ] PostGIS extension available and working

### Schema Verification
- [ ] Countries table accessible
- [ ] Cities table accessible
- [ ] Venues table accessible
- [ ] Public_events table accessible
- [ ] All required columns present and correct types
- [ ] JSONB fields (occurrences, metadata) queryable

### Query Performance
- [ ] Country queries <100ms
- [ ] City queries <200ms
- [ ] Venue queries <200ms
- [ ] Event queries <300ms
- [ ] PostGIS spatial queries <500ms
- [ ] Database connection pooling working correctly

## 3. Application Build

### Assets
- [ ] Tailwind CSS compiled successfully
- [ ] JavaScript bundled with esbuild
- [ ] Static assets digested (cache manifest generated)
- [ ] Asset paths use digest hashes
- [ ] Favicon and images present in priv/static
- [ ] All CSS/JS loaded without 404 errors

### Release
- [ ] Mix dependencies fetched (prod only)
- [ ] Application compiles without warnings
- [ ] Release built successfully (`mix release`)
- [ ] Release starts without errors
- [ ] Environment variables loaded correctly
- [ ] Config.runtime loads all required settings

## 4. Routes & Pages

### Static Pages
- [ ] `/` (Home) loads successfully
- [ ] `/about` loads successfully
- [ ] `/sitemap.xml` generates valid XML
- [ ] `/robots.txt` accessible and correct
- [ ] `/health` returns 200 OK

### Dynamic Routes
- [ ] `/:country_slug` works (e.g., /united-states)
- [ ] `/:country_slug/:city_slug` works (e.g., /united-states/new-york)
- [ ] `/:country_slug/:city_slug/:venue_slug` works
- [ ] All routes preserve V1 URL patterns
- [ ] Breadcrumb navigation works on all pages
- [ ] 404 handling works for invalid slugs

### Components
- [ ] Header displays correctly
- [ ] Footer displays correctly
- [ ] City cards render properly
- [ ] Venue cards render properly
- [ ] Event cards show occurrences
- [ ] Empty states display when no data
- [ ] All images load correctly
- [ ] Icons (Heroicons) render

## 5. SEO

### Meta Tags
- [ ] Every page has unique `<title>`
- [ ] Every page has meta description
- [ ] Canonical URLs present on all pages
- [ ] OpenGraph tags complete (title, description, url, type, site_name)
- [ ] Twitter Card tags present
- [ ] Geo tags on city and venue pages

### Structured Data
- [ ] BreadcrumbList JSON-LD on all pages
- [ ] Event schema on venue pages with events
- [ ] LocalBusiness schema on venue pages
- [ ] All JSON-LD validates with Google Rich Results Test
- [ ] Schema.org types correct (@context, @type)

### Sitemap
- [ ] Sitemap generates all URLs (6,976+ expected)
- [ ] Static pages included (/, /about)
- [ ] All country pages included
- [ ] All city pages included
- [ ] All venue pages included
- [ ] lastmod dates from database
- [ ] Priority scores appropriate (0.7-1.0)
- [ ] Change frequency set correctly
- [ ] robots.txt points to sitemap

## 6. Security

### SSL/TLS
- [ ] HTTPS enforced (force_ssl configured)
- [ ] HSTS headers present
- [ ] HTTP redirects to HTTPS
- [ ] SSL certificate valid and not expired
- [ ] TLS 1.2+ only (no SSL 2/3, TLS 1.0/1.1)

### Headers
- [ ] X-Frame-Options set
- [ ] X-Content-Type-Options set
- [ ] X-XSS-Protection set
- [ ] Content-Security-Policy configured
- [ ] Referrer-Policy set

### Database Security
- [ ] Database user has read-only permissions only
- [ ] No migrations run in production
- [ ] Connection uses SSL/TLS
- [ ] Database password stored securely (env vars, not code)
- [ ] No sensitive data in logs

### Application Security
- [ ] CSRF protection enabled
- [ ] Session security configured
- [ ] Secrets not committed to git (.env.example only)
- [ ] Dependencies scanned for vulnerabilities (`mix audit`)
- [ ] No debug/development features enabled in production

## 7. Performance

### Load Times
- [ ] Home page loads <3s on 3G
- [ ] City pages load <3s on 3G
- [ ] Venue pages load <3s on 3G
- [ ] API responses <500ms (health check)
- [ ] Static assets served with cache headers
- [ ] Gzip compression working

### Resource Usage
- [ ] Memory usage stable (<500MB for typical load)
- [ ] CPU usage reasonable (<30% average)
- [ ] Database connection pool not exhausted
- [ ] No memory leaks detected
- [ ] Process count stable

### Optimization
- [ ] Static assets cached (max-age headers)
- [ ] Database queries optimized (no N+1 queries)
- [ ] LiveView mounts efficiently (<500ms)
- [ ] Preloading associations where needed
- [ ] Query result limits prevent large result sets

## 8. Monitoring & Observability

### Health Checks
- [ ] `/health` endpoint returns 200 OK
- [ ] Health check verifies database connectivity
- [ ] Load balancer configured to use health check
- [ ] Health check response time <100ms

### Error Tracking
- [ ] Error tracking service configured (Sentry/Honeybadger)
- [ ] Test error sent and received
- [ ] Error notifications configured
- [ ] Source maps enabled for better stack traces
- [ ] Environment and release tags set

### Application Performance Monitoring
- [ ] APM tool configured (AppSignal/New Relic)
- [ ] Metrics reporting correctly
- [ ] Transaction traces visible
- [ ] Database query monitoring working
- [ ] LiveView mount/update times tracked

### Uptime Monitoring
- [ ] Uptime monitoring configured (UptimeRobot/Pingdom)
- [ ] Health check endpoint monitored
- [ ] Alert notifications configured
- [ ] Status page available (optional)
- [ ] Check interval appropriate (1-5 minutes)

### Logging
- [ ] Application logs aggregated (Papertrail/Logtail)
- [ ] Log level set to :info in production
- [ ] No sensitive data logged
- [ ] Structured logging configured
- [ ] Log retention policy set

## 9. Deployment Process

### Pre-Deployment
- [ ] Code reviewed and approved
- [ ] All tests passing
- [ ] Staging environment tested
- [ ] Database backup verified
- [ ] Rollback plan documented

### Deployment
- [ ] Assets compiled (`mix assets.deploy`)
- [ ] Dependencies installed (prod only)
- [ ] Release built successfully
- [ ] Environment variables set
- [ ] Database connectivity verified
- [ ] Application starts without errors

### Post-Deployment
- [ ] Application accessible at production URL
- [ ] Health check returns 200 OK
- [ ] Sample pages load correctly
- [ ] Sitemap generates successfully
- [ ] SEO meta tags present
- [ ] Error tracking receiving data
- [ ] APM metrics flowing
- [ ] Logs aggregating correctly

### Validation
- [ ] Load test completed (optional but recommended)
- [ ] Error rate <0.1%
- [ ] Response times within targets
- [ ] Memory usage stable
- [ ] No errors in logs (first 30 minutes)

## 10. Documentation

### Internal Documentation
- [ ] Deployment process documented
- [ ] Environment variables documented
- [ ] Rollback procedure documented
- [ ] Monitoring setup documented
- [ ] Incident response plan created
- [ ] On-call rotation defined (if applicable)

### External Documentation
- [ ] README.md updated
- [ ] API documentation current (if applicable)
- [ ] User-facing documentation updated
- [ ] Status page configured
- [ ] Support contact information published

## 11. Business Readiness

### SEO Migration
- [ ] All V1 URLs preserved in V2
- [ ] 301 redirects configured (if needed)
- [ ] Sitemap submitted to Google Search Console
- [ ] Sitemap submitted to Bing Webmaster Tools
- [ ] Robots.txt updated and verified
- [ ] Schema markup validated

### Analytics
- [ ] Google Analytics 4 configured
- [ ] Event tracking implemented
- [ ] Conversion tracking set up
- [ ] Custom dashboards created
- [ ] Goals defined and tracked

### Legal & Compliance
- [ ] Privacy policy updated
- [ ] Terms of service current
- [ ] Cookie consent implemented (if applicable)
- [ ] GDPR compliance verified (if applicable)
- [ ] Data retention policy documented

## 12. Final Verification

### Smoke Tests
- [ ] Navigate to home page
- [ ] Search for a city
- [ ] View city page
- [ ] View venue page
- [ ] Check event occurrences display
- [ ] Verify breadcrumb navigation
- [ ] Test empty states (no events scenario)
- [ ] Verify footer links work

### Cross-Browser Testing
- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Edge (latest)
- [ ] Mobile Safari (iOS)
- [ ] Chrome Mobile (Android)

### Accessibility
- [ ] Keyboard navigation works
- [ ] Screen reader compatible
- [ ] Color contrast sufficient
- [ ] Images have alt text
- [ ] Forms have labels
- [ ] ARIA attributes present where needed

### Performance Budgets
- [ ] Lighthouse score >90 (performance)
- [ ] Lighthouse score >90 (accessibility)
- [ ] Lighthouse score >90 (best practices)
- [ ] Lighthouse score >90 (SEO)
- [ ] Core Web Vitals passing (LCP, FID, CLS)

## Sign-Off

**Checklist Completed By**: ___________________
**Date**: ___________________
**Ready for Production**: [ ] Yes [ ] No

**Notes**:
_______________________________________________________________________
_______________________________________________________________________
_______________________________________________________________________

**Production Deployment Date**: ___________________
**Deployed By**: ___________________
