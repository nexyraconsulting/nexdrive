/* NEXDrive front-end configuration TEMPLATE.
   Generate js/config.js per environment at deploy time, for example:
     export NEXDRIVE_MODE=demo NEXDRIVE_API_BASE_URL=https://api.nexdrive.co.uk/v1 ...
     envsubst < config/config.template.js > js/config.js
   Or edit js/config.js by hand. This file is PUBLIC once deployed: never put secrets here.
   See CONFIGURATION_CHECKLIST.md for every value. */
window.NEXDRIVE_CONFIG = {
  // 'demo' = in-memory sample data (this build). 'live' = use the API (requires the backend; see DEVELOPER_HANDOVER.md).
  mode: '${NEXDRIVE_MODE}',
  // Base URL of the NEXDrive API, e.g. 'https://api.nexdrive.co.uk/v1'. Unused while mode is 'demo'.
  apiBaseUrl: '${NEXDRIVE_API_BASE_URL}',
  // Public sign-up URL used in referral links and QR codes. Must equal REFERRAL_BASE_URL in .env.
  referralBaseUrl: '${NEXDRIVE_REFERRAL_BASE_URL}',
  // true = show the workflow shortcuts panel and demo-only buttons. Set false for real users.
  showDemoPanel: ${NEXDRIVE_SHOW_DEMO_PANEL},
  // false = app fills the browser viewport instead of a phone frame on desktop.
  deviceFrame: ${NEXDRIVE_DEVICE_FRAME},
  // Play the NEXDrive lock-up animation on start.
  launchAnimation: true,
  timezone: 'Europe/London',
  currency: 'GBP'
};
