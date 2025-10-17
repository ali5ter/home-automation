# 🤖 home-automation

These are notes and enablement software that helped me set up Apple Home automation of my Nest thermostats, Ring video doorbell, Apple speakers, etc.

This is based on using Apple as your base platform and integrating other products to that environment.

## Prerequisites

* Apple Home is installed on your iPhone (optionally on your Mac).

## Adding 4th gen Nest thermostats directly to Apple Home

No software enablement required. You add this device as an accessory to Apple Home because both support the [Matter protocol](https://csa-iot.org/all-solutions/matter/).

Perform the following steps on your phone close to the thermostat you want to add to Apple Home.

1. Install & set up in Google Home (required).
2. In Google Home: Thermostat → Settings → Linked Matter apps → Add to generate a Matter pairing code.
3. On iPhone: Home → + → Add Accessory → More options and scan the code. Your HomePod mini acts as the Apple Home hub/controller.

## Bridging 3rd gen Nest thermostats to Apple Home

Previous generations of Nest don't support Matter. We use [Homebridge](https://homebridge.io) with the homebridge-google-nest-sdm plugin which uses Google’s Smart Device Management API.

### 1. Run a Homebridge server on your machine

Doing this with Docker Compose is super convenient and this [docker-compose.yml](homebridge/docker-compose.yml) file provides the definition. Running [start_server_stack.sh](start_server_stack.sh) script will use this definition to stand up the server.

** Note: Homebridge in Docker Desktop for macOS can’t be discovered by the Apple Home app reliably because Docker on Mac doesn’t expose the container’s mDNS/Bonjour to your LAN. This means Apple Home cannot find Homebridge running in Docker due to network isolation. Host networking doesn’t fix it on Mac (Docker’s host mode is a VM thing, not your actual Wi-Fi/Ethernet). For more details, see [Docker Desktop networking limitations on macOS](https://docs.docker.com/desktop/networking/).

You can install Homebridge natively on macOS as long as you have [Node](https://nodejs.org/en) installed (which is easily installed using [homebrew](brew.sh)). To install Node using Homebrew, run:

```bash
sudo npm install -g --unsafe-perm homebridge homebridge-config-ui-x
sudo hb-service install
```

Note: At the time of writing, Node v11 appears to be the version Homebridge works with.

### 2. Pair Homebridge to Apple Home

Open the Homebridge UI using the URL provided by the output or logs emitted in step 1. Typically, `http://<host-ip>:8581`.

Open Apple Home on your iPhone. Open Apple Home → + → Add Accessory → More options and scan the code on the top left of the Homebridge UI Status page. After a few seconds, the Status page should reflect that it is paired.

### 3. Register for Google Device Access and create an SDM Project

[Register for Google Device Access (one-time $5), then create a Device Access project](https://developers.google.com/nest/device-access/project). Copy and save the SDM Project ID somewhere for later.

### 4. Create OAuth Access to your GCP Project

Log into the [Google Cloud Console](https://console.cloud.google.com/)
[From the Google Cloud Console, use a GCP project to enable Smart Device Management API access and get the OAuth Client ID and Secret](https://developers.google.com/nest/device-access/get-started). Copy and save the GCP Project ID, and the OAuth Client ID and Secret for later.

### 5. Configure access to you Nest devices

In the browser signed into your [Device Access Console](https://console.nest.google.com/device-access/project-list), open this URL after replacing each value inside curly braces `{}` with your actual values:

```bash
https://nestservices.google.com/partnerconnections/{SDM_PROJECT_ID}/auth?redirect_uri=https://www.google.com&access_type=offline&prompt=consent&client_id={YOUR_OAUTH_CLIENT_ID}&response_type=code&scope=https://www.googleapis.com/auth/sdm.service+https://www.googleapis.com/auth/pubsub
```

In the resulting page, approve access to all the Nest thermostats, click Next, and when you land on the resulting page, copy the URL which will contain a `code` that you copy and save for the next step.

Run the following curl command in the terminal, replacing each value inside curly braces `{}` with your actual credentials and codes:

```bash
curl -s -X POST https://oauth2.googleapis.com/token \
  -d client_id="{YOUR_OAUTH_CLIENT_ID}" \
  -d client_secret="{YOUR_OAUTH_CLIENT_SECRET}" \
  -d code="{PASTE_THE_CODE}" \
  -d grant_type=authorization_code \
  -d redirect_uri="https://www.google.com"
```

Copy the `refresh_token` value from the resulting JSON and save for later.

### 6. Enable Subscription to the Nest device events

Create a Pub/Sub Topic by navigating in the Google Cloud Console to Pub/Sub → Topics → Create topic. Use a topic ID/name `nest-sdm-events`. Copy and save the Topic and Subscription Name somewhere for later.

View the permissions for that topic and Add Principle. The new principle should be `sdm-publisher@googlegroups.com` and the Role should be `Pub/Sub Publisher`

To link the Topic to the [Device Access Console](https://console.nest.google.com/device-access/project-list) project you created, navigate to the project and look for the section called Pub/Sub topic, click on the action to Enable Events with the Pub/Sub topic, and paste the topic full name before saving.

Create a Subscription back in the [Google Cloud Console](https://console.cloud.google.com/) under the Pub/Sub area. Name the Subscription ID `homebridge-sdm`, select the Topic created above, and make sure the delivery type is set to `Pull` before creating. Copy the Subscription Name.

### 7. Configure the Homebridge SDM plugin

In the Homebridge UI, navigate to the Plugins page and search for 'homebridge-google-nest-sdm'.
Proceed to download the latest version of that plugin. Enter all the information:

* The OAuth Client ID and Secret from the GCP Project.
* The SDM Project ID copied from the project set up in your Google Device Access console.
* The Refresh Token copied from the curl command above.
* The PubSub Subscription Name you created that was linked to the Topic of SDM events.
* The GCP Project ID/name which you used in the [Google Cloud Console](https://console.cloud.google.com/)

Save the form and this will restart Homebridge to make the configuration changes. The Homebridge Logs displayed in the Status page should list the Nest Thermostats you allowed access to above.

The Nest thermostats should appear in Apple Home. If not, you may need to repair Homebridge with Apple Home:

* In the Homebridge UI, go to the Status page and click "Unpair" or "Reset Homebridge".
* In Apple Home, remove the Homebridge accessory.
* Restart Homebridge, then re-add it in Apple Home by scanning the pairing code shown in the Homebridge UI Status page.

### 8. Save the Homebridge configuration

In the Homebridge UI, navigate to the JSON Config page, and copy and paste the configuration somewhere safe. This way if you have to move or upgrade Homebridge, you'll have the configuration to restore.

## Bridging 2nd gen Ring video doorbells to Apple Home

[Scrypted](https://www.scrypted.app) provides the best video performance but integration with Ring can also be performed with Homebridge.

### 1. Dependencies for Homebridge

Install the `ffmpeg` tools using homebrew:

```bash
brew install ffmpeg
```

In the Homebridge UI, navigate to the Plugins page and search for 'homebridge-ring'.
Enter the Ring credentials and 2FA code, then save to restart Homebridge.

### 2. Configure the Homebridge Ring plugin

In the Homebridge plugins page, open up the Ring plugin configurations form, and make sure the following is set:

* Hide In-Home Doorbell Switch: Checked
* Hide Doorbell Programmable Switch: Checked
* Debug Logging: Checked
* Camera/Chime Status Polling (seconds): 20
* Avoid Snapshot Battery Drain: Checked

Save and restart the plugin.

### 3. Add the Ring doorbell to Apple Home

Open the Homebridge UI plugins page and click on the QR code in the Ring plugin card. This will show the pairing code.
In Apple Home, go Add Accessory, and pair using this code to add the doorbell.

After that pairing completes, Apple Home will automatically show the Cameras & Doorbells section in settings, and you’ll be able to:

* Enable “Doorbell Chime on HomePod”
* Choose notifications and recording options, and
* Trigger automations based on doorbell presses or motion.
