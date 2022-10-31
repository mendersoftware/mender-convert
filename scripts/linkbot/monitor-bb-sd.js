import { getCurrentTestData, getLinksByMatch } from './common.js';

const reg = 'bone-debian-(?<version>[0-9]+.[0-9]+)-iot-armhf-(?<date>[0-9]{4}-[0-9]{2}-[0-9]{1,2})-4gb.img.xz$';
export const target = 'BBB_DEBIAN_SDCARD_IMAGE_URL';

export const checkForUpdates = ({ url, imageName }) =>
  getLinksByMatch(url, reg).then(async links => {
    // The bone-debian setup has two parts which needs comparing:
    // * The release-version: i.e., 10.3
    // * The date: i.e., 2020-04-06
    const matches = links.sort((a, b) => parseFloat(b.match.groups.version) - parseFloat(a.match.groups.version) || Date.parse(b.date) - Date.parse(a.date));
    const { element, link } = matches[0];
    if (element.textContent === imageName) {
      return;
    }
    return { newLine: `${target}="${link}"` };
  });

export const determineCurrentState = () =>
  getCurrentTestData(
    target,
    '.*="(?<url>[a-zA-Z-://._]*)(?<imageName>bone-debian-(?<version>[0-9]+.[0-9]+)-iot-armhf-(?<date>[0-9]{4}-[0-9]{2}-[0-9]{1,2})-4gb.img.xz)'
  );
