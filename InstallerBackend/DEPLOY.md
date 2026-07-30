# Cloudflare Deploy Checklist

SignFlow's OTA installer is ready in `InstallerBackend/`. This machine is not logged into Cloudflare yet.

## One-time setup

```bash
cd InstallerBackend
npm install --legacy-peer-deps
npx wrangler login
npx wrangler r2 bucket create signflow-releases
npx wrangler r2 bucket create signflow-releases-preview
npx wrangler secret put API_TOKEN   # choose a long random token
npx wrangler deploy
```

Copy the printed `*.workers.dev` URL and the same API token into **SignFlow → Settings → Installer Backend**, enable temporary upload consent, then **Test Connection**.

## Device smoke test

1. Sign an IPA with an **Ad Hoc** profile that includes this device's UDID.
2. On the result screen, tap **Install on This Device** and accept the upload consent.
3. Confirm the iOS install prompt, then trust the developer certificate under Settings → General → VPN & Device Management if asked.
4. For free/development profiles, use **Open in Installer / Share IPA** instead.
