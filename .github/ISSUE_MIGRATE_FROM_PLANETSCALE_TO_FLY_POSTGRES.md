# Migrate from PlanetScale to Fly Managed Postgres

## Summary

Migrate Trivia Advisor from PlanetScale database to Fly Managed Postgres to align with the Eventasaurus infrastructure and simplify our database architecture.

## Background

Trivia Advisor is a read-only application that displays trivia event data from the shared Eventasaurus database. Previously, we used PlanetScale for database hosting. Eventasaurus has already migrated to Fly Managed Postgres, so Trivia Advisor needs to follow suit to maintain a unified infrastructure.

### Current State (PlanetScale)

- **Environment Variables**: `PLANETSCALE_DATABASE_HOST`, `PLANETSCALE_DATABASE`, `PLANETSCALE_DATABASE_USERNAME`, `PLANETSCALE_DATABASE_PASSWORD`, `PLANETSCALE_PG_BOUNCER_PORT`
- **SSL**: Custom PlanetScale SSL configuration with `CAStore` and `server_name_indication`
- **Connection**: Hostname-based config with separate credentials
- **Networking**: IPv4 forced (`ECTO_IPV6` disabled)
- **Port**: 6432 (PgBouncer)

### Target State (Fly Managed Postgres)

- **Environment Variable**: Single `DATABASE_URL` connection string
- **SSL**: Standard Fly MPG SSL configuration (no special SSL opts needed for internal connections)
- **Connection**: URL-based config
- **Networking**: IPv6 for Fly internal network (`.flympg.net` domains)
- **Port**: Standard 5432 or PgBouncer port from connection string

## Critical: IPv6 and DNS Configuration

**IMPORTANT**: Fly Managed Postgres uses IPv6 internally and requires special DNS configuration. The Eventasaurus project has already solved these issues - we must replicate this configuration exactly.

### Key Learnings from Eventasaurus

1. **Erlang DNS Resolver Issue**: Erlang's built-in `inet_res` resolver doesn't read `/etc/resolv.conf` by default and fails with `nxdomain` on Fly.io's internal DNS for `.flympg.net` domains.

2. **Solution in `rel/env.sh.eex`**:
   ```bash
   # configure node for distributed erlang with IPV6 support
   # Also use native DNS resolver (getaddrinfo) instead of Erlang's inet_res
   # This fixes nxdomain errors for .flympg.net domains on Fly.io
   export ERL_AFLAGS="-proto_dist inet6_tcp -kernel inet_native_dns true"
   # Fly Managed Postgres uses IPv6 internally
   export ECTO_IPV6="true"
   ```

3. **Production DNS Fix in `runtime.exs`**:
   ```elixir
   # Configure Erlang's inet resolver to use Fly's internal DNS server
   if config_env() == :prod do
     fly_dns_server = {0xFDAA, 0, 0, 0, 0, 0, 0, 3}
     :inet_db.set_lookup([:dns, :file, :native])
     :inet_db.add_ns(fly_dns_server)
   end
   ```

4. **Socket Options**: All Repo configs must include `socket_options: [:inet6]`

## Development First Approach

**Before deploying to production, we must verify the database connection works in development mode.**

### Development Testing Strategy

1. **Option A - Use DATABASE_URL with local database**:
   - Set `DATABASE_URL` in `.env` pointing to local `eventasaurus_dev` database
   - This validates the URL-based configuration without needing Fly access

2. **Option B - Use Fly Proxy for remote access** (recommended for final testing):
   ```bash
   # Start proxy to Fly Managed Postgres
   fly proxy 15432:5432 -a eventasaurus-db

   # Then set DATABASE_URL in .env:
   # DATABASE_URL=postgres://user:pass@localhost:15432/eventasaurus
   ```

3. **Verify with `mix phx.server`** before any deployment

## Files Requiring Changes

### 1. `config/runtime.exs` (Major Changes)

**Changes needed:**
- Add Fly DNS configuration for production (lines 10-23 in Eventasaurus)
- Replace `PLANETSCALE_*` environment variables with `DATABASE_URL`
- Add `socket_options: [:inet6]` for Fly internal networking
- Keep `prepare: :unnamed` for PgBouncer compatibility
- Remove custom PlanetScale SSL opts (not needed for Fly internal connections)
- Update all comments and documentation

**Key addition - DNS fix for production:**
```elixir
if config_env() == :prod do
  # Fly's internal DNS server at fdaa::3 can resolve .flympg.net domains
  fly_dns_server = {0xFDAA, 0, 0, 0, 0, 0, 0, 3}
  :inet_db.set_lookup([:dns, :file, :native])
  :inet_db.add_ns(fly_dns_server)
end
```

### 2. `config/dev.exs` (Moderate Changes)

**Changes needed:**
- Remove PlanetScale-specific configuration (lines 8-88)
- Add support for `DATABASE_URL` environment variable
- Fallback to local database if `DATABASE_URL` not set
- Remove complex SSL configuration

**New dev config pattern:**
```elixir
# Load .env file for DATABASE_URL
if File.exists?(".env") do
  # ... load env vars
end

# Check for DATABASE_URL, fallback to local
database_url = System.get_env("DATABASE_URL")

if database_url do
  config :trivia_advisor, TriviaAdvisor.Repo,
    url: database_url,
    pool_size: 5,
    show_sensitive_data_on_connection_error: true
else
  # Local development database
  config :trivia_advisor, TriviaAdvisor.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "eventasaurus_dev",
    pool_size: 5,
    show_sensitive_data_on_connection_error: true
end
```

### 3. `config/test.exs` (Minor Changes)

**Changes needed:**
- Update comment on line 18 about PlanetScale
- No functional changes needed (already uses local database)

### 4. `lib/trivia_advisor/repo.ex` (Documentation Update)

**Changes needed:**
- Update `@moduledoc` documentation (lines 8-17)
- Replace "PlanetScale via PgBouncer" with "Fly Managed Postgres"
- Update description of production connection

### 5. `rel/env.sh.eex` (Critical Configuration)

**Changes needed:**
- Enable `ECTO_IPV6="true"`
- Add `-kernel inet_native_dns true` to ERL_AFLAGS
- Remove comment about PlanetScale needing IPv4

**Updated configuration:**
```bash
if [ -n "$FLY_APP_NAME" ]; then
  export DNS_CLUSTER_QUERY="${FLY_APP_NAME}.internal"
  export RELEASE_NODE="${FLY_APP_NAME}-${FLY_IMAGE_REF##*-}@${FLY_PRIVATE_IP}"
  # configure node for distributed erlang with IPV6 support
  # Also use native DNS resolver (getaddrinfo) instead of Erlang's inet_res
  # This fixes nxdomain errors for .flympg.net domains on Fly.io
  export ERL_AFLAGS="-proto_dist inet6_tcp -kernel inet_native_dns true"
  # Fly Managed Postgres uses IPv6 internally
  export ECTO_IPV6="true"
fi
```

### 6. `mix.exs` (Comment Update)

**Changes needed:**
- Update comment on line 71: "SSL certificate verification for PlanetScale"
- Change to: "SSL certificate verification for secure database connections"

### 7. `CACHE_AUDIT_PHASE1.md` (Optional Documentation Update)

**Changes needed:**
- Review for any PlanetScale-specific references
- Update if necessary

## Migration Plan

### Phase 1: Preparation

- [ ] Verify `DATABASE_URL` is available in Eventasaurus Fly secrets
- [ ] Document the correct `DATABASE_URL` format for Trivia Advisor
- [ ] Ensure local `eventasaurus_dev` database is accessible

### Phase 2: Code Changes (Development)

- [ ] Update `rel/env.sh.eex` with IPv6 and DNS fixes
- [ ] Update `config/dev.exs` with DATABASE_URL support
- [ ] Update `config/runtime.exs` with Fly MPG configuration
- [ ] Update `config/test.exs` comments
- [ ] Update `lib/trivia_advisor/repo.ex` documentation
- [ ] Update `mix.exs` comment

### Phase 3: Development Testing (MUST PASS BEFORE DEPLOY)

- [ ] Set `DATABASE_URL` in `.env` pointing to local database
- [ ] Run `mix phx.server` and verify pages load
- [ ] Check database queries execute successfully
- [ ] Verify no connection errors in console
- [ ] (Optional) Test with Fly proxy to remote database

### Phase 4: Production Deployment

- [ ] Set `DATABASE_URL` in Fly secrets for trivia-advisor app
- [ ] Deploy to production: `fly deploy -a trivia-advisor`
- [ ] Monitor logs for connection errors
- [ ] Verify all pages load correctly
- [ ] Check response times are acceptable

### Phase 5: Cleanup

- [ ] Remove old PlanetScale secrets from Fly
- [ ] Update any external documentation
- [ ] Close this issue

## Environment Variables

### To Add (Fly Secrets)

```bash
# Set via: fly secrets set DATABASE_URL="..." -a trivia-advisor
DATABASE_URL  # Connection string for Fly Managed Postgres (get from Eventasaurus secrets)
```

### To Remove (After Migration Verified)

```bash
# Remove via: fly secrets unset <VAR> -a trivia-advisor
PLANETSCALE_DATABASE_HOST
PLANETSCALE_DATABASE
PLANETSCALE_DATABASE_USERNAME
PLANETSCALE_DATABASE_PASSWORD
PLANETSCALE_PG_BOUNCER_PORT
```

## Configuration Reference

### Production Repo Configuration (Fly MPG)

```elixir
# config/runtime.exs - Production configuration
if config_env() == :prod do
  # DNS fix for Fly Managed Postgres
  fly_dns_server = {0xFDAA, 0, 0, 0, 0, 0, 0, 3}
  :inet_db.set_lookup([:dns, :file, :native])
  :inet_db.add_ns(fly_dns_server)
end

# Later in the file...
if config_env() == :prod do
  database_url = System.fetch_env!("DATABASE_URL")

  config :trivia_advisor, TriviaAdvisor.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5"),
    queue_target: 5000,
    queue_interval: 30000,
    # Disable prepared statements for PgBouncer Transaction mode
    prepare: :unnamed,
    # Force IPv6 for Fly.io internal network (.flympg.net resolves to IPv6)
    socket_options: [:inet6]
end
```

### Development Repo Configuration

```elixir
# config/dev.exs - Development configuration with DATABASE_URL support
database_url = System.get_env("DATABASE_URL")

if database_url do
  config :trivia_advisor, TriviaAdvisor.Repo,
    url: database_url,
    pool_size: 5,
    stacktrace: true,
    show_sensitive_data_on_connection_error: true
else
  config :trivia_advisor, TriviaAdvisor.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "eventasaurus_dev",
    pool_size: 5,
    stacktrace: true,
    show_sensitive_data_on_connection_error: true
end
```

## Rollback Plan

If the migration fails:

1. Revert code changes: `git revert <commit>`
2. Restore PlanetScale secrets: `fly secrets set PLANETSCALE_DATABASE_HOST=... -a trivia-advisor`
3. Deploy reverted code: `fly deploy -a trivia-advisor`
4. Verify connectivity to PlanetScale
5. Investigate failure cause before re-attempting migration

## Success Criteria

- [ ] `mix phx.server` runs successfully in development with new config
- [ ] Application starts successfully on Fly.io
- [ ] All LiveView pages render correctly
- [ ] Database queries execute without errors
- [ ] No `nxdomain` or DNS resolution errors
- [ ] No IPv6 connection errors
- [ ] Response times are comparable to or better than PlanetScale

## Common Issues and Solutions

### `nxdomain` errors for `.flympg.net`
**Cause**: Erlang's inet_res doesn't use system DNS resolver
**Solution**: Add `-kernel inet_native_dns true` to ERL_AFLAGS and DNS fix in runtime.exs

### Connection refused on IPv6
**Cause**: Missing `socket_options: [:inet6]` in Repo config
**Solution**: Add `socket_options: [:inet6]` to all Repo configurations

### SSL handshake errors
**Cause**: Using PlanetScale SSL opts with Fly MPG
**Solution**: Remove custom SSL opts - Fly internal connections don't need them

## Related Resources

- Eventasaurus Fly MPG configuration: `eventasaurus/config/runtime.exs`
- Eventasaurus DNS fix: `eventasaurus/rel/env.sh.eex`
- Fly Managed Postgres documentation: https://fly.io/docs/postgres/
- Ecto PostgreSQL configuration: https://hexdocs.pm/ecto_sql/Ecto.Adapters.Postgres.html

---

**Created:** 2025-01-22
**Priority:** High
**Estimated Effort:** 2-4 hours
**Risk Level:** Medium (read-only app, development-first approach)
