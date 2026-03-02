# Fallback Site (Nginx Stub)

Sets up a realistic-looking website that visitors see when browsing to the domain directly (not using VPN).

**ONLY for VLESS TLS path.** For Reality, the dest server already acts as a built-in fallback — visitors see the real website, no extra setup needed.

## How It Works

- Xray listens on port 443 and handles VLESS TLS traffic from VPN clients
- When a regular browser visits the domain (non-VPN HTTPS), Xray falls back to `127.0.0.1:8081`
- Nginx serves the stub site on `127.0.0.1:8081`
- Visitors see a realistic cloud storage page — not a connection error

**Important limitation:** Fallback via 3x-ui works ONLY with TCP transport (not XHTTP). `h2` must be removed from ALPN settings (already done in vless-tls.md Step 6).

## Step 1: Install Nginx

```bash
ssh {nickname} "sudo apt update && sudo apt install -y nginx"
```

## Step 2: Configure Nginx on Localhost

Nginx must listen on localhost only — port 443 is occupied by Xray.

```bash
ssh {nickname} 'sudo tee /etc/nginx/sites-available/stub << '"'"'NGINX_EOF'"'"'
server {
    listen 127.0.0.1:8081;
    server_name _;

    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX_EOF
sudo ln -sf /etc/nginx/sites-available/stub /etc/nginx/sites-enabled/stub && sudo rm -f /etc/nginx/sites-enabled/default && sudo nginx -t && sudo systemctl reload nginx'
```

## Step 3: Create Stub HTML Page (NebulaDrive style)

```bash
ssh {nickname} 'sudo tee /var/www/html/index.html << '"'"'HTML_EOF'"'"'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>NebulaDrive — Cloud Storage</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Russo+One&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
  <style>
    *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }

    body {
      font-family: "JetBrains Mono", monospace;
      background: #0a0a0a;
      color: #ededed;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }

    /* Animated background blobs */
    .blob {
      position: fixed;
      border-radius: 50%;
      filter: blur(120px);
      opacity: 0.12;
      pointer-events: none;
      z-index: 0;
      animation: float 18s ease-in-out infinite;
    }
    .blob-1 { width: 600px; height: 600px; background: #3b82f6; top: -200px; left: -150px; animation-delay: 0s; }
    .blob-2 { width: 500px; height: 500px; background: #8b5cf6; bottom: -150px; right: -100px; animation-delay: -6s; }
    .blob-3 { width: 300px; height: 300px; background: #10b981; top: 40%; left: 60%; animation-delay: -12s; }
    @keyframes float {
      0%, 100% { transform: translateY(0px) scale(1); }
      50% { transform: translateY(-30px) scale(1.05); }
    }

    /* Grid background */
    body::before {
      content: "";
      position: fixed;
      inset: 0;
      background-image:
        linear-gradient(rgba(59,130,246,0.04) 1px, transparent 1px),
        linear-gradient(90deg, rgba(59,130,246,0.04) 1px, transparent 1px);
      background-size: 40px 40px;
      pointer-events: none;
      z-index: 0;
    }

    /* Nav */
    nav {
      position: relative;
      z-index: 10;
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 20px 48px;
      border-bottom: 1px solid #262626;
      background: rgba(10,10,10,0.7);
      backdrop-filter: blur(12px);
    }
    .logo {
      font-family: "Russo One", sans-serif;
      font-size: 22px;
      background: linear-gradient(135deg, #3b82f6, #8b5cf6);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
      letter-spacing: 0.5px;
    }
    .nav-links { display: flex; gap: 32px; }
    .nav-links a {
      color: #a1a1aa;
      text-decoration: none;
      font-size: 13px;
      transition: color 0.2s;
    }
    .nav-links a:hover { color: #ededed; }
    .nav-actions { display: flex; gap: 12px; align-items: center; }
    .btn-ghost {
      background: transparent;
      border: 1px solid #262626;
      color: #a1a1aa;
      padding: 8px 18px;
      border-radius: 6px;
      font-family: "JetBrains Mono", monospace;
      font-size: 13px;
      cursor: pointer;
      transition: all 0.2s;
    }
    .btn-ghost:hover { border-color: #3b82f6; color: #ededed; }
    .btn-primary {
      background: linear-gradient(135deg, #2563eb, #7c3aed);
      border: none;
      color: #fff;
      padding: 8px 18px;
      border-radius: 6px;
      font-family: "JetBrains Mono", monospace;
      font-size: 13px;
      cursor: pointer;
      transition: opacity 0.2s;
    }
    .btn-primary:hover { opacity: 0.88; }

    /* Main layout */
    .main {
      position: relative;
      z-index: 10;
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 60px 48px;
      gap: 80px;
    }

    /* Left: sign-in form */
    .signin-card {
      background: rgba(23,23,23,0.85);
      border: 1px solid #262626;
      border-radius: 16px;
      padding: 40px;
      width: 380px;
      backdrop-filter: blur(16px);
    }
    .signin-card h2 {
      font-family: "Russo One", sans-serif;
      font-size: 24px;
      margin-bottom: 6px;
      background: linear-gradient(135deg, #ededed, #a1a1aa);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }
    .signin-card p { color: #a1a1aa; font-size: 13px; margin-bottom: 28px; }
    .form-group { margin-bottom: 16px; }
    .form-group label { display: block; font-size: 12px; color: #a1a1aa; margin-bottom: 6px; }
    .form-group input {
      width: 100%;
      padding: 11px 14px;
      background: #0a0a0a;
      border: 1px solid #262626;
      border-radius: 8px;
      color: #ededed;
      font-family: "JetBrains Mono", monospace;
      font-size: 13px;
      transition: border-color 0.2s;
      outline: none;
    }
    .form-group input:focus { border-color: #3b82f6; }
    .form-group input::placeholder { color: #52525b; }
    .form-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
    .remember { display: flex; align-items: center; gap: 8px; font-size: 12px; color: #a1a1aa; cursor: pointer; }
    .remember input { width: auto; }
    .forgot { font-size: 12px; color: #3b82f6; text-decoration: none; }
    .forgot:hover { text-decoration: underline; }
    .btn-signin {
      width: 100%;
      padding: 12px;
      background: linear-gradient(135deg, #2563eb, #7c3aed);
      border: none;
      border-radius: 8px;
      color: #fff;
      font-family: "Russo One", sans-serif;
      font-size: 15px;
      letter-spacing: 0.5px;
      cursor: pointer;
      transition: opacity 0.2s;
    }
    .btn-signin:hover { opacity: 0.88; }
    .divider { display: flex; align-items: center; gap: 12px; margin: 20px 0; }
    .divider span { flex: 1; height: 1px; background: #262626; }
    .divider p { font-size: 12px; color: #52525b; }
    .signup-link { text-align: center; font-size: 13px; color: #a1a1aa; }
    .signup-link a { color: #3b82f6; text-decoration: none; }
    .signup-link a:hover { text-decoration: underline; }

    /* Right: storage widget */
    .widget { width: 320px; }
    .widget-card {
      background: rgba(23,23,23,0.85);
      border: 1px solid #262626;
      border-radius: 16px;
      padding: 24px;
      backdrop-filter: blur(16px);
      margin-bottom: 16px;
    }
    .widget-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
    .widget-title { font-size: 13px; color: #a1a1aa; }
    .widget-size { font-family: "Russo One", sans-serif; font-size: 22px; background: linear-gradient(135deg, #3b82f6, #8b5cf6); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; }
    .progress-bar { height: 6px; background: #262626; border-radius: 3px; margin-bottom: 8px; }
    .progress-fill { height: 100%; background: linear-gradient(90deg, #3b82f6, #8b5cf6); border-radius: 3px; width: 34%; }
    .progress-label { font-size: 11px; color: #52525b; }
    .file-list { margin-top: 16px; display: flex; flex-direction: column; gap: 10px; }
    .file-item { display: flex; align-items: center; gap: 12px; }
    .file-icon { width: 32px; height: 32px; border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: 14px; flex-shrink: 0; }
    .file-icon.doc  { background: rgba(59,130,246,0.15); }
    .file-icon.img  { background: rgba(139,92,246,0.15); }
    .file-icon.zip  { background: rgba(16,185,129,0.15); }
    .file-info { flex: 1; min-width: 0; }
    .file-name { font-size: 12px; color: #ededed; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .file-meta { font-size: 11px; color: #52525b; }
    .file-size { font-size: 11px; color: #a1a1aa; flex-shrink: 0; }

    .stats-row { display: flex; gap: 10px; }
    .stat-card {
      flex: 1;
      background: rgba(23,23,23,0.85);
      border: 1px solid #262626;
      border-radius: 12px;
      padding: 14px;
      text-align: center;
      backdrop-filter: blur(16px);
    }
    .stat-value { font-family: "Russo One", sans-serif; font-size: 16px; background: linear-gradient(135deg, #3b82f6, #8b5cf6); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; }
    .stat-label { font-size: 10px; color: #52525b; margin-top: 2px; }

    /* Footer */
    footer {
      position: relative;
      z-index: 10;
      text-align: center;
      padding: 16px;
      font-size: 11px;
      color: #3f3f46;
      border-top: 1px solid #171717;
    }
    footer a { color: #52525b; text-decoration: none; margin: 0 8px; }
    footer a:hover { color: #a1a1aa; }
  </style>
</head>
<body>
  <div class="blob blob-1"></div>
  <div class="blob blob-2"></div>
  <div class="blob blob-3"></div>

  <nav>
    <div class="logo">NebulaDrive</div>
    <div class="nav-links">
      <a href="#">Features</a>
      <a href="#">Pricing</a>
      <a href="#">Docs</a>
      <a href="#">Status</a>
    </div>
    <div class="nav-actions">
      <button class="btn-ghost" onclick="return false;">Log in</button>
      <button class="btn-primary" onclick="return false;">Get started</button>
    </div>
  </nav>

  <div class="main">
    <div class="signin-card">
      <h2>Welcome back</h2>
      <p>Sign in to access your cloud storage</p>
      <form onsubmit="return false;">
        <div class="form-group">
          <label>Email address</label>
          <input type="email" placeholder="you@example.com" autocomplete="off">
        </div>
        <div class="form-group">
          <label>Password</label>
          <input type="password" placeholder="••••••••" autocomplete="off">
        </div>
        <div class="form-row">
          <label class="remember">
            <input type="checkbox"> Remember me
          </label>
          <a href="#" class="forgot">Forgot password?</a>
        </div>
        <button type="submit" class="btn-signin">Sign In</button>
      </form>
      <div class="divider">
        <span></span><p>or</p><span></span>
      </div>
      <div class="signup-link">
        Don&apos;t have an account? <a href="#">Create one free</a>
      </div>
    </div>

    <div class="widget">
      <div class="widget-card">
        <div class="widget-header">
          <span class="widget-title">Storage used</span>
          <span class="widget-size">34.2 GB</span>
        </div>
        <div class="progress-bar">
          <div class="progress-fill"></div>
        </div>
        <div class="progress-label">34.2 GB of 100 GB used</div>
        <div class="file-list">
          <div class="file-item">
            <div class="file-icon doc">📄</div>
            <div class="file-info">
              <div class="file-name">Q4_Report_Final.docx</div>
              <div class="file-meta">Modified 2 hours ago</div>
            </div>
            <div class="file-size">2.4 MB</div>
          </div>
          <div class="file-item">
            <div class="file-icon img">🖼</div>
            <div class="file-info">
              <div class="file-name">design_assets_v3.zip</div>
              <div class="file-meta">Modified yesterday</div>
            </div>
            <div class="file-size">18.7 MB</div>
          </div>
          <div class="file-item">
            <div class="file-icon zip">📦</div>
            <div class="file-info">
              <div class="file-name">backup_2024-11.tar.gz</div>
              <div class="file-meta">Modified 3 days ago</div>
            </div>
            <div class="file-size">512 MB</div>
          </div>
        </div>
      </div>

      <div class="stats-row">
        <div class="stat-card">
          <div class="stat-value">2M+</div>
          <div class="stat-label">Users</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">99.9%</div>
          <div class="stat-label">Uptime</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">AES-256</div>
          <div class="stat-label">Encrypted</div>
        </div>
      </div>
    </div>
  </div>

  <footer>
    &copy; 2025 NebulaDrive Inc.
    <a href="#">Privacy Policy</a>
    <a href="#">Terms of Service</a>
    <a href="#">Status</a>
  </footer>
</body>
</html>
HTML_EOF'
```

## Step 4: Verify Nginx is Running

```bash
ssh {nickname} "sudo nginx -t && sudo systemctl status nginx --no-pager -l"
```

Check stub is reachable locally:

```bash
ssh {nickname} "curl -s http://127.0.0.1:8081 | grep -o '<title>.*</title>'"
```

Expected: `<title>NebulaDrive — Cloud Storage</title>`

## Step 5: Verify Fallback from Browser

After the VLESS inbound is created with fallback to `127.0.0.1:8081` (done in vless-tls.md Step 6), visit the domain in a regular browser:

```
https://{domain}
```

Should show the NebulaDrive stub page — not a connection error or certificate warning.

## Notes

- The login form is purely cosmetic — it does nothing on submit
- Replace the HTML with any content you want (portfolio, blog, company landing page)
- Keep it realistic — an empty or broken page looks suspicious
- `h2` is intentionally excluded from ALPN (http/1.1 only) — required for Nginx fallback to work with Xray
