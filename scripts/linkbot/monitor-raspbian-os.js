const jsdom = require("jsdom");
const { JSDOM } = jsdom;
const fs = require("fs");
const { updateURLLink } = require("./common");

const target = "RASPBIAN_URL";

// Read the input file, and parse the variable input
try {
  const data = fs
    .readFileSync("../../.gitlab-ci.yml", "utf8")
    .split("\n")
    .filter((line) => line.match(`${target}: .*`));
  var line = data[0];
  console.log(line);
  var reg =
    "raspios_lite_armhf-(?<date>[0-9]{4}-[0-9]{2}-[0-9]{1,2})/(?<updated>[0-9]{4}-[0-9]{2}-[0-9]{1,2}).*$";
  var m = line.match(
    ".*: \"(?<url>[a-zA-Z-://._]*)(?<imageName>raspios_lite_armhf-[0-9]{4}-[0-9]{2}-[0-9]{1,2})/(?<updated>[0-9]{4}-[0-9]{2}-[0-9]{1,2}).*\"$"
  );
  console.log(m);
  var url = m.groups.url;
  var imageName = m.groups.imageName;
  var updated = m.groups.updated;
} catch (err) {
  console.error(err);
  process.exit(1);
}


function getNewRaspbian(target, url, separator) {
    console.log("getNewRaspbian");
    console.log(`${url}`);
    return JSDOM.fromURL(url, {}).then((dom) => {
        var document = dom.window.document;
        var refs = document.getElementsByTagName("a");
        var test = Array.from(refs)
            .filter((ref) => ref.textContent.match("raspios-.*-lite.*.zip$"))
            .reduce((acc, element) => {
                acc.push(element.textContent.match("raspios-.*-lite.*.zip$").input);
                return acc;
            }, [])[0];
        console.log(`Test var: ${test}`);
        const imageName = test.substring(0, test.length - 4);
        if (separator) {
            return {
                replacementLine: `${target}${separator} \"${url}/${test}\"`,
                imageName: imageName,
            };
        }
        return { replacementLine: `${target}=\"${url}/${test}\"`, imageName: imageName };
    });
}


function updateGitlabCILink(newLine, newURL, newName) {
  try {
    const data = fs
      .readFileSync("../../.gitlab-ci.yml", "utf8")
      .replace(
        RegExp(` *## Auto-update\n *${newURL}:.*\n *RASPBIAN_NAME: .*`),
        `  ## Auto-update\n  ${newLine}\n  RASPBIAN_NAME: ${newName}`
      );
    fs.writeFile("../../.gitlab-ci.yml", data, (err, data) => {
      if (err) {
        console.error(err);
      }
    });
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

JSDOM.fromURL(url, {}).then((dom) => {
  var document = dom.window.document;
  var table = document.getElementsByTagName("table");
  var rows = table[0].rows;
  var matches = [];
  for (var i = 0; i < rows.length; i++) {
    var rowText = rows[i].textContent;
    var regMatch = rowText.match(reg);
    if (regMatch) {
      matches.push(regMatch);
    }
  }
  // Sort the accumulated matches
  matches.sort(function (a, b) {
    let al = Date.parse(a.groups.date);
    let bl = Date.parse(b.groups.date);
    if (al == bl) {
      let ad = Date.parse(a.groups.updated);
      let bd = Date.parse(b.groups.updated);
      return bd - ad;
    }
    return bl - al;
  });
  var matchOn = matches[0].input.split("/")[0];
  if (matchOn !== imageName) {
    // We also need to extract the new image name from the index folder, as
    // dated folders contain images with different dates in them o_O
    console.error("We've got a new release! \\o/");

    // Update the GitlabCI link unconditionally
    console.log("Updating the GitlabCI Link");
    var newVar = getNewRaspbian(
      "RASPBIAN_URL",
      `${url}${matches[0].input.split(" ")[0].split("/").slice(0, -1)}`,
      (separator = ":")
    ).then(({ replacementLine, imageName }) => {
      console.log(`New release: ${replacementLine}`);
      updateGitlabCILink(replacementLine, "RASPBIAN_URL", imageName);
    });
  }
});
