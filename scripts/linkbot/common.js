import { JSDOM } from 'jsdom';
import fs from 'fs';

export const fileTypes = {
  testRunner: {
    key: 'testRunner',
    path: '../test/run-tests.sh',
    matcher: (target) => (line) => line.match(`${target}=.*`),
    replacer: ({ newLine, target }) => [RegExp(`## Auto-update\n${target}=.*`), `## Auto-update\n${newLine}`]
  },
  ciFile: {
    key: 'ciFile',
    path: '../../.gitlab-ci.yml',
    matcher: (target) => (line) => line.match(`${target}: .*`),
    replacer: ({ targetName, targetUrl, newName, newUrl }) => [
      RegExp(` *## Auto-update\n *${targetUrl}:.*\n *${targetName}: .*`),
      `  ## Auto-update\n  ${targetUrl}: "${newUrl}"\n  ${targetName}: ${newName}`
    ]
  }
};

export const updateURLLink = (updatedValues, fileType = fileTypes.testRunner.key) => {
  try {
    const data = fs.readFileSync(fileTypes[fileType].path, 'utf8').replace(...fileTypes[fileType].replacer(updatedValues));
    fs.writeFile(fileTypes[fileType].path, data, (err) => {
      if (err) {
        console.error(err);
      }
    });
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
};

export const getCurrentTestData = (target, matcher, fileType = fileTypes.testRunner.key) => {
  let line;
  try {
    line = fs.readFileSync(fileTypes[fileType].path, 'utf8').split('\n').find(fileTypes[fileType].matcher(target));
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
  const match = line.match(matcher);
  return match.groups;
};

export const getLinksByMatch = (url, matcher) =>
  JSDOM.fromURL(url, {}).then((dom) => {
    const refs = dom.window.document.getElementsByTagName('a');
    return Array.from(refs).reduce((accu, element) => {
      const match = element.textContent.match(matcher);
      if (match) {
        accu.push({ element, link: element.href, match });
      }
      return accu;
    }, []);
  });
