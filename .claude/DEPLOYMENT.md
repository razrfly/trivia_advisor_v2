# Trivia Advisor V2 - Deployment Guide

## Prerequisites

- Elixir 1.18+ and Erlang/OTP 27+
- PostgreSQL 15.8+ with PostGIS 3.3+
- Node.js 18+ (for asset compilation)
- Read-only access to Eventasaurus database

## Environment Variables

### Required for Production

```bash
# Database connection (Supabase or standard PostgreSQL)
DATABASE_URL=postgresql://user:password@host:5432/database
# OR
SUPABASE_DATABASE_URL=postgresql://user:password@host:5432/database

# Secret key for signing cookies (generate with: mix phx.gen.secret)
SECRET_KEY_BASE=your_secret_key_base_here

# Production domain
PHX_HOST=quizadvisor.com

# Base URL for sitemap and SEO
BASE_URL=https://quizadvisor.com
```

### Optional Environment Variables

```bash
# HTTP port (default: 4000)
PORT=4000

# Database connection pool size (default: 10)
POOL_SIZE=10

# Enable IPv6 for database connections
ECTO_IPV6=false

# DNS cluster query for multi-node Erlang clustering
DNS_CLUSTER_QUERY=

# Enable Phoenix server for releases
PHX_SERVER=true
```

## Deployment Steps

### 1. Asset Compilation

Compile and digest static assets for production:

```bash
# Install dependencies
mix deps.get --only prod

# Compile assets
MIX_ENV=prod mix assets.deploy

# This runs:
# - mix tailwind trivia_advisor
# - mix esbuild trivia_advisor
# - mix phx.digest
```

### 2. Database Setup

**Important**: Trivia Advisor V2 is **read-only** and does not run migrations.

Ensure your database user has `pg_read_all_data` role:

```sql
-- Create read-only user (if needed)
CREATE USER trivia_advisor_readonly WITH PASSWORD 'your_password';
GRANT pg_read_all_data TO trivia_advisor_readonly;
GRANT CONNECT ON DATABASE your_database TO trivia_advisor_readonly;
```

### 3. Release Build

Build a production release:

```bash
# Set environment
export MIX_ENV=prod

# Build release
mix release

# The release will be in _build/prod/rel/trivia_advisor/
```

### 4. Running the Release

```bash
# Start the server
PHX_SERVER=true _build/prod/rel/trivia_advisor/bin/trivia_advisor start

# Or run in foreground (for Docker/systemd)
PHX_SERVER=true _build/prod/rel/trivia_advisor/bin/trivia_advisor start_iex
```

## Docker Deployment

### Dockerfile

```dockerfile
FROM elixir:1.18-alpine AS builder

# Install build dependencies
RUN apk add --no-cache build-base npm git

# Set working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \\
    mix local.rebar --force

# Install dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy application code
COPY . .

# Compile assets
RUN mix assets.deploy

# Compile release
ENV MIX_ENV=prod
RUN mix compile
RUN mix release

# Production image
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache openssl ncurses-libs libstdc++

WORKDIR /app

# Copy release from builder
COPY --from=builder /app/_build/prod/rel/trivia_advisor ./

# Set environment
ENV PHX_SERVER=true
ENV PORT=4000

EXPOSE 4000

# Start the release
CMD ["/app/bin/trivia_advisor", "start"]
```

### Docker Compose

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "4000:4000"
    environment:
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - DATABASE_URL=${DATABASE_URL}
      - PHX_HOST=${PHX_HOST}
      - BASE_URL=${BASE_URL}
      - PORT=4000
    restart: unless-stopped
```

## Platform-Specific Deployment

### Fly.io

1. Install flyctl: `curl -L https://fly.io/install.sh | sh`

2. Create app:
```bash
fly launch
```

3. Set secrets:
```bash
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
fly secrets set DATABASE_URL=your_database_url
fly secrets set PHX_HOST=your-app.fly.dev
fly secrets set BASE_URL=https://your-app.fly.dev
```

4. Deploy:
```bash
fly deploy
```

### Render

1. Create new Web Service on Render
2. Connect repository
3. Configure:
   - **Build Command**: `mix deps.get && mix assets.deploy && mix compile && mix release`
   - **Start Command**: `_build/prod/rel/trivia_advisor/bin/trivia_advisor start`
   - **Environment**: Add all required environment variables

### Heroku

1. Add buildpacks:
```bash
heroku buildpacks:add hashnuke/elixir
heroku buildpacks:add https://github.com/gjaldon/heroku-buildpack-phoenix-static
```

2. Set environment variables:
```bash
heroku config:set SECRET_KEY_BASE=$(mix phx.gen.secret)
heroku config:set DATABASE_URL=your_database_url
heroku config:set PHX_HOST=your-app.herokuapp.com
heroku config:set BASE_URL=https://your-app.herokuapp.com
```

3. Deploy:
```bash
git push heroku main
```

## Post-Deployment Checklist

### 1. Verify Application

- [ ] Application starts without errors
- [ ] Home page loads (`https://yourdomain.com/`)
- [ ] Database connection successful
- [ ] Sitemap generates (`https://yourdomain.com/sitemap.xml`)
- [ ] Robots.txt accessible (`https://yourdomain.com/robots.txt`)

### 2. Test Core Functionality

- [ ] Navigate to country page
- [ ] Navigate to city page
- [ ] Navigate to venue page
- [ ] Verify breadcrumb navigation
- [ ] Check empty states work correctly

### 3. SEO Verification

- [ ] View source and verify meta tags on all page types
- [ ] Verify JSON-LD structured data
- [ ] Test with Google Rich Results Test
- [ ] Submit sitemap to Google Search Console
- [ ] Verify canonical URLs

### 4. Performance Testing

- [ ] Test page load times (<3s on 3G)
- [ ] Verify asset compression (gzip enabled)
- [ ] Check SSL/TLS certificate
- [ ] Test HTTPS redirect
- [ ] Verify HSTS headers

### 5. Security Verification

- [ ] SSL/TLS enabled and valid
- [ ] HSTS headers present
- [ ] Security headers configured
- [ ] No sensitive data exposed in logs
- [ ] Database user has read-only access

### 6. Monitoring Setup

- [ ] Set up application monitoring (e.g., AppSignal, New Relic)
- [ ] Configure error tracking (e.g., Sentry, Honeybadger)
- [ ] Set up uptime monitoring
- [ ] Configure log aggregation
- [ ] Set up alerts for errors and downtime

## Rollback Procedure

### For Releases

```bash
# Stop current release
_build/prod/rel/trivia_advisor/bin/trivia_advisor stop

# Restore previous release version
# (Keep previous releases in deployment directory)

# Start previous release
PHX_SERVER=true _build/prod/rel/trivia_advisor/bin/trivia_advisor start
```

### For Platform Deployments

- **Fly.io**: `fly releases rollback`
- **Render**: Use dashboard to rollback to previous deploy
- **Heroku**: `heroku rollback`

## Health Checks

Health check endpoint is available at `/health` for load balancers and monitoring systems.

**Endpoint**: `GET /health`

**Response Codes**:
- `200 OK` - Application healthy, database connected
- `503 Service Unavailable` - Application unhealthy, database disconnected

**Example Healthy Response**:
```json
{
  "status": "healthy",
  "database": "connected",
  "timestamp": "2025-01-08T12:34:56Z"
}
```

**Example Unhealthy Response**:
```json
{
  "status": "unhealthy",
  "database": "disconnected",
  "error": "connection error details",
  "timestamp": "2025-01-08T12:34:56Z"
}
```

**Load Balancer Configuration**:
```yaml
# Example for AWS ALB
HealthCheck:
  Path: /health
  Interval: 30
  Timeout: 5
  HealthyThreshold: 2
  UnhealthyThreshold: 3
```

**Monitoring Integration**:
- Configure uptime monitoring to ping `/health` every 30-60 seconds
- Set up alerts when endpoint returns 503 or timeout
- Track response times for performance monitoring

## Monitoring and Observability

### Application Performance Monitoring (APM)

**AppSignal** (Recommended for Phoenix):
```elixir
# mix.exs
{:appsignal_phoenix, "~> 2.3"}

# config/prod.exs
config :appsignal, :config,
  otp_app: :trivia_advisor,
  name: "Trivia Advisor",
  push_api_key: System.get_env("APPSIGNAL_PUSH_API_KEY"),
  env: :prod,
  active: true

# lib/trivia_advisor_web/endpoint.ex (add to endpoint)
plug Appsignal.Phoenix.Plug
```

**New Relic**:
```elixir
# mix.exs
{:new_relic_agent, "~> 1.28"}

# config/prod.exs
config :new_relic_agent,
  app_name: "Trivia Advisor",
  license_key: System.get_env("NEW_RELIC_LICENSE_KEY")
```

### Error Tracking

**Sentry** (Recommended):
```elixir
# mix.exs
{:sentry, "~> 10.0"}

# config/prod.exs
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: :prod,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  tags: %{
    env: "production"
  }

# config/runtime.exs (add to endpoint config)
config :trivia_advisor, TriviaAdvisorWeb.Endpoint,
  # ... other config
  render_errors: [
    formats: [html: TriviaAdvisorWeb.ErrorHTML, json: TriviaAdvisorWeb.ErrorJSON],
    layout: false
  ]

# lib/trivia_advisor/application.ex (add to start/2)
{:ok, _} = Logger.add_backend(Sentry.LoggerBackend)
```

**Honeybadger**:
```elixir
# mix.exs
{:honeybadger, "~> 0.21"}

# config/prod.exs
config :honeybadger,
  api_key: System.get_env("HONEYBADGER_API_KEY"),
  environment_name: :prod,
  app: :trivia_advisor
```

### Uptime Monitoring

**UptimeRobot** (Free):
1. Create account at https://uptimerobot.com
2. Add HTTP(S) monitor: `https://quizadvisor.com/health`
3. Set interval: 5 minutes
4. Configure alerts: Email, SMS, Slack

**Pingdom**:
1. Create account at https://www.pingdom.com
2. Add uptime check: `https://quizadvisor.com/health`
3. Set check interval: 1 minute
4. Configure alert contacts

**Better Uptime**:
1. Create account at https://betteruptime.com
2. Add monitor: `https://quizadvisor.com/health`
3. Configure on-call schedule
4. Set up status page

### Log Aggregation

**Papertrail** (Simple log aggregation):
```bash
# Install syslog drain
heroku drains:add syslog+tls://logs.papertrailapp.com:PORT

# Or configure in render.yaml
services:
  - type: web
    env: docker
    logging:
      type: syslog
      destination: logs.papertrailapp.com:PORT
```

**Logtail** (Structured logging):
```elixir
# mix.exs
{:logtail, "~> 0.11"}

# config/prod.exs
config :logger,
  backends: [Logtail]

config :logtail,
  source_token: System.get_env("LOGTAIL_SOURCE_TOKEN")
```

### Performance Monitoring

**Phoenix LiveDashboard** (Development/Staging only):
```elixir
# mix.exs
{:phoenix_live_dashboard, "~> 0.8"}

# router.ex (behind authentication in production)
scope "/" do
  pipe_through [:browser, :auth]
  live_dashboard "/dashboard", metrics: TriviaAdvisorWeb.Telemetry
end
```

**Custom Telemetry Events**:
```elixir
# lib/trivia_advisor_web/telemetry.ex
defmodule TriviaAdvisorWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("trivia_advisor.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "Total query time"
      ),

      # LiveView Metrics
      summary("phoenix.live_view.mount.stop.duration",
        unit: {:native, :millisecond}
      ),

      # Custom Business Metrics
      counter("trivia_advisor.venue.views"),
      counter("trivia_advisor.city.views")
    ]
  end
end
```

### Alert Configuration

**Critical Alerts** (Immediate notification):
- Application down (health check fails)
- Database connection lost
- Error rate >5% of requests
- Response time >3 seconds (p95)

**Warning Alerts** (15-minute delay):
- Error rate >1% of requests
- Response time >2 seconds (p95)
- Memory usage >80%
- Database connection pool >80% utilization

**Info Alerts** (1-hour summary):
- Deployment completed
- Configuration changed
- New errors detected (first occurrence)

### Monitoring Checklist

After deployment, verify:

- [ ] Health check endpoint returns 200 OK
- [ ] APM tool receiving metrics and traces
- [ ] Error tracking capturing exceptions
- [ ] Uptime monitoring configured and working
- [ ] Log aggregation receiving application logs
- [ ] Alert notifications delivered to correct channels
- [ ] Dashboard accessible and showing live data
- [ ] Performance metrics within acceptable ranges
- [ ] Database query performance tracked
- [ ] LiveView mount times monitored

## Troubleshooting

### Database Connection Issues

```bash
# Test database connection
psql $DATABASE_URL

# Verify read permissions
SELECT has_table_privilege('pg_read_all_data', 'countries', 'SELECT');
```

### Asset Issues

```bash
# Clear and rebuild assets
rm -rf priv/static
MIX_ENV=prod mix assets.deploy
```

### Release Not Starting

```bash
# Check logs
tail -f /var/log/trivia_advisor.log

# Or if using systemd
journalctl -u trivia_advisor -f
```

## Support

For deployment issues, check:
1. Application logs
2. Database connection
3. Environment variables
4. Port availability
5. SSL certificate validity
