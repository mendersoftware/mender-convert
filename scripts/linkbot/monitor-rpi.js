import { getCurrentTestData, getLinksByMatch } from './common.js';

const reg = 'raspbian_lite-(?<date>[0-9]{4}-[0-9]{2}-[0-9]{1,2})/';
export const target = 'RASPBIAN_IMAGE_URL';

export const checkForUpdates = ({ url, imageName }) =>
  getLinksByMatch(url, reg).then(async links => {
    const matches = links.sort((a, b) => Date.parse(b.match.groups.date) - Date.parse(a.match.groups.date));
    const { link, match } = matches[0];
    const matchOn = match.input.split('/')[0];
    if (matchOn === imageName) {
      return;
    }
    // We also need to extract the new image name from the index folder, as
    // dated folders contain images with different dates in them o_O
    console.error("We've got a new release! \\o/");
    const newLink = await getLinksByMatch(link, 'raspbian-.*-lite.*.zip$').then(links => `${target}=\"${links[0].link}\"`);
    console.log(`New release: ${newLink}`);
    return { newLine: newLink };
  });

export const determineCurrentState = () => getCurrentTestData(target, '.*="(?<url>[a-zA-Z-://._]*)(?<imageName>raspbian_lite-[0-9]{4}-[0-9]{2}-[0-9]{1,2})/');
