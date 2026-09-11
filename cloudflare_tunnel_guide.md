# Cloudflare Tunnels (Zero Trust) Setup Guide

This guide will walk you through exposing your internal services (like Immich, your Job Board, etc.) securely to the internet without opening any ports on your router.

**Note:** You mentioned your IP as `192.186.50.217`. It's very likely this is a typo for `192.168.50.217` (as `192.168.x.x` is standard private networking). Be sure to use the exact correct IP when setting up the tunnels below.

## Phase 1: Creating the Tunnel in Cloudflare

1. Log into your Cloudflare Dashboard and navigate to **Zero Trust**.
2. On the left sidebar, go to **Networks** -> **Tunnels**.
3. Click **Add a tunnel**.
4. Choose **Cloudflared** and click Next.
5. Name the tunnel (e.g., `Hub-and-Spoke-Pi`) and click Save.
6. **Install the Connector:** 
   - Cloudflare will show you a command to run on your Raspberry Pi.
   - Under "Choose your environment", select **Debian** and **64-bit** (since you are on Debian 13 Trixie).
   - Copy the command provided (it will look like `curl -L --output cloudflared.deb ... && sudo dpkg -i cloudflared.deb && sudo cloudflared service install <YOUR_TOKEN>`).
7. **Run that command on your Raspberry Pi.**
   - Once it runs successfully, the tunnel status on your Cloudflare dashboard should change to **Connected**.
   - Click Next.

## Phase 2: Route Your Subdomains (Public Hostnames)

Now you will tell Cloudflare which subdomains point to which internal IP addresses and ports on your network.

### 1. Job Board (Example)
- **Subdomain:** `jobs`
- **Domain:** `dark-ops.cc`
- **Type:** `HTTP` (or `HTTPS` if the container requires it locally)
- **URL:** `192.168.50.217:<PORT_FOR_JOB_BOARD>`
- Click **Save**.

### 2. Immich / Photos (Example)
- Go back into your Tunnel configuration and click **Add public hostname**.
- **Subdomain:** `photos` (or `immich`)
- **Domain:** `dark-ops.cc`
- **Type:** `HTTP`
- **URL:** `192.168.50.217:2283` (Standard Immich port, change if different)
- Click **Save**.

### 3. Security Cameras (Future)
- **Subdomain:** `cameras`
- **Domain:** `dark-ops.cc`
- **Type:** `HTTP`
- **URL:** `192.168.50.217:<PORT_FOR_CAMERAS>`
- Click **Save**.

## Phase 3: Lock it Down with Zero Trust Access

Right now, anyone who goes to `jobs.dark-ops.cc` can see your app. We need to lock this down so *only you* can access it via an Email PIN.

1. In the Zero Trust Dashboard, go to **Access** -> **Applications**.
2. Click **Add an application** -> Select **Self-hosted**.
3. **Application Name:** `My Secure Home Apps`
4. **Session Duration:** `24 hours` (or whatever you prefer)
5. **Application Domain:** 
   - Add all your subdomains here (`jobs.dark-ops.cc`, `photos.dark-ops.cc`, etc.)
6. Click **Next** to go to Policies.
7. **Policy Name:** `Allow Only Me`
8. **Action:** `Allow`
9. Under **Include**, set:
   - **Selector:** `Emails`
   - **Value:** `<your-actual-email-address>`
10. Click **Next** and **Save**.

## Verification
- Turn off Wi-Fi on your phone and go to `https://jobs.dark-ops.cc`.
- You should be greeted by a Cloudflare Access screen asking for your email.
- Enter your email, type in the PIN you receive, and you will be securely granted access to your internal app!

## Phase 4: Allowing Mobile Apps (Like Immich) to Connect

When you lock down your domains with Cloudflare Zero Trust (Phase 3), mobile apps like the Immich Android app will break because they cannot process the Cloudflare Email PIN login screen. 

You have two main options to fix this while keeping your server safe:

### Option 1: Use the Cloudflare One (WARP) App (Most Secure)
This method keeps your Immich instance 100% hidden behind Zero Trust, but requires an app on your phone.

1. In your Cloudflare Zero Trust dashboard, go to **Settings** -> **WARP Client**.
2. Under **Device enrollment**, click **Manage** and set up a rule to allow your email address to enroll devices.
3. On your Android phone, download the **Cloudflare One Agent (WARP)** app from the Play Store.
4. Open the app, go to Settings -> Account -> **Login to Zero Trust**.
5. Enter your Zero Trust team name (found in your Cloudflare dashboard under Settings -> Custom Pages -> Team domain).
6. Log in with your email PIN.
7. Turn on the WARP connection in the app. 
8. The Immich app will now be able to connect to `https://photos.dark-ops.cc` seamlessly!

### Option 2: Bypass Zero Trust for Immich's API (Easier)
This method opens the Immich API to the public internet, relying purely on Immich's built-in login screen for security. The web interface will still be protected by Cloudflare Access.

**Here is how to properly bypass the Immich API:**
1. In Cloudflare Zero Trust, go to **Access** -> **Applications** and click **Add an application** (Self-hosted).
2. Name it `Immich API Bypass`.
3. Set the Domain to `photos.dark-ops.cc` and the **Path** to `api` (no slashes needed, just `api`).
4. Click Next to go to Policies.
5. Name the policy `Bypass API`.
6. Set the **Action** to `Bypass`.
7. Under **Include**, set the Selector to `Everyone`.
8. Save the application.

Now, going to `https://photos.dark-ops.cc` in a browser will still ask for a PIN, but the Immich Android App will be able to talk to `https://photos.dark-ops.cc/api` freely and you can log in using your normal Immich username/password!
