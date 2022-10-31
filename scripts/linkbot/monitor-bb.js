import { getCurrentTestData, getLinksByMatch } from './common.js';

const reg = '[0-9]{4}-[0-9]{2}-[0-9]{1,2}/';
export const target = 'BBB_DEBIAN_EMMC_IMAGE_URL';

export const checkForUpdates = ({ url, latestDate }) =>
  getLinksByMatch(url, reg).then(async links => {
    const matches = links.sort((a, b) => Date.parse(b.element.textContent) - Date.parse(a.element.textContent));
    const date = matches[0].element.textContent;
    if (date === latestDate) {
      return;
    }
    const consoleLinks = await getLinksByMatch(matches[0].link, 'bullseye-minimal-arm64');
    const result = await getLinksByMatch(consoleLinks[0].link, 'bbai64-debian.*.img.xz$').then(links => `${target}=\"${links[0].link}\"`);
    return { newLine: result };
  });

export const determineCurrentState = () => getCurrentTestData(target, '.*="(?<url>[a-zA-Z-://.]*)(?<latestDate>[0-9]{4}-[0-9]{2}-[0-9]{1,2}/).*');
