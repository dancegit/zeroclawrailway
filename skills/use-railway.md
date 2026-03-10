# Railway Self-Management

This skill allows ZeroClaw to manage its own Railway deployment.

## Authentication

The service is authenticated via `RAILWAY_TOKEN` environment variable (project-scoped token).

## Service Identity

This service can identify itself:
- Project ID: Set via `RAILWAY_PROJECT_ID` env var (or auto-detected from token)
- Service Name: Set via `ZEROCLAW_SERVICE_NAME` env var
- Environment: Set via `RAILWAY_ENVIRONMENT` env var (default: `production`)

## Available Commands

### Check Status

```bash
railway status --json
railway whoami --json
```

### View Logs

```bash
railway logs --lines 100
railway logs --build --lines 50
```

### Redeploy Self

```bash
railway up --detach -m "Automated redeploy"
railway redeploy
```

### Manage Variables

```bash
railway variable list --json
railway variable set KEY=value
railway variable delete KEY
```

### Environment Info

```bash
railway environment
railway domain
```

## Important Constraints

**This token is PROJECT-SCOPED. You can ONLY:**
- Deploy/redeploy services in this project
- View and modify variables for this project
- View logs and status for this project
- Manage domains for this project

**You CANNOT:**
- Access other Railway projects
- Create new projects or services
- Delete the project
- Access workspace-level settings

## Redeployment Workflow

When the user asks you to redeploy yourself:

1. **Check current status:**
   ```bash
   railway status --json
   ```

2. **Pull latest code (if using GitHub integration):**
   ```bash
   railway redeploy
   ```

3. **Or deploy from image:**
   ```bash
   railway up --detach -m "Redeploy triggered by ZeroClaw"
   ```

4. **Verify deployment:**
   ```bash
   railway logs --lines 20
   ```

## Creating a Project Token

To create a project token for this service:

1. Go to Railway Dashboard: https://railway.com/dashboard
2. Navigate to your project → Settings → Tokens
3. Click "Create Token"
4. Select the environment (e.g., `production`)
5. Copy the token and set it as `RAILWAY_TOKEN` environment variable

## Example: Self-Update Scenario

```
User: "Can you update yourself to use the latest image?"

ZeroClaw:
1. Checks railway status
2. Redeploys: railway redeploy
3. Monitors logs for successful startup
4. Reports: "Redeployment complete. New deployment is live."
```

## Troubleshooting

### Token Not Working

```bash
railway whoami --json
# If this fails, the token is invalid or expired
```

### Deployment Stuck

```bash
railway logs --build --lines 100
# Check for build errors
```

### Service Unhealthy

```bash
railway logs --lines 200
railway status --json
```

## API Access (Advanced)

For operations not supported by CLI, use the Railway GraphQL API:

```bash
curl --request POST \
  --url https://backboard.railway.com/graphql/v2 \
  --header "Project-Access-Token: $RAILWAY_TOKEN" \
  --header 'Content-Type: application/json' \
  --data '{"query":"query { projectToken { projectId environmentId } }"}'
```
