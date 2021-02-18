const jsdom = require("jsdom");
const { JSDOM } = jsdom;
const fs = require('fs')
const { updateURLLink } = require('./common');

const reg = "[0-9]{4}-[0-9]{2}-[0-9]{1,2}/"
const target = "BBB_DEBIAN_EMMC_IMAGE_URL"

// Read the input file, and parse the variable input
try {
    const data = fs.readFileSync('../test/run-tests.sh', 'utf8')
          .split('\n')
          .filter(line => line.match(`${target}=.*`))
    var line = data[0]
    var m = line.match(".*=\"(?<url>[a-zA-Z-://\.]*)(?<latestDate>[0-9]{4}-[0-9]{2}-[0-9]{1,2}/).*")
    var url = m.groups.url
    var latestDate = m.groups.latestDate
} catch (err) {
    console.error(err)
    process.exit(1)
}

function getNewBoneDebian(url) {
    return JSDOM.fromURL(url, {}).then(dom => {
        var document = dom.window.document;
        var refs = document.getElementsByTagName("a");
        var test = Array.from(refs)
            .filter(ref => ref.textContent.match(("bone-debian.*\.img\.xz$")))
            .reduce((acc, element) => {
                acc.push(element.textContent.match("bone-debian.*\.img\.xz$").input)
                return acc
            }, [])[0]
        return `${target}=\"${url}/${test}\"`;
    });
}

JSDOM.fromURL(url, {}).then(async dom => {
    var document = dom.window.document;
    var table = document.getElementsByTagName("table");
    var rows = table[0].rows;
    var matches = Array.from(rows)
        .filter(row => row.children.length == 5)
        .filter(row => row.children[1].textContent.match(reg))
        .reduce((acc, row ) => {
            acc.push(row.children[1].textContent)
        return acc
        }, [])
        .sort((a,b) => {
            return Date.parse(b) - Date.parse(a)
        })
    if (matches[0] !== latestDate) {
        console.error("We've got a new release! \\o/");
        var newVar = await getNewBoneDebian(`${url}${matches[0]}buster-console`)
        if (newVar) {
            updateURLLink(newVar, target)
        }
    }
});
