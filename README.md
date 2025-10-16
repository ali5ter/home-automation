# home-automation

These are notes and enablement of software that helped me set up automation for my range of thermostats, video doorbell, speakers, TCs, etc.

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

** Note: Homebridge in Docker Desktop for macOS can’t be discovered by the Apple Home app reliably because Docker on Mac doesn’t expose the container’s mDNS/Bonjour to your LAN. Host networking doesn’t fix it on Mac (Docker’s host mode is a VM thing, not your actual Wi-Fi/Ethernet).

You can install Homebridge natively on macOS as long as you have [Node](https://nodejs.org/en) installed (which is easily installed using [homebrew](brew.sh)). Run the following from the terminal:

```bash
sudo npm install -g --unsafe-perm homebridge homebridge-config-ui-x
sudo hb-service install
```

### 2. Pair Homebridge to Apple Home

Open the Homebridge UI using the URL provided by the output or logs emitted in step 1. Typically, `http://<host-ip>:8581`.

Open Apple Home on your iPhone. Open Apple Home → + → Add Accessory → More options and scan the code on the top left of the Homebridge UI Status page. After a few seconds, the Status page should reflect that it is paired.

### 3. Register for Google Device Access and create an SDM Project

[Register for Google Device Access (one-time $5), then create a Device Access project](https://developers.google.com/nest/device-access/project). Copy and save the SDM Project ID somewhere for later.

### 4. Create OAuth Access to your GCP Project

Log into the [Google Cloud Console](https://console.cloud.google.com/)
[From the Google Cloud Console, use a GCP project to enable Smart Device Management API access and get the OAuth Client ID and Secret](https://developers.google.com/nest/device-access/get-started). Copy and save the GCP Project ID, and the OAuth Client ID and Secret for later.

### 5. Configure access to you Nest devices

In the browser signed into your [Device Access Console](https://console.nest.google.com/device-access/project-list), open this URL after replacing the bracketed parts:

``` url
https://nestservices.google.com/partnerconnections/<SDM_PROJECT_ID>/auth?redirect_uri=https://www.google.com&access_type=offline&prompt=consent&client_id=<YOUR_OAUTH_CLIENT_ID>&response_type=code&scope=https://www.googleapis.com/auth/sdm.service+https://www.googleapis.com/auth/pubsub
```

In the resulting page, approve access to all the Nest thermostats, click Next, and when you land on the resulting page, copy the URL which will contain a `code` that you copy and save for the next step.

Run the following curl command in the terminal replacing the bracketed parts:

```bash
curl -s -X POST <https://oauth2.googleapis.com/token> \
  -d client_id="<YOUR_OAUTH_CLIENT_ID>" \
  -d client_secret="<YOUR_OAUTH_CLIENT_SECRET>" \
  -d code="<PASTE_THE_CODE>" \
  -d grant_type=authorization_code \
  -d redirect_uri="<https://www.google.com>"
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

The Nest thermostats should appear in Apple Home, if not, repair Homebridge with Apple Home.

### 8. Save the Homebridge configuration

In the Homebridge UI, navigate to the JSON Config page, and copy and paste the configuration somewhere safe. This way if you have to move or upgrade Homebridge, you'll have the configuration to restore.

## Bridging 2nd gen Ring video doorbells to Apple Home
