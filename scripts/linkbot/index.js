import { updateURLLink } from './common.js';
import * as bbMonitor from './monitor-bb.js';
import * as bbSdMonitor from './monitor-bb-sd.js';
import * as rpiMonitor from './monitor-rpi.js';
import * as ubuntuServerMonitor from './monitor-ub-server.js';
import * as raspbianOsMonitor from './monitor-raspbian-os.js';

const monitors = {
  bbMonitor,
  bbSdMonitor,
  rpiMonitor,
  ubuntuServerMonitor,
  raspbianOsMonitor
};

Object.entries(monitors).map(async ([monitorName, { checkForUpdates, determineCurrentState, target, updateReference }]) => {
  console.log(`${monitorName}: starting`);
  // Read the input file, and parse the variable input
  const state = await determineCurrentState();
  const result = await checkForUpdates(state);
  if (!result) {
    console.log(`${monitorName}: no updates found`);
    return;
  }
  console.log(`${monitorName}: We've got a new release! \\o/`);
  if (updateReference) {
    await updateReference(result);
    return;
  }
  await updateURLLink({ ...result, target });
});
