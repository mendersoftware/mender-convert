import { getCurrentTestData, getLinksByMatch } from './common.js';

const reg = '(?<url>[a-zA-Z-://._]*)(?<release>[0-9][02468]).04.?(?<minor>[0-9]{1})?.*';
export const target = 'UBUNTU_SERVER_RPI_IMAGE_URL';

const getReleaseName = (release, minor) => `${release}.04${minor ? `.${minor}` : ''}`;

// Get the release image url from the releases (sub)-page
export const checkForUpdates = async ({ url, release }) => {
  const releasedVersion = await getLinksByMatch(url, reg).then((links) => {
    const matches = links.sort((a, b) => {
      if (b.match.groups.release === a.match.groups.release) {
        return parseInt(b.match.groups.minor) - parseInt(a.match.groups.minor);
      }
      return parseInt(b.match.groups.release) - parseInt(a.match.groups.release);
    });
    const { match } = matches[0];
    return getReleaseName(match.groups.release, match.groups.minor);
  });
  if (release === releasedVersion) {
    return;
  }
  console.log(`Ubuntu server image has a new release: ${releasedVersion}`);
  const links = await getLinksByMatch(`${url}${releasedVersion}/release/`, `.*ubuntu-${releasedVersion}-preinstalled-server-armhf.*\.img\.xz$`);
  const { link, match } = links[0];
  if (match) {
    return { newLine: `${target}="${link}"` };
  }
  const betaLinks = await getLinksByMatch(`${url}${releasedVersion}/release/`, `.*ubuntu-${releasedVersion}-beta-preinstalled-server-armhf.*\.img\.xz$`);
  if (betaLinks.length) {
    console.log('Only the beta is out still');
  }
};

export const determineCurrentState = () => {
  const { minor, release, url } = getCurrentTestData(target, reg);
  return { url, release: getReleaseName(release, minor) };
};
