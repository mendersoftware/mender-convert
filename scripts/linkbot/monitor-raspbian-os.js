import { getCurrentTestData, getLinksByMatch, fileTypes, updateURLLink } from './common.js';

const reg = 'raspios_lite_armhf-(?<date>[0-9]{4}-[0-9]{2}-[0-9]{1,2})/.*';
export const target = 'RASPBIAN_URL';

export const checkForUpdates = ({ url, imageName: currentImageName }) =>
  getLinksByMatch(url, reg).then(async (links) => {
    const { link, match } = links.sort((a, b) => Date.parse(b.match.groups.date) - Date.parse(a.match.groups.date))[0];
    const matchOn = match.input.split('/')[0];
    if (matchOn === currentImageName) {
      return;
    }
    // We also need to extract the new image name from the index folder, as
    // dated folders contain images with different dates in them o_O
    const newLinks = await getLinksByMatch(link, 'raspios-.*-lite.*.img.(zip|xz)$');
    const { link: newUrl, match: imageMatch } = newLinks[0];
    const imageName = imageMatch.input.substring(0, imageMatch.input.lastIndexOf('.img'));
    console.log(`New release: ${newUrl}`);
    return { newName: imageName, newUrl };
  });

// Read the input file, and parse the variable input
export const determineCurrentState = () =>
  getCurrentTestData(target, '.*: "(?<url>[a-zA-Z-://._]*)(?<imageName>raspios_lite_armhf-[0-9]{4}-[0-9]{2}-[0-9]{1,2})/.*"$', fileTypes.ciFile.key);

export const updateReference = ({ newName, newUrl }) => {
  // Update the GitlabCI link
  console.log('Updating the GitlabCI Link');
  updateURLLink({ targetName: 'RASPBIAN_NAME', targetUrl: target, newName, newUrl }, fileTypes.ciFile.key);
};
