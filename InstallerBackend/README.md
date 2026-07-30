# SignFlow Installer Backend

Private Cloudflare Worker + R2 service that hosts short-lived signed IPAs for Apple OTA (`itms-services`) installation.

## Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/health` | No | Health / retention limits |
| `POST` | `/v1/releases` | Bearer | Create upload session |
| `PUT` | `/v1/releases/:id/parts/:n` | Bearer | Upload IPA chunk |
| `POST` | `/v1/releases/:id/complete` | Bearer | Assemble IPA, return install URL |
| `DELETE` | `/v1/releases/:id` | Bearer | Force delete release |
| `GET` | `/v1/d/:id/:token/manifest.plist` | Token | Apple OTA manifest |
| `GET` | `/v1/d/:id/:token/app.ipa` | Token | IPA download |

## Local development

```bash
cd InstallerBackend
npm install
npx wrangler login
npx wrangler secret put API_TOKEN
npm run dev
```

## Deploy

```bash
npx wrangler r2 bucket create signflow-releases
npx wrangler deploy
```

Releases expire after `RETENTION_HOURS` (default 6) and are cleaned by an hourly cron. IPA objects are also deleted shortly after the first successful download.
