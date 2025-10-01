---
## 5.0.0 - 2025-09-29


### Bug fixes


- Do not use world-writable permissions for mender-convert image.
 ([6a74029](https://github.com/mendersoftware/mender-convert/commit/6a7402947fecdd3d35df902b586dd0dc4bac3747)) 


  The image is only used in the build itself, so it's unlikely to be a
  security issue. It does not affect output images.
- Fix writing MSDOS partition UUIDs
([MEN-7937](https://northerntech.atlassian.net/browse/MEN-7937)) ([af0a17d](https://github.com/mendersoftware/mender-convert/commit/af0a17d3ca0793fa3bc9328f98173ef4b0408144))  by @jo-lund


  rev works on unicode strings and is therefore not safe to use to swap bytes.
- Preserve extended attribute with rsync
 ([b9988ee](https://github.com/mendersoftware/mender-convert/commit/b9988eeb87fe1350fc2baae15798e796a4e1958a))  by @timbz
- Update `grub-mender-grubenv` version
([ME-458](https://northerntech.atlassian.net/browse/ME-458)) ([10817e5](https://github.com/mendersoftware/mender-convert/commit/10817e5e2c88d1667329b6ba865f6de04a4fd5bf))  by @lluiscampos
- Expand the data partition into the empty space on boot
([MEN-8191](https://northerntech.atlassian.net/browse/MEN-8191)) ([d04876a](https://github.com/mendersoftware/mender-convert/commit/d04876acfa437454a7685ba4f59d4c13deeb8300))  by @jo-lund


  When MENDER_DATA_PART_GROWFS is "y" (which is default), x-systemd.growfs
  will be set for the data partition in /etc/fstab. This option is understood
  by systemd and will grow the file system to occupy the full block device.
  However, the partition itself will not necessarily be expanded. For
  Raspberry Pi a systemd script could be used that would run "parted"
  to expand the partition. This is now done for all systems.
- Systemd_common_config: add --fix option to parted call
 ([ef68160](https://github.com/mendersoftware/mender-convert/commit/ef6816058bfa406ca925928f177e188f838c9645))  by @chlongv


  In case when the GPT header does not include the full disk size (can
  happen to generate smaller images), parted is going to fail because of
  an exception.
  
  Add the --fix option to fix those exceptions and allow parted to resize
  the data partition.




### Documentation


- Update example commands in README
 ([f81ba6b](https://github.com/mendersoftware/mender-convert/commit/f81ba6b57acf174afc72cbac22eceeba175d0036))  by @lluiscampos


  Follow-up from 495c5e601f3cc52d152f651ff3a53aafce2b69b7
- Update command to decompress the image
 ([49f5654](https://github.com/mendersoftware/mender-convert/commit/49f565468799905dc4ba4a5beab9513f725cbf4e))  by @lluiscampos
- Rewrite comment for `MENDER_CLIENT_VERSION`
 ([0486ffb](https://github.com/mendersoftware/mender-convert/commit/0486ffbabb3c788dd5668fd54c2173dee7bd2978))  by @lluiscampos


  To clarify what `auto` will do in the context of the recently released
  Mender Client 5.0.
- Update run-tests readme
 ([d4a676d](https://github.com/mendersoftware/mender-convert/commit/d4a676d5ed17024548d58c20d9fe26d2e4501bdf))  by @danielskinstad
- Extend UEFI NVRAM guide for future Ubuntu 24.04 upgrade
 ([6b787b6](https://github.com/mendersoftware/mender-convert/commit/6b787b6a7606f74feab09890179dfe7df8dc98d5))  by @lluiscampos




### Features


- *(uefi)* Implement support for RPi4 `cmdline.txt` boot file.
([MEN-5826](https://northerntech.atlassian.net/browse/MEN-5826)) ([59816ee](https://github.com/mendersoftware/mender-convert/commit/59816ee8137881f5df9743ba9ebe351cbdc24baf)) 


  This is required to run the "firstboot" Raspberry Pi setup
  correctly. It also makes sure that custom boot options in that file
  are actually respected.

- Add a `platform_pre_modify` hook.
 ([9b4cae4](https://github.com/mendersoftware/mender-convert/commit/9b4cae4eb4bfdf73cd70c2ed06ca7813641ced86)) 


  This runs before modifications, but after the image has been mounted,
  so that it's ready to receive modifications.
- Introduce basic support for booting Raspberry Pi 4 using UEFI.
([MEN-5826](https://northerntech.atlassian.net/browse/MEN-5826)) ([e5fba41](https://github.com/mendersoftware/mender-convert/commit/e5fba4163ec04771f83f601b97216d784d254c14)) 


  With this we can boot Raspberry Pi 4 using UEFI, but it provides no
  integration beyond the mere boot itself, which works, but presents
  some problems. These will be fixed in upcoming commits.
- Upgrade Raspberry Pi 3 pre-built image to Debian 12 64bits
([MEN-7759](https://northerntech.atlassian.net/browse/MEN-7759)) ([c4b47f3](https://github.com/mendersoftware/mender-convert/commit/c4b47f3d1523d2ba4fffc9cba5d7082b2b7f4e67))  by @lluiscampos


  This commit restores the Raspberry Pi 3 pre-built image build and
  publish, but modifying it from being based in the 32bits one to the 64
  bits one.

- Create sparse images
 ([c90d8df](https://github.com/mendersoftware/mender-convert/commit/c90d8df9d719f5dbdcbc557e1338ae07d6604f00))  by @ygerlach


  Instead of allocating the whole image on the disk, only allocate the parts that actually contain data. This reduces the required disk space to store or create images.
  This feature is disabled by default and can be enabled with the `MENDER_SPARSE_IMAGE` configuration flag.
- Warn for signs of external  mender installation
 ([b4eab2a](https://github.com/mendersoftware/mender-convert/commit/b4eab2aa8529df858a1cbc253b0770addff92171))  by @TheMeaningfulEngineer


- Update GRUB to version 2.12
 ([4f180a2](https://github.com/mendersoftware/mender-convert/commit/4f180a2356054b8342cf0eefa886bd602ebc99e5))  by @lluiscampos


  Following the update from `grub-mender-grubenv` repository from January
  2025:
  * https://github.com/mendersoftware/grub-mender-grubenv/pull/39
- Use the `device-components` repository
 ([150095d](https://github.com/mendersoftware/mender-convert/commit/150095d717ebeea40f1993738f8d4303a2fa8864))  by @danielskinstad
- Use `apt install some-package` to install Mender packages
([MEN-8476](https://northerntech.atlassian.net/browse/MEN-8476)) ([44920dc](https://github.com/mendersoftware/mender-convert/commit/44920dca944c8bca9cc2a6ed06d3b1a3d51fc3bb))  by @vpodzime
  - **BREAKING**: apt is now used to install Mender packages from
the repositories instead of dpkg installing individual packages


  Instead of custom magic downloading and installing individual
  packages from the repos, `apt` package manager is now used to do
  its job, including dependency resolution and installation, and
  signature+checksum verification, among other things.




### Security


- Bump tests/mender-image-tests from `698cb01` to `5405aa3`
 ([88d0240](https://github.com/mendersoftware/mender-convert/commit/88d0240790e49171a3d889dcc44f007321493929))  by @dependabot[bot]


  Bumps [tests/mender-image-tests](https://github.com/mendersoftware/mender-image-tests) from `698cb01` to `5405aa3`.
  - [Commits](https://github.com/mendersoftware/mender-image-tests/compare/698cb01171f7ef1faaabbe8311f21a06cf1a0432...5405aa3c2b0bd8a6219820720e023363f090881c)
  
  ---
  updated-dependencies:
  - dependency-name: tests/mender-image-tests
    dependency-type: direct:production
  ...
- Bump pytest in /tests in the python-test-dependencies group
 ([afff8f2](https://github.com/mendersoftware/mender-convert/commit/afff8f2d1151c7cfeb0e5b6eab650c87314b2a0a))  by @dependabot[bot]


  Bumps the python-test-dependencies group in /tests with 1 update: [pytest](https://github.com/pytest-dev/pytest).
  
  
  Updates `pytest` from 8.3.3 to 8.3.4
  - [Release notes](https://github.com/pytest-dev/pytest/releases)
  - [Changelog](https://github.com/pytest-dev/pytest/blob/main/CHANGELOG.rst)
  - [Commits](https://github.com/pytest-dev/pytest/compare/8.3.3...8.3.4)
  
  ---
  updated-dependencies:
  - dependency-name: pytest
    dependency-type: direct:production
    update-type: version-update:semver-patch
    dependency-group: python-test-dependencies
  ...
- Bump jinja2 from 3.1.4 to 3.1.5 in /tests
 ([b2e6c67](https://github.com/mendersoftware/mender-convert/commit/b2e6c67a8c0acd17ce718ac7eec0df71539e7d79))  by @dependabot[bot]


  Bumps [jinja2](https://github.com/pallets/jinja) from 3.1.4 to 3.1.5.
  - [Release notes](https://github.com/pallets/jinja/releases)
  - [Changelog](https://github.com/pallets/jinja/blob/main/CHANGES.rst)
  - [Commits](https://github.com/pallets/jinja/compare/3.1.4...3.1.5)
  
  ---
  updated-dependencies:
  - dependency-name: jinja2
    dependency-type: indirect
  ...
- Bump tests/mender-image-tests from `5405aa3` to `074bb74`
 ([c8c7eb9](https://github.com/mendersoftware/mender-convert/commit/c8c7eb93181f43e2fb6e8613adf554411e482106))  by @dependabot[bot]


  Bumps [tests/mender-image-tests](https://github.com/mendersoftware/mender-image-tests) from `5405aa3` to `074bb74`.
  - [Commits](https://github.com/mendersoftware/mender-image-tests/compare/5405aa3c2b0bd8a6219820720e023363f090881c...074bb74c4828ea8c265f0cc40781f312bc17ed5e)
  
  ---
  updated-dependencies:
  - dependency-name: tests/mender-image-tests
    dependency-type: direct:production
  ...
- Bump filelock in /tests in the python-test-dependencies group
 ([b051bd7](https://github.com/mendersoftware/mender-convert/commit/b051bd7e15a78adfa4831f45e8fef6f7265d8a2f))  by @dependabot[bot]


  Bumps the python-test-dependencies group in /tests with 1 update: [filelock](https://github.com/tox-dev/py-filelock).
  
  
  Updates `filelock` from 3.16.1 to 3.17.0
  - [Release notes](https://github.com/tox-dev/py-filelock/releases)
  - [Changelog](https://github.com/tox-dev/filelock/blob/main/docs/changelog.rst)
  - [Commits](https://github.com/tox-dev/py-filelock/compare/3.16.1...3.17.0)
  
  ---
  updated-dependencies:
  - dependency-name: filelock
    dependency-type: direct:production
    update-type: version-update:semver-minor
    dependency-group: python-test-dependencies
  ...
- Bump jsdom from 25.0.1 to 26.0.0 in /scripts/linkbot
 ([37bb957](https://github.com/mendersoftware/mender-convert/commit/37bb9575200f14f6384933f867def79214e998bf))  by @dependabot[bot]


  Bumps [jsdom](https://github.com/jsdom/jsdom) from 25.0.1 to 26.0.0.
  - [Release notes](https://github.com/jsdom/jsdom/releases)
  - [Changelog](https://github.com/jsdom/jsdom/blob/main/Changelog.md)
  - [Commits](https://github.com/jsdom/jsdom/compare/25.0.1...26.0.0)
  
  ---
  updated-dependencies:
  - dependency-name: jsdom
    dependency-type: direct:production
    update-type: version-update:semver-major
  ...
- Bump tests/mender-image-tests from `074bb74` to `a03b5fd`
 ([03abc36](https://github.com/mendersoftware/mender-convert/commit/03abc367539d74a35d450f3a71fcdc9e0e155898))  by @dependabot[bot]


  Bumps [tests/mender-image-tests](https://github.com/mendersoftware/mender-image-tests) from `074bb74` to `a03b5fd`.
  - [Commits](https://github.com/mendersoftware/mender-image-tests/compare/074bb74c4828ea8c265f0cc40781f312bc17ed5e...a03b5fd7465e079442ec2667823ab70ca625d085)
  
  ---
  updated-dependencies:
  - dependency-name: tests/mender-image-tests
    dependency-type: direct:production
  ...
- Bump the python-test-dependencies group in /tests with 2 updates
 ([a40d044](https://github.com/mendersoftware/mender-convert/commit/a40d04400863e4a10b921071a6b5535f834566f9))  by @dependabot[bot]


  Bumps the python-test-dependencies group in /tests with 2 updates: [filelock](https://github.com/tox-dev/py-filelock) and [pytest](https://github.com/pytest-dev/pytest).
  
  
  Updates `filelock` from 3.17.0 to 3.18.0
  - [Release notes](https://github.com/tox-dev/py-filelock/releases)
  - [Changelog](https://github.com/tox-dev/filelock/blob/main/docs/changelog.rst)
  - [Commits](https://github.com/tox-dev/py-filelock/compare/3.17.0...3.18.0)
  
  Updates `pytest` from 8.3.4 to 8.3.5
  - [Release notes](https://github.com/pytest-dev/pytest/releases)
  - [Changelog](https://github.com/pytest-dev/pytest/blob/main/CHANGELOG.rst)
  - [Commits](https://github.com/pytest-dev/pytest/compare/8.3.4...8.3.5)
  
  ---
  updated-dependencies:
  - dependency-name: filelock
    dependency-version: 3.18.0
    dependency-type: direct:production
    update-type: version-update:semver-minor
    dependency-group: python-test-dependencies
  - dependency-name: pytest
    dependency-version: 8.3.5
    dependency-type: direct:production
    update-type: version-update:semver-patch
    dependency-group: python-test-dependencies
  ...
- Bump jinja2 from 3.1.5 to 3.1.6 in /tests
 ([48a73a2](https://github.com/mendersoftware/mender-convert/commit/48a73a27f8af6158b7ed55a38563a551fcbef29c))  by @dependabot[bot]


  Bumps [jinja2](https://github.com/pallets/jinja) from 3.1.5 to 3.1.6.
  - [Release notes](https://github.com/pallets/jinja/releases)
  - [Changelog](https://github.com/pallets/jinja/blob/main/CHANGES.rst)
  - [Commits](https://github.com/pallets/jinja/compare/3.1.5...3.1.6)
  
  ---
  updated-dependencies:
  - dependency-name: jinja2
    dependency-version: 3.1.6
    dependency-type: indirect
  ...
- Bump jsdom from 26.0.0 to 26.1.0 in /scripts/linkbot
 ([a2fef50](https://github.com/mendersoftware/mender-convert/commit/a2fef50fe87edfd85e05bfbf3a19e6990dcfd16c))  by @dependabot[bot]


  Bumps [jsdom](https://github.com/jsdom/jsdom) from 26.0.0 to 26.1.0.
  - [Release notes](https://github.com/jsdom/jsdom/releases)
  - [Changelog](https://github.com/jsdom/jsdom/blob/main/Changelog.md)
  - [Commits](https://github.com/jsdom/jsdom/compare/26.0.0...26.1.0)
  
  ---
  updated-dependencies:
  - dependency-name: jsdom
    dependency-version: 26.1.0
    dependency-type: direct:production
    update-type: version-update:semver-minor
  ...
- Bump the python-test-dependencies group across 1 directory with 3 updates
 ([1c55aef](https://github.com/mendersoftware/mender-convert/commit/1c55aef03e0bd7a25a523443872e663a1a2ccb93))  by @dependabot[bot]


  Bumps the python-test-dependencies group with 3 updates in the /tests directory: [pytest](https://github.com/pytest-dev/pytest), [pytest-xdist](https://github.com/pytest-dev/pytest-xdist) and [requests](https://github.com/psf/requests).
  
  
  Updates `pytest` from 8.3.5 to 8.4.0
  - [Release notes](https://github.com/pytest-dev/pytest/releases)
  - [Changelog](https://github.com/pytest-dev/pytest/blob/main/CHANGELOG.rst)
  - [Commits](https://github.com/pytest-dev/pytest/compare/8.3.5...8.4.0)
  
  Updates `pytest-xdist` from 3.6.1 to 3.7.0
  - [Release notes](https://github.com/pytest-dev/pytest-xdist/releases)
  - [Changelog](https://github.com/pytest-dev/pytest-xdist/blob/master/CHANGELOG.rst)
  - [Commits](https://github.com/pytest-dev/pytest-xdist/compare/v3.6.1...v3.7.0)
  
  Updates `requests` from 2.32.3 to 2.32.4
  - [Release notes](https://github.com/psf/requests/releases)
  - [Changelog](https://github.com/psf/requests/blob/main/HISTORY.md)
  - [Commits](https://github.com/psf/requests/compare/v2.32.3...v2.32.4)
  
  ---
  updated-dependencies:
  - dependency-name: pytest
    dependency-version: 8.4.0
    dependency-type: direct:production
    update-type: version-update:semver-minor
    dependency-group: python-test-dependencies
  - dependency-name: pytest-xdist
    dependency-version: 3.7.0
    dependency-type: direct:production
    update-type: version-update:semver-minor
    dependency-group: python-test-dependencies
  - dependency-name: requests
    dependency-version: 2.32.4
    dependency-type: direct:production
    update-type: version-update:semver-patch
    dependency-group: python-test-dependencies
  ...
- Bump urllib3 from 1.26.19 to 2.5.0 in /tests
 ([a2bda71](https://github.com/mendersoftware/mender-convert/commit/a2bda7170f827d3b4c1486ec42b7c0a9b71344af))  by @danielskinstad


  Bumps [urllib3](https://github.com/urllib3/urllib3) from 1.26.19 to 2.5.0.
  - [Release notes](https://github.com/urllib3/urllib3/releases)
  - [Changelog](https://github.com/urllib3/urllib3/blob/main/CHANGES.rst)
  - [Commits](https://github.com/urllib3/urllib3/compare/1.26.19...2.5.0)
  
  ---
  updated-dependencies:
  - dependency-name: urllib3
    dependency-version: 2.5.0
    dependency-type: indirect
  ...
  
  Install awscli2 because of
  `ImportError: cannot import name 'DEFAULT_CIPHERS' from 'urllib3.util.ssl_'`
  See https://github.com/aws/aws-cli/issues/7905
- Bump tests/mender-image-tests from `a03b5fd` to `e5ff4e5`
 ([66aed83](https://github.com/mendersoftware/mender-convert/commit/66aed833474bf36487f19858c5715a0ba4640f09))  by @dependabot[bot]


  Bumps [tests/mender-image-tests](https://github.com/mendersoftware/mender-image-tests) from `a03b5fd` to `e5ff4e5`.
  - [Commits](https://github.com/mendersoftware/mender-image-tests/compare/a03b5fd7465e079442ec2667823ab70ca625d085...e5ff4e596e9137ec90a297f5e53358a5f3033484)
  
  ---
  updated-dependencies:
  - dependency-name: tests/mender-image-tests
    dependency-version: e5ff4e596e9137ec90a297f5e53358a5f3033484
    dependency-type: direct:production
  ...
- Bump pytest-xdist in /tests in the python-test-dependencies group
 ([eb04be3](https://github.com/mendersoftware/mender-convert/commit/eb04be33c9b07a8456b7aabc21666981e71aca1f))  by @dependabot[bot]


  Bumps the python-test-dependencies group in /tests with 1 update: [pytest-xdist](https://github.com/pytest-dev/pytest-xdist).
  
  
  Updates `pytest-xdist` from 3.7.0 to 3.8.0
  - [Release notes](https://github.com/pytest-dev/pytest-xdist/releases)
  - [Changelog](https://github.com/pytest-dev/pytest-xdist/blob/master/CHANGELOG.rst)
  - [Commits](https://github.com/pytest-dev/pytest-xdist/compare/v3.7.0...v3.8.0)
  
  ---
  updated-dependencies:
  - dependency-name: pytest-xdist
    dependency-version: 3.8.0
    dependency-type: direct:production
    update-type: version-update:semver-minor
    dependency-group: python-test-dependencies
  ...




### Build


- Update to latest `mender-artifact` version
([MEN-8269](https://northerntech.atlassian.net/browse/MEN-8269)) ([65a3be8](https://github.com/mendersoftware/mender-convert/commit/65a3be8a94cd1a7c747c24a19de761a26ff44883))  by @lluiscampos## Bug fixes


- Do not use world-writable permissions for mender-convert image.
 ([6a74029](https://github.com/mendersoftware/mender-convert/commit/6a7402947fecdd3d35df902b586dd0dc4bac3747)) 


  The image is only used in the build itself, so it's unlikely to be a
  security issue. It does not affect output images.
- Fix writing MSDOS partition UUIDs
([MEN-7937](https://northerntech.atlassian.net/browse/MEN-7937)) ([af0a17d](https://github.com/mendersoftware/mender-convert/commit/af0a17d3ca0793fa3bc9328f98173ef4b0408144))  by @jo-lund


  rev works on unicode strings and is therefore not safe to use to swap bytes.
- Preserve extended attribute with rsync
 ([b9988ee](https://github.com/mendersoftware/mender-convert/commit/b9988eeb87fe1350fc2baae15798e796a4e1958a))  by @timbz
- Update `grub-mender-grubenv` version
([ME-458](https://northerntech.atlassian.net/browse/ME-458)) ([10817e5](https://github.com/mendersoftware/mender-convert/commit/10817e5e2c88d1667329b6ba865f6de04a4fd5bf))  by @lluiscampos
- Expand the data partition into the empty space on boot
([MEN-8191](https://northerntech.atlassian.net/browse/MEN-8191)) ([d04876a](https://github.com/mendersoftware/mender-convert/commit/d04876acfa437454a7685ba4f59d4c13deeb8300))  by @jo-lund


  When MENDER_DATA_PART_GROWFS is "y" (which is default), x-systemd.growfs
  will be set for the data partition in /etc/fstab. This option is understood
  by systemd and will grow the file system to occupy the full block device.
  However, the partition itself will not necessarily be expanded. For
  Raspberry Pi a systemd script could be used that would run "parted"
  to expand the partition. This is now done for all systems.
- Systemd_common_config: add --fix option to parted call
 ([ef68160](https://github.com/mendersoftware/mender-convert/commit/ef6816058bfa406ca925928f177e188f838c9645))  by @chlongv


  In case when the GPT header does not include the full disk size (can
  happen to generate smaller images), parted is going to fail because of
  an exception.
  
  Add the --fix option to fix those exceptions and allow parted to resize
  the data partition.




### Documentation


- Update example commands in README
 ([f81ba6b](https://github.com/mendersoftware/mender-convert/commit/f81ba6b57acf174afc72cbac22eceeba175d0036))  by @lluiscampos


  Follow-up from 495c5e601f3cc52d152f651ff3a53aafce2b69b7
- Update command to decompress the image
 ([49f5654](https://github.com/mendersoftware/mender-convert/commit/49f565468799905dc4ba4a5beab9513f725cbf4e))  by @lluiscampos
- Rewrite comment for `MENDER_CLIENT_VERSION`
 ([0486ffb](https://github.com/mendersoftware/mender-convert/commit/0486ffbabb3c788dd5668fd54c2173dee7bd2978))  by @lluiscampos


  To clarify what `auto` will do in the context of the recently released
  Mender Client 5.0.
- Update run-tests readme
 ([d4a676d](https://github.com/mendersoftware/mender-convert/commit/d4a676d5ed17024548d58c20d9fe26d2e4501bdf))  by @danielskinstad
- Extend UEFI NVRAM guide for future Ubuntu 24.04 upgrade
 ([6b787b6](https://github.com/mendersoftware/mender-convert/commit/6b787b6a7606f74feab09890179dfe7df8dc98d5))  by @lluiscampos




### Features


- *(uefi)* Implement support for RPi4 `cmdline.txt` boot file.
([MEN-5826](https://northerntech.atlassian.net/browse/MEN-5826)) ([59816ee](https://github.com/mendersoftware/mender-convert/commit/59816ee8137881f5df9743ba9ebe351cbdc24baf)) 


  This is required to run the "firstboot" Raspberry Pi setup
  correctly. It also makes sure that custom boot options in that file
  are actually respected.

- Add a `platform_pre_modify` hook.
 ([9b4cae4](https://github.com/mendersoftware/mender-convert/commit/9b4cae4eb4bfdf73cd70c2ed06ca7813641ced86)) 


  This runs before modifications, but after the image has been mounted,
  so that it's ready to receive modifications.
- Introduce basic support for booting Raspberry Pi 4 using UEFI.
([MEN-5826](https://northerntech.atlassian.net/browse/MEN-5826)) ([e5fba41](https://github.com/mendersoftware/mender-convert/commit/e5fba4163ec04771f83f601b97216d784d254c14)) 


  With this we can boot Raspberry Pi 4 using UEFI, but it provides no
  integration beyond the mere boot itself, which works, but presents
  some problems. These will be fixed in upcoming commits.
- Upgrade Raspberry Pi 3 pre-built image to Debian 12 64bits
([MEN-7759](https://northerntech.atlassian.net/browse/MEN-7759)) ([c4b47f3](https://github.com/mendersoftware/mender-convert/commit/c4b47f3d1523d2ba4fffc9cba5d7082b2b7f4e67))  by @lluiscampos


  This commit restores the Raspberry Pi 3 pre-built image build and
  publish, but modifying it from being based in the 32bits one to the 64
  bits one.

- Create sparse images
 ([c90d8df](https://github.com/mendersoftware/mender-convert/commit/c90d8df9d719f5dbdcbc557e1338ae07d6604f00))  by @ygerlach


  Instead of allocating the whole image on the disk, only allocate the parts that actually contain data. This reduces the required disk space to store or create images.
  This feature is disabled by default and can be enabled with the `MENDER_SPARSE_IMAGE` configuration flag.
- Warn for signs of external  mender installation
 ([b4eab2a](https://github.com/mendersoftware/mender-convert/commit/b4eab2aa8529df858a1cbc253b0770addff92171))  by @TheMeaningfulEngineer


- Update GRUB to version 2.12
 ([4f180a2](https://github.com/mendersoftware/mender-convert/commit/4f180a2356054b8342cf0eefa886bd602ebc99e5))  by @lluiscampos


  Following the update from `grub-mender-grubenv` repository from January
  2025:
  * https://github.com/mendersoftware/grub-mender-grubenv/pull/39
- Use the `device-components` repository
 ([150095d](https://github.com/mendersoftware/mender-convert/commit/150095d717ebeea40f1993738f8d4303a2fa8864))  by @danielskinstad
- Use `apt install some-package` to install Mender packages
([MEN-8476](https://northerntech.atlassian.net/browse/MEN-8476)) ([44920dc](https://github.com/mendersoftware/mender-convert/commit/44920dca944c8bca9cc2a6ed06d3b1a3d51fc3bb))  by @vpodzime
  - **BREAKING**: apt is now used to install Mender packages from
the repositories instead of dpkg installing individual packages


  Instead of custom magic downloading and installing individual
  packages from the repos, `apt` package manager is now used to do
  its job, including dependency resolution and installation, and
  signature+checksum verification, among other things.




### Security


- Bump tests/mender-image-tests from `698cb01` to `5405aa3`
 ([88d0240](https://github.com/mendersoftware/mender-convert/commit/88d0240790e49171a3d889dcc44f007321493929))  by @dependabot[bot]


  Bumps [tests/mender-image-tests](https://github.com/mendersoftware/mender-image-tests) from `698cb01` to `5405aa3`.
  - [Commits](https://github.com/mendersoftware/mender-image-tests/compare/698cb01171f7ef1faaabbe8311f21a06cf1a0432...5405aa3c2b0bd8a6219820720e023363f090881c)
  
  ---
  updated-dependencies:
  - dependency-name: tests/mender-image-tests
    dependency-type: direct:production
  ...
- Bump pytest in /tests in the python-test-dependencies group
 ([afff8f2](https://github.com/mendersoftware/mender-convert/commit/afff8f2d1151c7cfeb0e5b6eab650c87314b2a0a))  by @dependabot[bot]


  Bumps the python-test-dependencies group in /tests with 1 update: [pytest](https://github.com/pytest-dev/pytest).
  
  
  Updates `pytest` from 8.3.3 to 8.3.4
  - [Release notes](https://github.com/pytest-dev/pytest/releases)
  - [Changelog](https://github.com/pytest-dev/pytest/blob/main/CHANGELOG.rst)
  - [Commits](https://github.com/pytest-dev/pytest/compare/8.3.3...8.3.4)
  
  ---
  updated-dependencies:
  - dependency-name: pytest
    dependency-type: direct:production
    update-type: version-update:semver-patch
    dependency-group: python-test-dependencies
  ...
- Bump jinja2 from 3.1.4 to 3.1.5 in /tests
 ([b2e6c67](https://github.com/mendersoftware/mender-convert/commit/b2e6c67a8c0acd17ce718ac7eec0df71539e7d79))  by @dependabot[bot]


  Bumps [jinja2](https://github.com/pallets/jinja) from 3.1.4 to 3.1.5.
  - [Release notes](https://github.com/pallets/jinja/releases)
  - [Changelog](https://github.com/pallets/jinja/blob/main/CHANGES.rst)
  - [Commits](https://github.com/pallets/jinja/compare/3.1.4...3.1.5)
  
  ---
  updated-dependencies:
  - dependency-name: jinja2
    dependency-type: indirect
  ...
- Bump tests/mender-image-tests from `5405aa3` to `074bb74`
 ([c8c7eb9](https://github.com/mendersoftware/mender-convert/commit/c8c7eb93181f43e2fb6e8613adf554411e482106))  by @dependabot[bot]


  Bumps [tests/mender-image-tests](https://github.com/mendersoftware/mender-image-tests) from `5405aa3` to `074bb74`.
  - [Commits](https://github.com/mendersoftware/mender-image-tests/compare/5405aa3c2b0bd8a6219820720e023363f090881c...074bb74c4828ea8c265f0cc40781f312bc17ed5e)
  
  ---
  updated-dependencies:
  - dependency-name: tests/mender-image-tests
    dependency-type: direct:production
  ...
- Bump filelock in /tests in the python-test-dependencies group
 ([b051bd7](https://github.com/mendersoftware/mender-convert/commit/b051bd7e15a78adfa4831f45e8fef6f7265d8a2f))  by @dependabot[bot]


  Bumps the python-test-dependencies group in /tests with 1 update: [filelock](https://github.com/tox-dev/py-filelock).
  
  
  Updates `filelock` from 3.16.1 to 3.17.0
  - [Release notes](https://github.com/tox-dev/py-filelock/releases)
  - [Changelog](https://github.com/tox-dev/filelock/blob/main/docs/changelog.rst)
  - [Commits](https://github.com/tox-dev/py-filelock/compare/3.16.1...3.17.0)
  
  ---
  updated-dependencies:
  - dependency-name: filelock
    dependency-type: direct:production
    update-type: version-update:semver-minor
    dependency-group: python-test-dependencies
  ...
- Bump jsdom from 25.0.1 to 26.0.0 in /scripts/linkbot
 ([37bb957](https://github.com/mendersoftware/mender-convert/commit/37bb9575200f14f6384933f867def79214e998bf))  by @dependabot[bot]


  Bumps [jsdom](https://github.com/jsdom/jsdom) from 25.0.1 to 26.0.0.
  - [Release notes](https://github.com/jsdom/jsdom/releases)
  - [Changelog](https://github.com/jsdom/jsdom/blob/main/Changelog.md)
  - [Commits](https://github.com/jsdom/jsdom/compare/25.0.1...26.0.0)
  
  ---
  updated-dependencies:
  - dependency-name: jsdom
    dependency-type: direct:production
    update-type: version-update:semver-major
  ...
- Bump tests/mender-image-tests from `074bb74` to `a03b5fd`
 ([03abc36](https://github.com/mendersoftware/mender-convert/commit/03abc367539d74a35d450f3a71fcdc9e0e155898))  by @dependabot[bot]


  Bumps [tests/mender-image-tests](https://github.com/mendersoftware/mender-image-tests) from `074bb74` to `a03b5fd`.
  - [Commits](https://github.com/mendersoftware/mender-image-tests/compare/074bb74c4828ea8c265f0cc40781f312bc17ed5e...a03b5fd7465e079442ec2667823ab70ca625d085)
  
  ---
  updated-dependencies:
  - dependency-name: tests/mender-image-tests
    dependency-type: direct:production
  ...
- Bump the python-test-dependencies group in /tests with 2 updates
 ([a40d044](https://github.com/mendersoftware/mender-convert/commit/a40d04400863e4a10b921071a6b5535f834566f9))  by @dependabot[bot]


  Bumps the python-test-dependencies group in /tests with 2 updates: [filelock](https://github.com/tox-dev/py-filelock) and [pytest](https://github.com/pytest-dev/pytest).
  
  
  Updates `filelock` from 3.17.0 to 3.18.0
  - [Release notes](https://github.com/tox-dev/py-filelock/releases)
  - [Changelog](https://github.com/tox-dev/filelock/blob/main/docs/changelog.rst)
  - [Commits](https://github.com/tox-dev/py-filelock/compare/3.17.0...3.18.0)
  
  Updates `pytest` from 8.3.4 to 8.3.5
  - [Release notes](https://github.com/pytest-dev/pytest/releases)
  - [Changelog](https://github.com/pytest-dev/pytest/blob/main/CHANGELOG.rst)
  - [Commits](https://github.com/pytest-dev/pytest/compare/8.3.4...8.3.5)
  
  ---
  updated-dependencies:
  - dependency-name: filelock
    dependency-version: 3.18.0
    dependency-type: direct:production
    update-type: version-update:semver-minor
    dependency-group: python-test-dependencies
  - dependency-name: pytest
    dependency-version: 8.3.5
    dependency-type: direct:production
    update-type: version-update:semver-patch
    dependency-group: python-test-dependencies
  ...
- Bump jinja2 from 3.1.5 to 3.1.6 in /tests
 ([48a73a2](https://github.com/mendersoftware/mender-convert/commit/48a73a27f8af6158b7ed55a38563a551fcbef29c))  by @dependabot[bot]


  Bumps [jinja2](https://github.com/pallets/jinja) from 3.1.5 to 3.1.6.
  - [Release notes](https://github.com/pallets/jinja/releases)
  - [Changelog](https://github.com/pallets/jinja/blob/main/CHANGES.rst)
  - [Commits](https://github.com/pallets/jinja/compare/3.1.5...3.1.6)
  
  ---
  updated-dependencies:
  - dependency-name: jinja2
    dependency-version: 3.1.6
    dependency-type: indirect
  ...
- Bump jsdom from 26.0.0 to 26.1.0 in /scripts/linkbot
 ([a2fef50](https://github.com/mendersoftware/mender-convert/commit/a2fef50fe87edfd85e05bfbf3a19e6990dcfd16c))  by @dependabot[bot]


  Bumps [jsdom](https://github.com/jsdom/jsdom) from 26.0.0 to 26.1.0.
  - [Release notes](https://github.com/jsdom/jsdom/releases)
  - [Changelog](https://github.com/jsdom/jsdom/blob/main/Changelog.md)
  - [Commits](https://github.com/jsdom/jsdom/compare/26.0.0...26.1.0)
  
  ---
  updated-dependencies:
  - dependency-name: jsdom
    dependency-version: 26.1.0
    dependency-type: direct:production
    update-type: version-update:semver-minor
  ...
- Bump the python-test-dependencies group across 1 directory with 3 updates
 ([1c55aef](https://github.com/mendersoftware/mender-convert/commit/1c55aef03e0bd7a25a523443872e663a1a2ccb93))  by @dependabot[bot]


  Bumps the python-test-dependencies group with 3 updates in the /tests directory: [pytest](https://github.com/pytest-dev/pytest), [pytest-xdist](https://github.com/pytest-dev/pytest-xdist) and [requests](https://github.com/psf/requests).
  
  
  Updates `pytest` from 8.3.5 to 8.4.0
  - [Release notes](https://github.com/pytest-dev/pytest/releases)
  - [Changelog](https://github.com/pytest-dev/pytest/blob/main/CHANGELOG.rst)
  - [Commits](https://github.com/pytest-dev/pytest/compare/8.3.5...8.4.0)
  
  Updates `pytest-xdist` from 3.6.1 to 3.7.0
  - [Release notes](https://github.com/pytest-dev/pytest-xdist/releases)
  - [Changelog](https://github.com/pytest-dev/pytest-xdist/blob/master/CHANGELOG.rst)
  - [Commits](https://github.com/pytest-dev/pytest-xdist/compare/v3.6.1...v3.7.0)
  
  Updates `requests` from 2.32.3 to 2.32.4
  - [Release notes](https://github.com/psf/requests/releases)
  - [Changelog](https://github.com/psf/requests/blob/main/HISTORY.md)
  - [Commits](https://github.com/psf/requests/compare/v2.32.3...v2.32.4)
  
  ---
  updated-dependencies:
  - dependency-name: pytest
    dependency-version: 8.4.0
    dependency-type: direct:production
    update-type: version-update:semver-minor
    dependency-group: python-test-dependencies
  - dependency-name: pytest-xdist
    dependency-version: 3.7.0
    dependency-type: direct:production
    update-type: version-update:semver-minor
    dependency-group: python-test-dependencies
  - dependency-name: requests
    dependency-version: 2.32.4
    dependency-type: direct:production
    update-type: version-update:semver-patch
    dependency-group: python-test-dependencies
  ...
- Bump urllib3 from 1.26.19 to 2.5.0 in /tests
 ([a2bda71](https://github.com/mendersoftware/mender-convert/commit/a2bda7170f827d3b4c1486ec42b7c0a9b71344af))  by @danielskinstad


  Bumps [urllib3](https://github.com/urllib3/urllib3) from 1.26.19 to 2.5.0.
  - [Release notes](https://github.com/urllib3/urllib3/releases)
  - [Changelog](https://github.com/urllib3/urllib3/blob/main/CHANGES.rst)
  - [Commits](https://github.com/urllib3/urllib3/compare/1.26.19...2.5.0)
  
  ---
  updated-dependencies:
  - dependency-name: urllib3
    dependency-version: 2.5.0
    dependency-type: indirect
  ...
  
  Install awscli2 because of
  `ImportError: cannot import name 'DEFAULT_CIPHERS' from 'urllib3.util.ssl_'`
  See https://github.com/aws/aws-cli/issues/7905
- Bump tests/mender-image-tests from `a03b5fd` to `e5ff4e5`
 ([66aed83](https://github.com/mendersoftware/mender-convert/commit/66aed833474bf36487f19858c5715a0ba4640f09))  by @dependabot[bot]


  Bumps [tests/mender-image-tests](https://github.com/mendersoftware/mender-image-tests) from `a03b5fd` to `e5ff4e5`.
  - [Commits](https://github.com/mendersoftware/mender-image-tests/compare/a03b5fd7465e079442ec2667823ab70ca625d085...e5ff4e596e9137ec90a297f5e53358a5f3033484)
  
  ---
  updated-dependencies:
  - dependency-name: tests/mender-image-tests
    dependency-version: e5ff4e596e9137ec90a297f5e53358a5f3033484
    dependency-type: direct:production
  ...
- Bump pytest-xdist in /tests in the python-test-dependencies group
 ([eb04be3](https://github.com/mendersoftware/mender-convert/commit/eb04be33c9b07a8456b7aabc21666981e71aca1f))  by @dependabot[bot]


  Bumps the python-test-dependencies group in /tests with 1 update: [pytest-xdist](https://github.com/pytest-dev/pytest-xdist).
  
  
  Updates `pytest-xdist` from 3.7.0 to 3.8.0
  - [Release notes](https://github.com/pytest-dev/pytest-xdist/releases)
  - [Changelog](https://github.com/pytest-dev/pytest-xdist/blob/master/CHANGELOG.rst)
  - [Commits](https://github.com/pytest-dev/pytest-xdist/compare/v3.7.0...v3.8.0)
  
  ---
  updated-dependencies:
  - dependency-name: pytest-xdist
    dependency-version: 3.8.0
    dependency-type: direct:production
    update-type: version-update:semver-minor
    dependency-group: python-test-dependencies
  ...




### Build


- Update to latest `mender-artifact` version
([MEN-8269](https://northerntech.atlassian.net/browse/MEN-8269)) ([65a3be8](https://github.com/mendersoftware/mender-convert/commit/65a3be8a94cd1a7c747c24a19de761a26ff44883))  by @lluiscampos







## mender-convert 4.3.0

_Released 12.18.2024_

### Changelogs

#### mender-convert (4.3.0)

New changes in mender-convert since 4.2.3:

##### Bug fixes

* allow installation of deb packages with spaces
  ([MEN-7264](https://northerntech.atlassian.net/browse/MEN-7264))
* correctly check that RASPBERRYPI_OS_REQUIRED_ID is set

##### Features

* Add the possibility to install arbitrary debian packages
  located in `MENDER_INSTALL_INPUT_PACKAGES_PATH` to the converted image.
  ([MEN-7264](https://northerntech.atlassian.net/browse/MEN-7264))
* support assets directory for local data
* `mender-convert` Docker build is now architecture aware and
  it will install the native dependencies for the target architecture.
  This change makes the tool compatible with Apple arm machines. The Docker
  images will be published for `linux/amd64` and `linux/arm64` platforms.
* Added ext3 filesystem support
* make boot partition mount point configurable
* extend Raspberry Pi support to bookworm

  The Debian release 12 "bookworm" introduced the /boot/firmware
  mount point for the boot partition, which is a breaking change.

  The upgrade therefore involves these adjustments:
  - use the "check_image_os" function to check the Linux distribution
    release requirement on the supplied image
  - set MENDER_BOOT_PART_MOUNTPOINT to /boot/firmware
  - remove the /uboot directory creation and related modifications
    of scripts shipped with the supplied image.
  - copy the device tree overlays from the boot partition to /boot
    so they can be accessed from u-boot

  To facilitate maintenance, some functionality has been factored out
  into the raspberrypi_common_config file.

  Currently checks for the required Linux distribution family and version,
  e.g. "debian" and "12" (reflects "bookworm") are included. This is
  common for both the already existing 32bit and upcoming 64bit configs,
  so it prepares the version bump and aarch64 extension.

  On Debian 11 "bullseye" (or derivatives) and earlier, the boot
  partition is mounted to /uboot in the u-boot integration path.
  As several scripts rely on the files located on the patition,
  we need to adjust those.
* add support for Raspberry Pi OS 64bit

  Add support for Raspberry Pi OS 64bit, based on Debian 12
  "bookworm", including configuration for Raspberry Pi 4
  The logic is very close to the 32bit version, with the
  exceptions:
  - the kernel image filename is always kernel8.img, which
    in the supplied image is in fact a gzipped vmlinux file
  - the checks are on 64bit binaries, and the enforcement o
    32bit execution is removed.
  - No support for non-Debian images.

  Add the initial base 64b configuration and extend with
  an explicit instatiations of RPi4 "bullseye" and "bookworm"
  ([MEN-3663](https://northerntech.atlassian.net/browse/MEN-3663))
* raspberrypi_common: support local assets
* support Raspberry Pi 5, bookworm 64bit
* Upgrade Raspberry Pi 3 pre-built image to Debian 12 64bits
  ([MEN-7759](https://northerntech.atlassian.net/browse/MEN-7759))
* Support for sparse images to save storage space. It is disabled by default and can be enabled with `MENDER_SPARSE_IMAGE` configuration flag

##### Other

* Remove Beaglebone from supported boards.

  Beaglebone has not worked for quite some time with the latest images,
  due to problems with booting using UEFI and GRUB. The last version
  to support it, Debian Buster, has now gone out of support, so
  therefore we remove support in mender-convert as well.
* update README for Raspberry Pi OS support
* Raspberry Pi configs have changed names. Please see the
  `README.md` files for the new names.


## mender-convert 4.2.3

_Released 12.02.2024_

### Changelogs

#### mender-convert (4.2.3)

New changes in mender-convert since 4.2.2:

##### Bug fixes

* `docker-mender-convert` wrapper updated to support
  multiple branches pointing to the same reference and
  detached HEAD
* Modify the list of available APT distros from where to get
  Mender software by adding `debian/bookworm` and `ubuntu/noble` and
  removing `ubuntu/focal`.

##### Other

* Fallback to Debian Bullseye packages when target distribution
  is not supported, printing a user facing warning when doing so.


## mender-convert 4.2.2

_Released 06.12.2024_

### Changelogs

#### mender-convert (4.2.2)

New changes in mender-convert since 4.2.1:

##### Bug fixes

* Make sure that `/data` mountpoint exists when using a R/O rootfs.
  ([MEN-7219](https://northerntech.atlassian.net/browse/MEN-7219))
* Fix installation of Mender client v4 when the user specifies
  the exact version to use with `MENDER_CLIENT_VERSION=a.b.c`. Using
  `auto` (default) or `latest` does not trigger this bug.
  ([MEN-7325](https://northerntech.atlassian.net/browse/MEN-7325))


## mender-convert 4.2.1

_Released 05.16.2024_

### Changelogs

#### mender-convert (4.2.1)

New changes in mender-convert since 4.2.0:

##### Bug fixes

* Fix occasional failure when handling service files.
  ([MEN-7143](https://northerntech.atlassian.net/browse/MEN-7143))
* Fix boot problems on RaspiOS images.
  ([MEN-7143](https://northerntech.atlassian.net/browse/MEN-7143))
* Make sure rootfs-image updates also updates the kernel.
* Fix boot failure on Ubuntu image for Raspberry Pi.
* Missing DTB inclusion in armbian-based images
* Remove incorrect warning about `64bit` ext4 flag.
  ([MEN-6027](https://northerntech.atlassian.net/browse/MEN-6027))


## mender-convert 4.2.0

_Released 03.21.2024_

### Changelogs

#### mender-convert (4.2.0)

New changes in mender-convert since 4.1.1:

##### Bug fixes

* Remove unneeded `mender_grub_storage_device` assignment
  which could boot from the wrong device if a USB stick was inserted.

##### Features

* From Mender client v4 onwards, the client is distributed in
  two separate packages: `mender-auth` and `mender-update`. Now
  `mender-convert` installs these two when installing the client.
  ([MEN-6282](https://northerntech.atlassian.net/browse/MEN-6282))
* Install `mender-flash` when installing the Mender client
  ([MEN-6282](https://northerntech.atlassian.net/browse/MEN-6282))
* Switch to install packages using Debian package manager.
  This means that the files are no longer simply extracted into place,
  which has been a big source of conflict with the package manager when
  doing later upgrades. It also means that a default `mender.conf` file
  will be provided if `mender-setup` is installed, since it installs it
  by default.
  ([MEN-6935](https://northerntech.atlassian.net/browse/MEN-6935))
* Install mender-setup and mender-snapshot by default when
  Mender client 4.0 or later is selected. Previously they were built-in,
  but are now optional and can be turned off with:
  ```
  MENDER_SETUP_INSTALL=n
  MENDER_SNAPSHOT_INSTALL=n
  ```
  to save space.
  ([MEN-6935](https://northerntech.atlassian.net/browse/MEN-6935))
* add support for `MENDER_CLIENT_VERSION="auto"`, which installs the Mender Client 3.x series for Debian bullseye and buster and for Ubuntu jammy and focal, the Mender Client 4.x series for all the other distributions
  ([MEN-6976](https://northerntech.atlassian.net/browse/MEN-6976))

##### Other

* The `mender-client-data-dir.service` has been renamed to
  `mender-data-dir.service`. This is used as a dependency for the mender
  update client, and most users should not notice the change.
* Update the rpi bullseye image to the 2023-05-03 release.


## mender-convert 4.1.1

_Released 01.15.2024_

### Statistics

A total of 4 lines added, 3 removed (delta 1)

| Developers with the most changesets | |
|---|---|
| Lluis Campos | 2 (100.0%) |

| Developers with the most changed lines | |
|---|---|
| Lluis Campos | 4 (100.0%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 2 (100.0%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 4 (100.0%) |

| Employers with the most hackers (total 1) | |
|---|---|
| Northern.tech | 1 (100.0%) |

### Changelogs

#### mender-convert (4.1.1)

New changes in mender-convert since 4.1.0:

* Set default `MENDER_CLIENT_VERSION` to 3.5.2.
  `mender-convert` is not yet integrated with upcoming client v4.
  ([MEN-6948](https://northerntech.atlassian.net/browse/MEN-6948))


## mender-convert 4.1.0

_Released 12.28.2023_

### Statistics

| Developers with the most changesets | |
|---|---|
| Lluis Campos | 5 (29.4%) |
| Kristian Amlie | 5 (29.4%) |
| Michael Mugnai | 2 (11.8%) |
| Julien Roland | 1 (5.9%) |
| Lorenzo Ruffati | 1 (5.9%) |
| Josef Holzmayr | 1 (5.9%) |
| Tom Callahan | 1 (5.9%) |
| Krzysztof Jaskiewicz | 1 (5.9%) |

| Developers with the most changed lines | |
|---|---|
| Kristian Amlie | 106 (45.9%) |
| Lluis Campos | 76 (32.9%) |
| Michael Mugnai | 33 (14.3%) |
| Lorenzo Ruffati | 5 (2.2%) |
| Josef Holzmayr | 5 (2.2%) |
| Julien Roland | 2 (0.9%) |
| Tom Callahan | 2 (0.9%) |
| Krzysztof Jaskiewicz | 2 (0.9%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 12 (70.6%) |
| michael.mugnai@gmail.com | 2 (11.8%) |
| Unikie oy | 1 (5.9%) |
| juroland@gmail.com | 1 (5.9%) |
| 78968887+tcallahan14@users.noreply.github.com | 1 (5.9%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 189 (81.8%) |
| michael.mugnai@gmail.com | 33 (14.3%) |
| Unikie oy | 5 (2.2%) |
| juroland@gmail.com | 2 (0.9%) |
| 78968887+tcallahan14@users.noreply.github.com | 2 (0.9%) |

| Employers with the most hackers (total 8) | |
|---|---|
| Northern.tech | 4 (50.0%) |
| michael.mugnai@gmail.com | 1 (12.5%) |
| Unikie oy | 1 (12.5%) |
| juroland@gmail.com | 1 (12.5%) |
| 78968887+tcallahan14@users.noreply.github.com | 1 (12.5%) |

### Changelogs

#### mender-convert (4.1.0)

New changes in mender-convert since 4.0.3:

##### Bug fixes

* hosted bootstrap script syntax error

##### Features

* add support for BTRFS filesystems


## mender-convert 4.0.3

_Released 10.18.2023_

### Statistics

| Developers with the most changesets | |
|---|---|
| Kristian Amlie | 1 (33.3%) |
| Michael Mugnai | 1 (33.3%) |
| Lorenzo Ruffati | 1 (33.3%) |

| Developers with the most changed lines | |
|---|---|
| Michael Mugnai | 19 (76.0%) |
| Lorenzo Ruffati | 5 (20.0%) |
| Kristian Amlie | 1 (4.0%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 1 (33.3%) |
| michael.mugnai@gmail.com | 1 (33.3%) |
| Unikie Oy | 1 (33.3%) |

| Top lines changed by employer | |
|---|---|
| michael.mugnai@gmail.com | 19 (76.0%) |
| Unikie Oy | 5 (20.0%) |
| Northern.tech | 1 (4.0%) |

| Employers with the most hackers (total 3) | |
|---|---|
| michael.mugnai@gmail.com | 1 (33.3%) |
| Unikie Oy | 1 (33.3%) |
| Northern.tech | 1 (33.3%) |

### Changelogs

#### mender-convert (4.0.3)

New changes in mender-convert since 4.0.2:

##### Bug fixes

* Reorder operation to move data directory before rootfs size is estimated
* fix: hosted bootstrap support for 'eu' region


## mender-convert 4.0.2

_Released 08.25.2023_

### Statistics

A total of 13 lines added, 36 removed (delta -23)

| Developers with the most changesets | |
|---|---|
| Kristian Amlie | 2 (66.7%) |
| Tom Callahan | 1 (33.3%) |

| Developers with the most changed lines | |
|---|---|
| Kristian Amlie | 37 (94.9%) |
| Tom Callahan | 2 (5.1%) |

| Developers with the most lines removed | |
|---|---|
| Kristian Amlie | 23 (63.9%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 2 (66.7%) |
| 78968887+tcallahan14@users.noreply.github.com | 1 (33.3%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 37 (94.9%) |
| 78968887+tcallahan14@users.noreply.github.com | 2 (5.1%) |

| Employers with the most hackers (total 2) | |
|---|---|
| Northern.tech | 1 (50.0%) |
| 78968887+tcallahan14@users.noreply.github.com | 1 (50.0%) |

### Changelogs

#### mender-convert (4.0.2)

New changes in mender-convert since 4.0.1:

##### Bug fixes

* Remove trailing forward slash in overlay path.

  This prevented the overlay from being applied, due to duplicate slashes in the rsync command (mender-convert-modify line 280). The end result was that the /etc/mender/mender.conf file was missing from the final image. Removing the extra forward slash solved the problem.
* Fix convert error when using `MENDER_GRUB_D_INTEGRATION`
  and `MENDER_ENABLE_PARTUUID` together.
  ([MEN-6645](https://northerntech.atlassian.net/browse/MEN-6645))

##### Other

* Drop support for Debian 9 (stretch).


## mender-convert 4.0.1

_Released 03.08.2023_

### Statistics

A total of 1 lines added, 1 removed (delta 0)

| Developers with the most changesets | |
|---|---|
| Kristian Amlie | 1 (100.0%) |

| Developers with the most changed lines | |
|---|---|
| Kristian Amlie | 1 (100.0%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 1 (100.0%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 1 (100.0%) |

| Employers with the most hackers (total 1) | |
|---|---|
| Northern.tech | 1 (100.0%) |

### Changelogs

#### mender-convert (4.0.1)

New changes in mender-convert since 4.0.0:

##### Bug fixes

* grub-mender-grubenv: Fix boot failure because
  `mender_grub_storage_device` is not exported correctly.


## mender-convert 4.0.0

_Released 02.20.2023_

### Statistics

A total of 888 lines added, 770 removed (delta 118)

| Developers with the most changesets | |
|---|---|
| Lluis Campos | 15 (30.0%) |
| Kristian Amlie | 14 (28.0%) |
| Ole Petter Orhagen | 8 (16.0%) |
| Dell Green | 3 (6.0%) |
| Mikael Torp-Holte | 3 (6.0%) |
| Fabio Tranchitella | 3 (6.0%) |
| Manuel Zedel | 2 (4.0%) |
| Sven Bachmann | 1 (2.0%) |
| Alin Alexandru | 1 (2.0%) |

| Developers with the most changed lines | |
|---|---|
| Manuel Zedel | 387 (36.2%) |
| Ole Petter Orhagen | 295 (27.6%) |
| Kristian Amlie | 194 (18.1%) |
| Lluis Campos | 115 (10.8%) |
| Mikael Torp-Holte | 49 (4.6%) |
| Fabio Tranchitella | 13 (1.2%) |
| Dell Green | 8 (0.7%) |
| Sven Bachmann | 5 (0.5%) |
| Alin Alexandru | 3 (0.3%) |

| Developers with the most lines removed | |
|---|---|
| Manuel Zedel | 145 (18.8%) |
| Mikael Torp-Holte | 19 (2.5%) |

| Developers with the most signoffs (total 1) | |
|---|---|
| Kristian Amlie | 1 (100.0%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 45 (90.0%) |
| Ideaworks Ltd | 3 (6.0%) |
| INNOBYTE | 1 (2.0%) |
| dev@mcbachmann.de | 1 (2.0%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 1053 (98.5%) |
| Ideaworks Ltd | 8 (0.7%) |
| dev@mcbachmann.de | 5 (0.5%) |
| INNOBYTE | 3 (0.3%) |

| Employers with the most signoffs (total 1) | |
|---|---|
| Northern.tech | 1 (100.0%) |

| Employers with the most hackers (total 9) | |
|---|---|
| Northern.tech | 6 (66.7%) |
| Ideaworks Ltd | 1 (11.1%) |
| dev@mcbachmann.de | 1 (11.1%) |
| INNOBYTE | 1 (11.1%) |

### Changelogs

#### mender-convert (4.0.0)

New changes in mender-convert since 3.0.1:

##### Bug fixes

* The prebuilt Mender Grub integration now comes with the XFS module
  installed by default. ([ME-6](https://northerntech.atlassian.net/browse/ME-6))
* Support Mender integration in
  `raspberrypi-sys-mods/firstboot` script included in recent Raspberry Pi
  OS images by modifying the hard-coded mount point for the boot partition
  from  `/boot` to `/uboot`.
  ([MEN-5944](https://northerntech.atlassian.net/browse/MEN-5944))
* Support Mender integration in `userconf-pi/userconf-service`
  script included in recent Raspberry Pi OS images by modifying the
  hard-coded mount point for the boot partition from  `/boot` to `/uboot`.
  ([MEN-5954](https://northerntech.atlassian.net/browse/MEN-5954))
* Support Mender integration in
  `raspberrypi-net-mods/wpa_copy` script included in recent Raspberry Pi
  OS images by modifying the hard-coded mount point for the boot partition
  from  `/boot` to `/uboot`.
  ([MEN-5955](https://northerntech.atlassian.net/browse/MEN-5955))
* Supplying configs/mender_convert_demo_config as a
  --config parameter to mender-convert will add/override polling
  interval parameters on top of a mender.conf file found in the
  overlays. ([MEN-5109](https://northerntech.atlassian.net/browse/MEN-5109))
* User must now supply the overlay generated by a
  bootstrap script to mender-convert with the --overlay option in
  order for the scripts to take effect.
  Additionally, the bootstrap scripts may now be called from any
  directory. ([MEN-5109](https://northerntech.atlassian.net/browse/MEN-5109))
* Fix grub.d integration when host and target 32/64 bit
  architectures don't match. Namely: pass the correct `--target` parameter
  to `grub-install` command instead of relaying on host architecture.
  ([MEN-5979](https://northerntech.atlassian.net/browse/MEN-5979))
* grub-mender-grubenv: Add lock file to prevent data races
  when accessing boot environment concurrently.
* grub-mender-grubenv: Fail execution if both environments
  are corrupt.
* grub-mender-grubenv: Recompute checksum after restoring
  environment (new versions of grub-editenv add extra data).
* Project can now be used as a git submodule again
  Ticket: # ([MEN-6305](https://northerntech.atlassian.net/browse/MEN-6305))
* Added support for installing mender client for ubuntu jammy conversions
  Ticket: # ([MEN-6306](https://northerntech.atlassian.net/browse/MEN-6306))
* support added for mender-client deb package data archive compressed with zstd
  ([MEN-6307](https://northerntech.atlassian.net/browse/MEN-6307))

##### Features

* A bootstrap Artifact is now installed in
  /data/mender/bootstrap.mender, on every conversion, adding the ability to have
  the Mender client bootstrap the database without running an update first, thus
  enabling delta-updates to be installed without first running a full rootfs
  update. Please note that this will require a minimum of the Mender client at
  version 3.4.x. However, the generated Artifact is still usable in any case.
  ([MEN-5594](https://northerntech.atlassian.net/browse/MEN-5594))
* use a Docker volume as work area
  ([MEN-5943](https://northerntech.atlassian.net/browse/MEN-5943))


## mender-convert 3.0.2

_Released 03.10.2023_

### Statistics

A total of 115 lines added, 26 removed (delta 89)

| Developers with the most changesets | |
|---|---|
| Lluis Campos | 8 (53.3%) |
| Kristian Amlie | 4 (26.7%) |
| Dell Green | 3 (20.0%) |

| Developers with the most changed lines | |
|---|---|
| Lluis Campos | 68 (59.1%) |
| Kristian Amlie | 39 (33.9%) |
| Dell Green | 8 (7.0%) |

| Developers with the most signoffs (total 1) | |
|---|---|
| Kristian Amlie | 1 (100.0%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 12 (80.0%) |
| Ideaworks Ltd | 3 (20.0%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 107 (93.0%) |
| Ideaworks Ltd | 8 (7.0%) |

| Employers with the most signoffs (total 1) | |
|---|---|
| Northern.tech | 1 (100.0%) |

| Employers with the most hackers (total 3) | |
|---|---|
| Northern.tech | 2 (66.7%) |
| Ideaworks Ltd | 1 (33.3%) |

### Changelogs

#### mender-convert (3.0.2)

New changes in mender-convert since 3.0.1:

##### Bug fixes

* Support Mender integration in
  `raspberrypi-sys-mods/firstboot` script included in recent Raspberry Pi
  OS images by modifying the hard-coded mount point for the boot partition
  from  `/boot` to `/uboot`.
  ([MEN-5944](https://northerntech.atlassian.net/browse/MEN-5944))
* Support Mender integration in `userconf-pi/userconf-service`
  script included in recent Raspberry Pi OS images by modifying the
  hard-coded mount point for the boot partition from  `/boot` to `/uboot`.
  ([MEN-5954](https://northerntech.atlassian.net/browse/MEN-5954))
* Support Mender integration in
  `raspberrypi-net-mods/wpa_copy` script included in recent Raspberry Pi
  OS images by modifying the hard-coded mount point for the boot partition
  from  `/boot` to `/uboot`.
  ([MEN-5955](https://northerntech.atlassian.net/browse/MEN-5955))
* Fix grub.d integration when host and target 32/64 bit
  architectures don't match. Namely: pass the correct `--target` parameter
  to `grub-install` command instead of relaying on host architecture.
  ([MEN-5979](https://northerntech.atlassian.net/browse/MEN-5979))
* grub-mender-grubenv: Add lock file to prevent data races
  when accessing boot environment concurrently.
* grub-mender-grubenv: Fail execution if both environments
  are corrupt.
* grub-mender-grubenv: Recompute checksum after restoring
  environment (new versions of grub-editenv add extra data).
* Add the XFS module to the grub efi binary module list
* Project can now be used as a git submodule again
  Ticket: #
  ([MEN-6305](https://northerntech.atlassian.net/browse/MEN-6305))
* Added support for installing mender client for ubuntu jammy conversions
  Ticket: #
  ([MEN-6306](https://northerntech.atlassian.net/browse/MEN-6306))
* support added for mender-client deb package data archive compressed with zstd
  ([MEN-6307](https://northerntech.atlassian.net/browse/MEN-6307))
* grub-mender-grubenv: Fix boot failure because
  `mender_grub_storage_device` is not exported correctly.


## mender-convert 3.0.1

_Released 09.25.2022_

### Statistics

A total of 269 lines added, 203 removed (delta 66)

| Developers with the most changesets | |
|---|---|
| Lluis Campos | 2 (33.3%) |
| Kristian Amlie | 2 (33.3%) |
| Alin Alexandru | 1 (16.7%) |
| Ole Petter Orhagen | 1 (16.7%) |

| Developers with the most changed lines | |
|---|---|
| Ole Petter Orhagen | 220 (81.8%) |
| Lluis Campos | 33 (12.3%) |
| Kristian Amlie | 13 (4.8%) |
| Alin Alexandru | 3 (1.1%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 5 (83.3%) |
| INNOBYTE | 1 (16.7%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 266 (98.9%) |
| INNOBYTE | 3 (1.1%) |

| Employers with the most hackers (total 4) | |
|---|---|
| Northern.tech | 3 (75.0%) |
| INNOBYTE | 1 (25.0%) |

### Changelogs

#### mender-convert (3.0.1)

New changes in mender-convert since 3.0.0:

##### Bug fixes

* Detect when EFI is not available and disable grub.d integration.
* Amend error message for optional parameters


## mender-convert 3.0.0

_Released 06.14.2022_

### Statistics

A total of 1475 lines added, 474 removed (delta 1001)

| Developers with the most changesets | |
|---|---|
| Kristian Amlie | 21 (39.6%) |
| Ole Petter Orhagen | 16 (30.2%) |
| Lluis Campos | 8 (15.1%) |
| Josef Holzmayr | 4 (7.5%) |
| Simon Ensslen | 2 (3.8%) |
| Mikael Torp-Holte | 1 (1.9%) |
| Peter Grzybowski | 1 (1.9%) |

| Developers with the most changed lines | |
|---|---|
| Kristian Amlie | 690 (44.9%) |
| Ole Petter Orhagen | 479 (31.2%) |
| Lluis Campos | 173 (11.3%) |
| Simon Ensslen | 123 (8.0%) |
| Josef Holzmayr | 46 (3.0%) |
| Peter Grzybowski | 23 (1.5%) |
| Mikael Torp-Holte | 2 (0.1%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 51 (96.2%) |
| Griesser AG | 2 (3.8%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 1413 (92.0%) |
| Griesser AG | 123 (8.0%) |

| Employers with the most hackers (total 7) | |
|---|---|
| Northern.tech | 6 (85.7%) |
| Griesser AG | 1 (14.3%) |

### Changelogs

#### mender-convert (3.0.0)

New changes in mender-convert since 2.6.2:

* Modify `ln` calls for data store links to support successive runs
  ([MEN-5078](https://northerntech.atlassian.net/browse/MEN-5078))
* Fix "unbound variable" error when using `raspberrypi4_ubuntu_config`.
* Download and install Debian packages taking into account the
  target OS. Now downloads.mender.io serves four distributions: the two
  latests releases for Debian and Ubuntu. Probe /etc/os-release to figure
  out the correct package to install, and fallback to Debian Buster
  packages which was the previous default.
  ([MEN-5410](https://northerntech.atlassian.net/browse/MEN-5410))
* Fix installation of user specified versions for mender-configure add-on
* Debian 11 tests support.
  ([MEN-5257](https://northerntech.atlassian.net/browse/MEN-5257))
* The fstab file from the image being converted is now preserved across convertions, with the Mender specific additions merged with the existing fstab file, as opposed to replacing it completely. Which was the previous approach.
* fix compatibility of docker-mender-convert with macOS/*BSD
* Keep the UUID of the original first partition on the boot partition
  of the converted image when the partition table is GPT.
  ([MEN-5221](https://northerntech.atlassian.net/browse/MEN-5221))
* clarify supported development platforms
* clarify Raspbian compatibility
* README: add compatibility tables for configurations
* The mender-convert docker image does now contain the mender-convert application and does no longer need companion checkouts.
* All input files passed to docker-mender-convert must be located within the input directory as opposed to anywhere in the mender-convert checkout directory
* If `grub*.efi` preexists on the EFI partition, keep it
  instead of installing our own. In all other cases, we fall back to the
  old functionality of installing mender-grub and nuking the existing
  bootloader.
* Integrate with `grub.d` framework.

  This means that `grub-install` and `update-grub` no longer risk
  bricking the device, but will produce boot scripts with Mender support
  integrated. It also means that the standard GRUB menu will be
  available.

  It is supported on x86_64 platforms where `grub.d` is available, and
  can be turned on and off with `MENDER_GRUB_D_INTEGRATION`. The default
  is to use it if available.

  Devices that did not previously use `grub.d` integration won't be
  upgraded correctly with it turned on, so it is advised to set
  `MENDER_GRUB_D_INTEGRATION=n` if you are upgrading existing devices.
  ([MEN-5219](https://northerntech.atlassian.net/browse/MEN-5219))

##### Dependabot bumps

* Aggregated Dependabot Changelogs:
  * Bumps [jsdom](https://github.com/jsdom/jsdom) from 17.0.0 to 18.0.0.
      - [Release notes](https://github.com/jsdom/jsdom/releases)
      - [Changelog](https://github.com/jsdom/jsdom/blob/master/Changelog.md)
      - [Commits](https://github.com/jsdom/jsdom/compare/17.0.0...18.0.0)

      ```
      updated-dependencies:
      - dependency-name: jsdom
        dependency-type: direct:production
        update-type: version-update:semver-major
      ```
  * Bumps [jsdom](https://github.com/jsdom/jsdom) from 18.0.0 to 18.0.1.
      - [Release notes](https://github.com/jsdom/jsdom/releases)
      - [Changelog](https://github.com/jsdom/jsdom/blob/master/Changelog.md)
      - [Commits](https://github.com/jsdom/jsdom/compare/18.0.0...18.0.1)

      ```
      updated-dependencies:
      - dependency-name: jsdom
        dependency-type: direct:production
        update-type: version-update:semver-patch
      ```
  * Bumps [jsdom](https://github.com/jsdom/jsdom) from 18.0.1 to 18.1.0.
      - [Release notes](https://github.com/jsdom/jsdom/releases)
      - [Changelog](https://github.com/jsdom/jsdom/blob/master/Changelog.md)
      - [Commits](https://github.com/jsdom/jsdom/compare/18.0.1...18.1.0)

      ```
      updated-dependencies:
      - dependency-name: jsdom
        dependency-type: direct:production
        update-type: version-update:semver-minor
      ```
  * Bumps [jsdom](https://github.com/jsdom/jsdom) from 18.1.0 to 18.1.1.
      - [Release notes](https://github.com/jsdom/jsdom/releases)
      - [Changelog](https://github.com/jsdom/jsdom/blob/master/Changelog.md)
      - [Commits](https://github.com/jsdom/jsdom/compare/18.1.0...18.1.1)

      ```
      updated-dependencies:
      - dependency-name: jsdom
        dependency-type: direct:production
        update-type: version-update:semver-patch
      ```
  * Bumps [jsdom](https://github.com/jsdom/jsdom) from 18.1.1 to 19.0.0.
      - [Release notes](https://github.com/jsdom/jsdom/releases)
      - [Changelog](https://github.com/jsdom/jsdom/blob/master/Changelog.md)
      - [Commits](https://github.com/jsdom/jsdom/compare/18.1.1...19.0.0)

      ```
      updated-dependencies:
      - dependency-name: jsdom
        dependency-type: direct:production
        update-type: version-update:semver-major
      ```



## mender-convert 2.6.2

_Released 02.02.2022_

### Statistics

A total of 136 lines added, 70 removed (delta 66)

| Developers with the most changesets | |
|---|---|
| Lluis Campos | 5 (100.0%) |

| Developers with the most changed lines | |
|---|---|
| Lluis Campos | 143 (100.0%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 5 (100.0%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 143 (100.0%) |

| Employers with the most hackers (total 1) | |
|---|---|
| Northern.tech | 1 (100.0%) |

### Changelogs

#### mender-convert (2.6.2)

New changes in mender-convert since 2.6.1:

* Download and install Debian packages taking into account the
  target OS. Now downloads.mender.io serves four distributions: the two
  latests releases for Debian and Ubuntu. Probe /etc/os-release to figure
  out the correct package to install, and fallback to Debian Buster
  packages which was the previous default.
  ([MEN-5410](https://northerntech.atlassian.net/browse/MEN-5410))
* Fix installation of user specified versions for mender-configure add-on


## mender-convert 2.6.1

_Released 01.24.2022_

### Statistics

A total of 12 lines added, 13 removed (delta -1)

| Developers with the most changesets | |
|---|---|
| Ole Petter Orhagen | 4 (66.7%) |
| Kristian Amlie | 1 (16.7%) |
| Lluis Campos | 1 (16.7%) |

| Developers with the most changed lines | |
|---|---|
| Ole Petter Orhagen | 6 (40.0%) |
| Lluis Campos | 5 (33.3%) |
| Kristian Amlie | 4 (26.7%) |

| Developers with the most lines removed | |
|---|---|
| Kristian Amlie | 3 (23.1%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 6 (100.0%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 15 (100.0%) |

| Employers with the most hackers (total 3) | |
|---|---|
| Northern.tech | 3 (100.0%) |
      
### Changelogs

#### mender-convert (2.6.1)

New changes in mender-convert since 2.6.0:

* Modify `ln` calls for data store links to support successive runs
  ([MEN-5078](https://northerntech.atlassian.net/browse/MEN-5078))
* Fix "unbound variable" error when using `raspberrypi4_ubuntu_config`.


## mender-convert 2.6.0

_Released 09.28.2021_

### Statistics

A total of 194 lines added, 88 removed (delta 106)

| Developers with the most changesets | |
|---|---|
| Kristian Amlie | 7 (36.8%) |
| Lluis Campos | 6 (31.6%) |
| Ole Petter Orhagen | 5 (26.3%) |
| Andrey Basov | 1 (5.3%) |

| Developers with the most changed lines | |
|---|---|
| Kristian Amlie | 91 (45.7%) |
| Lluis Campos | 79 (39.7%) |
| Ole Petter Orhagen | 25 (12.6%) |
| Andrey Basov | 4 (2.0%) |

| Developers with the most signoffs (total 1) | |
|---|---|
| Kristian Amlie | 1 (100.0%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 18 (94.7%) |
| dev.basov@gmail.com | 1 (5.3%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 195 (98.0%) |
| dev.basov@gmail.com | 4 (2.0%) |

| Employers with the most signoffs (total 1) | |
|---|---|
| Northern.tech | 1 (100.0%) |

| Employers with the most hackers (total 4) | |
|---|---|
| Northern.tech | 3 (75.0%) |
| dev.basov@gmail.com | 1 (25.0%) |

### Changelogs

#### mender-convert (2.6.0)

New changes in mender-convert since 2.5.0:

* configs/images/raspberrypi_raspbian_config: Allow APT Suite change
  ([MEN-5057](https://northerntech.atlassian.net/browse/MEN-5057))
* Fix broken download of packages when `*_VERSION` are set to
  `master`.
* grub-mender-grubenv: User space tools, "fw_printenv" and
  "fw_setenv" have been renamed to "grub-mender-grubenv-print" and
  "grub-mender-grubenv-set", respectively. This has been done in order
  to avoid conflict with U-Boot's user space tools, which have the same
  names.
* RPi pre-converted images: remove Mender client version from
  Artifact name.
* Create symlink from `/var/lib/mender-monitor` to
  `/data/mender-configure`
  ([MEN-5086](https://northerntech.atlassian.net/browse/MEN-5086))
* Closing curly brace added in bootstrap-rootfs-overlay-production-server.sh
* Aggregated Dependabot Changelogs:
  * Bumps [jsdom](https://github.com/jsdom/jsdom) from 16.6.0 to 16.7.0.
    - [Release notes](https://github.com/jsdom/jsdom/releases)
    - [Changelog](https://github.com/jsdom/jsdom/blob/master/Changelog.md)
    - [Commits](https://github.com/jsdom/jsdom/compare/16.6.0...16.7.0)
    ---
    updated-dependencies:
    - dependency-name: jsdom
      dependency-type: direct:production
      update-type: version-update:semver-minor
    ...
  * Bumps [jsdom](https://github.com/jsdom/jsdom) from 16.7.0 to 17.0.0.
    - [Release notes](https://github.com/jsdom/jsdom/releases)
    - [Changelog](https://github.com/jsdom/jsdom/blob/master/Changelog.md)
    - [Commits](https://github.com/jsdom/jsdom/compare/16.7.0...17.0.0)
    ---
    updated-dependencies:
    - dependency-name: jsdom
      dependency-type: direct:production
      update-type: version-update:semver-major
    ...


## mender-convert 2.5.3

_Released 02.09.2022_

### Statistics

A total of 143 lines added, 78 removed (delta 65)

| Developers with the most changesets | |
|---|---|
| Lluis Campos | 6 (75.0%) |
| Ole Petter Orhagen | 1 (12.5%) |
| Kristian Amlie | 1 (12.5%) |

| Developers with the most changed lines | |
|---|---|
| Lluis Campos | 147 (96.1%) |
| Kristian Amlie | 4 (2.6%) |
| Ole Petter Orhagen | 2 (1.3%) |

| Developers with the most lines removed | |
|---|---|
| Kristian Amlie | 3 (3.8%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 8 (100.0%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 153 (100.0%) |

| Employers with the most signoffs (total 0) | |
|---|---|

| Employers with the most hackers (total 3) | |
|---|---|
| Northern.tech | 3 (100.0%) |

### Changelogs

#### mender-convert (2.5.3)

New changes in mender-convert since 2.5.2:

* Modify `ln` calls for data store links to support successive runs
  ([MEN-5078](https://northerntech.atlassian.net/browse/MEN-5078))
* Fix "unbound variable" error when using `raspberrypi4_ubuntu_config`.
* Download and install Debian packages taking into account the
  target OS. Now downloads.mender.io serves four distributions: the two
  latests releases for Debian and Ubuntu. Probe /etc/os-release to figure
  out the correct package to install, and fallback to Debian Buster
  packages which was the previous default.
  ([MEN-5410](https://northerntech.atlassian.net/browse/MEN-5410))
* Fix installation of user specified versions for mender-configure add-on


## mender-convert 2.5.2

_Released 09.30.2021_

### Statistics

A total of 107 lines added, 38 removed (delta 69)

| Developers with the most changesets | |
|---|---|
| Kristian Amlie | 5 (71.4%) |
| Lluis Campos | 1 (14.3%) |
| Andrey Basov | 1 (14.3%) |

| Developers with the most changed lines | |
|---|---|
| Kristian Amlie | 89 (83.2%) |
| Lluis Campos | 14 (13.1%) |
| Andrey Basov | 4 (3.7%) |

| Developers with the most signoffs (total 1) | |
|---|---|
| Kristian Amlie | 1 (100.0%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 6 (85.7%) |
| dev.basov@gmail.com | 1 (14.3%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 103 (96.3%) |
| dev.basov@gmail.com | 4 (3.7%) |

| Employers with the most signoffs (total 1) | |
|---|---|
| Northern.tech | 1 (100.0%) |

| Employers with the most hackers (total 3) | |
|---|---|
| Northern.tech | 2 (66.7%) |
| dev.basov@gmail.com | 1 (33.3%) |

### Changelogs

## mender-convert 2.5.2

#### mender-convert (2.5.2)

New changes in mender-convert since 2.5.0:

* Closing curly brace added in bootstrap-rootfs-overlay-production-server.sh
* Fix broken download of packages when `*_VERSION` are set to
  `master`.


## mender-convert 2.5.1

_Released 09.30.2021_

    mender-convert 2.5.1 was a faulty release, and has been removed.


## mender-convert 2.5.0

_Released 07.14.2021_

### Statistics

A total of 167 lines added, 219 removed (delta -52)

| Developers with the most changesets | |
|---|---|
| Lluis Campos | 9 (37.5%) |
| Ole Petter Orhagen | 9 (37.5%) |
| Kristian Amlie | 4 (16.7%) |
| Fabio Tranchitella | 2 (8.3%) |

| Developers with the most changed lines | |
|---|---|
| Ole Petter Orhagen | 154 (51.9%) |
| Lluis Campos | 81 (27.3%) |
| Kristian Amlie | 50 (16.8%) |
| Fabio Tranchitella | 12 (4.0%) |

| Developers with the most lines removed | |
|---|---|
| Kristian Amlie | 38 (17.4%) |
| Ole Petter Orhagen | 13 (5.9%) |
| Lluis Campos | 12 (5.5%) |

| Developers with the most signoffs (total 2) | |
|---|---|
| Lluis Campos | 2 (100.0%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 24 (100.0%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 297 (100.0%) |

| Employers with the most signoffs (total 2) | |
|---|---|
| Northern.tech | 2 (100.0%) |

| Employers with the most hackers (total 4) | |
|---|---|
| Northern.tech | 4 (100.0%) |

### Changelogs

#### mender-convert (2.5.0)

New changes in mender-convert since 2.4.0:

* Switch to stable version of mender-configure.
* Always create symlinks from `/var/lib/mender-configure` to
  `/data/mender-configure`. They always need to installed in a
  rootfs-image prepared image, even if the software isn't, because if
  the package is installed later, the links must be present or it will
  act as if it is a non-rootfs image, and store the settings on the
  rootfs partition, when they should be stored on the data partition.
* Raspberry Pi: create symbolic links from /boot to /uboot for
  all existing files in boot partition. Some Raspberry Pi apps, like Pi
  Camera, expect firmware files at /boot.
  ([MEN-4658](https://northerntech.atlassian.net/browse/MEN-4658))
* Added an option `MENDER_CLIENT_INSTALL=y/n`, in order to
  configure the installation of the Mender client into the converted image.
  Defaults to `yes`.
  ([MEN-4256](https://northerntech.atlassian.net/browse/MEN-4256))
* Add a demo configuration in configs/mender_convert_demo_config which
  when added at run time creates a Mender demo setup in the converted image. This
  includes short polling intervals, and all add-on's installed by default.
  ([MEN-4462](https://northerntech.atlassian.net/browse/MEN-4462))
* Aggregated Dependabot Changelogs:
  * Bumps [jsdom](https://github.com/jsdom/jsdom) from 16.4.0 to 16.5.3.
    - [Release notes](https://github.com/jsdom/jsdom/releases)
    - [Changelog](https://github.com/jsdom/jsdom/blob/master/Changelog.md)
    - [Commits](https://github.com/jsdom/jsdom/compare/16.4.0...16.5.3)
  * Bumps [jsdom](https://github.com/jsdom/jsdom) from 16.5.3 to 16.6.0.
    - [Release notes](https://github.com/jsdom/jsdom/releases)
    - [Changelog](https://github.com/jsdom/jsdom/blob/master/Changelog.md)
    - [Commits](https://github.com/jsdom/jsdom/compare/16.5.3...16.6.0)

## mender-convert 2.4.0

_Released 04.19.2021_

### Statistics

A total of 3340 lines added, 1222 removed (delta 2118)

| Developers with the most changesets | |
|---|---|
| Ole Petter Orhagen | 19 (50.0%) |
| Lluis Campos | 9 (23.7%) |
| Kristian Amlie | 8 (21.1%) |
| Fabio Tranchitella | 2 (5.3%) |

| Developers with the most changed lines | |
|---|---|
| Ole Petter Orhagen | 3240 (95.5%) |
| Lluis Campos | 84 (2.5%) |
| Kristian Amlie | 58 (1.7%) |
| Fabio Tranchitella | 12 (0.4%) |

| Developers with the most lines removed | |
|---|---|
| Kristian Amlie | 38 (3.1%) |

| Developers with the most signoffs (total 1) | |
|---|---|
| Lluis Campos | 1 (100.0%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 38 (100.0%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 3394 (100.0%) |

| Employers with the most signoffs (total 1) | |
|---|---|
| Northern.tech | 1 (100.0%) |

| Employers with the most hackers (total 4) | |
|---|---|
| Northern.tech | 4 (100.0%) |

### Changelogs

#### mender-convert (2.4.0)

New changes in mender-convert since 2.3.0:

* Set mender-connect version to latest
([MEN-4200](https://northerntech.atlassian.net/browse/MEN-4200))
* Support installing mender-configure addon. Not installed by
default, it can be configured using MENDER_ADDON_CONFIGURE_INSTALL and
MENDER_ADDON_CONFIGURE_VERSION variables.
([MEN-4422](https://northerntech.atlassian.net/browse/MEN-4422))
* Set mender-configure version to master
([MEN-4422](https://northerntech.atlassian.net/browse/MEN-4422))
* The standard RasperryPi configuration now comes with UBoot 2020.01 as
the default. ([MEN-4395](https://northerntech.atlassian.net/browse/MEN-4395))
* raspberrypi_config: Modify headless configuration services to
expect boot partition in /uboot instead of /boot.
([MEN-4117](https://northerntech.atlassian.net/browse/MEN-4117))
* [raspberrypi_config] Enable UART in U-Boot config.txt
([MEN-4567](https://northerntech.atlassian.net/browse/MEN-4567))
* Update mender-artifact to 3.5.x.
* Switch to stable version of mender-configure.
* Always create symlinks from `/var/lib/mender-configure` to
`/data/mender-configure`. They always need to installed in a
rootfs-image prepared image, even if the software isn't, because if
the package is installed later, the links must be present or it will
act as if it is a non-rootfs image, and store the settings on the
rootfs partition, when they should be stored on the data partition.

## mender-convert 2.3.1

_Released 16.04.2021_

### Statistics

| Developers with the most changesets | |
|---|---|
| Ole Petter Orhagen | 4 (80.0%) |
| Lluis Campos | 1 (20.0%) |

| Developers with the most changed lines | |
|---|---|
| Lluis Campos | 9 (64.3%) |
| Ole Petter Orhagen | 5 (35.7%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 5 (100.0%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 14 (100.0%) |

| Employers with the most hackers (total 2) | |
|---|---|
| Northern.tech | 2 (100.0%) |

### Changelogs

#### mender-convert (2.3.1)

New changes in mender-convert since 2.3.0:

* The standard RasperryPi configuration now comes with UBoot 2020.01 as
the default. ([MEN-4395](https://northerntech.atlassian.net/browse/MEN-4395))
* [raspberrypi_config] Enable UART in U-Boot config.txt
([MEN-4567](https://northerntech.atlassian.net/browse/MEN-4567))

## mender-convert 2.3.0

_Released 01.20.2021_

### Statistics

A total of 858 lines added, 378 removed (delta 480)

| Developers with the most changesets | |
|---|---|
| Lluis Campos | 31 (53.4%) |
| Kristian Amlie | 9 (15.5%) |
| Drew Moseley | 7 (12.1%) |
| Ole Petter Orhagen | 6 (10.3%) |
| Nils Olav Kvelvane Johansen | 2 (3.4%) |
| Fabio Tranchitella | 1 (1.7%) |
| Mirza Krak | 1 (1.7%) |
| Alin Alexandru | 1 (1.7%) |

| Developers with the most changed lines | |
|---|---|
| Lluis Campos | 642 (71.0%) |
| Kristian Amlie | 125 (13.8%) |
| Drew Moseley | 51 (5.6%) |
| Ole Petter Orhagen | 36 (4.0%) |
| Nils Olav Kvelvane Johansen | 22 (2.4%) |
| Fabio Tranchitella | 16 (1.8%) |
| Alin Alexandru | 11 (1.2%) |
| Mirza Krak | 1 (0.1%) |

| Developers with the most lines removed | |
|---|---|
| Mirza Krak | 1 (0.3%) |

| Developers with the most signoffs (total 1) | |
|---|---|
| Lluis Campos | 1 (100.0%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 57 (98.3%) |
| INNOBYTE | 1 (1.7%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 893 (98.8%) |
| INNOBYTE | 11 (1.2%) |

| Employers with the most signoffs (total 1) | |
|---|---|
| Northern.tech | 1 (100.0%) |

| Employers with the most hackers (total 8) | |
|---|---|
| Northern.tech | 7 (87.5%) |
| INNOBYTE | 1 (12.5%) |

### Changelogs

#### mender-convert (2.3.0)

New changes in mender-convert since 2.2.0:

* Fix inadvertent fstab change of fstype field.
* package: Create partitions as ext4.
* grub-efi: Fix inability to upgrade to a different kernel.
* Fix massive root filesystem corruption under some build conditions.
* Add support for overlay hooks
* beaglebone: Implement workaround for broken U-Boot and kernel.
([MEN-3952](https://northerntech.atlassian.net/browse/MEN-3952))
* beaglebone: Remove U-Boot integration, which has not worked
for a long time. U-Boot will still be used for booting, but GRUB will
be used for integration with Mender, by chainloading via UEFI.
([MEN-3952](https://northerntech.atlassian.net/browse/MEN-3952))
* Support overriding default image compression
* Do not compress output image for uncompressed input image
* Package latest released Mender-client by default
([QA-214](https://northerntech.atlassian.net/browse/QA-214))
* Use separate chown and chgrp commands when creating rootfs overlay.
* Support installing mender-shell addon. Not installed by
default, it can be configured using MENDER_ADDON_SHELL_INSTALL and
MENDER_ADDON_SHELL_VERSION variables.
([MEN-4097](https://northerntech.atlassian.net/browse/MEN-4097))
* Set mender-shell version to master
([MEN-4097](https://northerntech.atlassian.net/browse/MEN-4097))
* Create demo configuration for Mender Shell addon in
bootstrap-rootfs-overlay-demo-server.sh script
([MEN-4097](https://northerntech.atlassian.net/browse/MEN-4097))
* Better parameter checks for read-only options.
* Use unique work directories when building with docker.
* Fix error when removing empty directories in rootfs/boot
* Use numeric uid and gid for better cross-compatibility.
* Now it is possible to write multiple device types in the config file using a space seperated string. Filenames for files in the deploy dir will contain all the device names seperated with +.
([MEN-3361](https://northerntech.atlassian.net/browse/MEN-3361))
* Now it is possible to to select a custom filename for the deployed files by using a DEPLOY_IMAGE_NAME string in the config file.
* Set mender-connect version to latest
([MEN-4200](https://northerntech.atlassian.net/browse/MEN-4200))
* Aggregated Dependabot Changelogs:
* Bumps [tests/mender-image-tests](https://github.com/mendersoftware/mender-image-tests) from `986bd6e` to `5f88854`.
- [Release notes](https://github.com/mendersoftware/mender-image-tests/releases)
- [Commits](https://github.com/mendersoftware/mender-image-tests/compare/986bd6e3e932af1432ca74f4f9f0ec5a85ed7e66...5f8885448d946ee2fed099aa541e5f8c277b20c9)
* Bump tests/mender-image-tests from `986bd6e` to `5f88854`
* Bumps [tests/mender-image-tests](https://github.com/mendersoftware/mender-image-tests) from `5f88854` to `55c846d`.
- [Release notes](https://github.com/mendersoftware/mender-image-tests/releases)
- [Commits](https://github.com/mendersoftware/mender-image-tests/compare/5f8885448d946ee2fed099aa541e5f8c277b20c9...55c846d681c21045a8fa839c40dff0f07c2cc512)
* Bumps [tests/mender-image-tests](https://github.com/mendersoftware/mender-image-tests) from `55c846d` to `cab12eb`.
- [Release notes](https://github.com/mendersoftware/mender-image-tests/releases)
- [Commits](https://github.com/mendersoftware/mender-image-tests/compare/55c846d681c21045a8fa839c40dff0f07c2cc512...cab12eb11c7b3aea8ae2b383037de1aae04a02b7)
* Bump tests/mender-image-tests from `55c846d` to `cab12eb`

## mender-convert 2.2.2

_Released 01.21.2021_

### Statistics

A total of 73 lines added, 40 removed (delta 33)

| Developers with the most changesets | |
|---|---|
| Lluis Campos | 4 (28.6%) |
| Ole Petter Orhagen | 4 (28.6%) |
| Kristian Amlie | 3 (21.4%) |
| Drew Moseley | 2 (14.3%) |
| Mirza Krak | 1 (7.1%) |

| Developers with the most changed lines | |
|---|---|
| Lluis Campos | 37 (49.3%) |
| Drew Moseley | 20 (26.7%) |
| Ole Petter Orhagen | 11 (14.7%) |
| Kristian Amlie | 6 (8.0%) |
| Mirza Krak | 1 (1.3%) |

| Developers with the most lines removed | |
|---|---|
| Mirza Krak | 1 (2.5%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 14 (100.0%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 75 (100.0%) |

| Employers with the most hackers (total 5) | |
|---|---|
| Northern.tech | 5 (100.0%) |

### Changelogs

#### mender-convert (2.2.2)

New changes in mender-convert since 2.2.1:

* Package latest released Mender-client by default
([QA-214](https://northerntech.atlassian.net/browse/QA-214))
* Use separate chown and chgrp commands when creating rootfs overlay.
* Better parameter checks for read-only options.
* Fix error when removing empty directories in rootfs/boot

## mender-convert 2.2.1

_Released 11.05.2020_

### Statistics

A total of 144 lines added, 96 removed (delta 48)

| Developers with the most changesets | |
|---|---|
| Kristian Amlie | 6 (60.0%) |
| Ole Petter Orhagen | 2 (20.0%) |
| Lluis Campos | 2 (20.0%) |

| Developers with the most changed lines | |
|---|---|
| Kristian Amlie | 119 (81.0%) |
| Lluis Campos | 23 (15.6%) |
| Ole Petter Orhagen | 5 (3.4%) |

| Developers with the most lines removed | |
|---|---|
| Ole Petter Orhagen | 3 (3.1%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 10 (100.0%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 147 (100.0%) |

| Employers with the most hackers (total 3) | |
|---|---|
| Northern.tech | 3 (100.0%) |

### Changelogs

#### mender-convert (2.2.1)

New changes in mender-convert since 2.2.0:

* grub-efi: Fix inability to upgrade to a different kernel.
* Fix massive root filesystem corruption under some build conditions.
* beaglebone: Implement workaround for broken U-Boot and kernel.
([MEN-3952](https://northerntech.atlassian.net/browse/MEN-3952))
* beaglebone: Remove U-Boot integration, which has not worked
for a long time. U-Boot will still be used for booting, but GRUB will
be used for integration with Mender, by chainloading via UEFI.
([MEN-3952](https://northerntech.atlassian.net/browse/MEN-3952))
* Install the latest Mender-client release (2.4.1) by default.

## mender-convert 2.2.0

_Released 09.16.2020_

### Statistics

A total of 436 lines added, 56 removed (delta 380)

| Developers with the most changesets | |
|---|---|
| Drew Moseley | 12 (44.4%) |
| Lluis Campos | 7 (25.9%) |
| Dell Green | 2 (7.4%) |
| Kristian Amlie | 2 (7.4%) |
| Marek Belisko | 1 (3.7%) |
| Peter Grzybowski | 1 (3.7%) |
| Ole Petter Orhagen | 1 (3.7%) |
| Purushotham Nayak | 1 (3.7%) |

| Developers with the most changed lines | |
|---|---|
| Dell Green | 309 (70.9%) |
| Drew Moseley | 53 (12.2%) |
| Lluis Campos | 25 (5.7%) |
| Ole Petter Orhagen | 14 (3.2%) |
| Marek Belisko | 13 (3.0%) |
| Purushotham Nayak | 11 (2.5%) |
| Peter Grzybowski | 8 (1.8%) |
| Kristian Amlie | 3 (0.7%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 23 (85.2%) |
| Ideaworks Ltd | 2 (7.4%) |
| Cisco Systems, Inc. | 1 (3.7%) |
| open-nandra | 1 (3.7%) |

| Top lines changed by employer | |
|---|---|
| Ideaworks Ltd | 309 (70.9%) |
| Northern.tech | 103 (23.6%) |
| open-nandra | 13 (3.0%) |
| Cisco Systems, Inc. | 11 (2.5%) |

| Employers with the most hackers (total 8) | |
|---|---|
| Northern.tech | 5 (62.5%) |
| Ideaworks Ltd | 1 (12.5%) |
| open-nandra | 1 (12.5%) |
| Cisco Systems, Inc. | 1 (12.5%) |

### Changelogs

#### mender-convert (2.2.0)

New changes in mender-convert since 2.1.0:

* Fix missed log messages.
* Unmount filesystem images before creating full image.
* Fix incorrect file ownership on artifact_info file
* Extract debian package contents with sudo.
* Probing of kernel and initrd now handles multiple instances and symlinks
([MEN-3640](https://northerntech.atlassian.net/browse/MEN-3640))
* Fix error when partitions numbers are not sequential
* chmod 600 on mender.conf
([MEN-3762](https://northerntech.atlassian.net/browse/MEN-3762))
* Partition UUID support added for gpt/dos partition tables for deterministic booting
([MEN-3725](https://northerntech.atlassian.net/browse/MEN-3725))
* mender-convert-modify: Use sudo to copy DTBs.
* raspberrypi: Do not overwrite existing kernel.
* mender-convert-modify: Check is selinux is configured in enforce mode and force rootfs-relabel
* Account for root ownership of overlay files.
* Cleanup more bootloader files.
* Allow for custom options when creating filesystems.
* Allow for custom option when mounting filesystems.
* Update mender-artifact to 3.4.0
* Warn user when converting read-only file systems that would
result in unstable checksums, making the image incompatible with Mender
Delta updates.
([MEN-3912](https://northerntech.atlassian.net/browse/MEN-3912))
* Update mender client to 2.4.0

## mender-convert 2.1.0

_Released 07.16.2020_

### Statistics

A total of 845 lines added, 251 removed (delta 594)

| Developers with the most changesets | |
|---|---|
| Kristian Amlie | 21 (36.2%) |
| Drew Moseley | 14 (24.1%) |
| Ole Petter Orhagen | 14 (24.1%) |
| Nate Baker | 3 (5.2%) |
| Marek Belisko | 2 (3.4%) |
| Lluis Campos | 2 (3.4%) |
| Dell Green | 1 (1.7%) |
| Sylvain | 1 (1.7%) |

| Developers with the most changed lines | |
|---|---|
| Ole Petter Orhagen | 450 (52.9%) |
| Kristian Amlie | 203 (23.9%) |
| Drew Moseley | 80 (9.4%) |
| Marek Belisko | 66 (7.8%) |
| Nate Baker | 30 (3.5%) |
| Dell Green | 18 (2.1%) |
| Lluis Campos | 3 (0.4%) |
| Sylvain | 1 (0.1%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 51 (87.9%) |
| bakern@gmail.com | 3 (5.2%) |
| open-nandra | 2 (3.4%) |
| TideWise Ltda. | 1 (1.7%) |
| Ideaworks Ltd | 1 (1.7%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 736 (86.5%) |
| open-nandra | 66 (7.8%) |
| bakern@gmail.com | 30 (3.5%) |
| Ideaworks Ltd | 18 (2.1%) |
| TideWise Ltda. | 1 (0.1%) |

| Employers with the most hackers (total 8) | |
|---|---|
| Northern.tech | 4 (50.0%) |
| open-nandra | 1 (12.5%) |
| bakern@gmail.com | 1 (12.5%) |
| Ideaworks Ltd | 1 (12.5%) |
| TideWise Ltda. | 1 (12.5%) |

### Changelogs

#### mender-convert (2.1.0)

New changes in mender-convert since 2.1.0b1:

* Fix incorrect file ownership on artifact_info file
* Extract debian package contents with sudo.
* Fix missed log messages.
* Unmount filesystem images before creating full image.
* Upgrade to Mender 2.3.0 and mender-artifact 3.4.0.

New changes in mender-convert since 2.0.1:

* Use consistent compression and archive naming.
* Upgrade to GRUB 2.04.
* Add detection of problematic versions of U-Boot and kernel.
([MEN-2404](https://northerntech.atlassian.net/browse/MEN-2404))
* Added color to the terminal log messages
* Added hooks to Mender convert
This extends the current functionality of the platform_ function
functionality into using hooks, so that each modification step can be called
from multiple configuration files.
The valid hooks are:
* PLATFORM_MODIFY_HOOKS
* PLATFORM_PACKAGE_HOOKS
* USER_LOCAL_MODIFY_HOOKS
and can be appended to as a regular bash array.
* Add COMFILE Pi config
* Add support for GPT partition tables
([MEN-2151](https://northerntech.atlassian.net/browse/MEN-2151))
* Don't truncate output diskimage while writing partitions.
* configs: Added ubuntu x86-64 hdd defconfig
* Print improved error diagnostics before exiting on an error
* Add the state scripts version file.
* Ensure overlay files are owned by root.
* Setting of version variable now works if project added as a git submodule
([MEN-3475](https://northerntech.atlassian.net/browse/MEN-3475))
* configs: Added generic x86-64 hdd defconfig
* Added automatic decompression of input images, so that the convert
tool now accepts compressed input images in the formats: lzma, gzip, and zip.
The images will also be recompressed to the input format automatically.
([MEN-3052](https://northerntech.atlassian.net/browse/MEN-3052))
* add 'rootwait' to bootargs
* grubenv: Handle debug command prompt when running as EFI app.
* utilize regexp to dynamically set mender_grub_storage_device
* Remove kernel_devicetree from EFI path.
This information is not used when loading via UEFI, instead it is
queried directly from the UEFI provider.
* Fix 404 download errors when trying to run `docker-build`.
* Upgrade mender-client to 2.3.0b1 and mender-artifact to
3.4.0b1.

## mender-convert 2.0.1

_Released 05.28.2020_

### Statistics

A total of 49 lines added, 36 removed (delta 13)

| Developers with the most changesets | |
|---|---|
| Nate Baker | 3 (42.9%) |
| Kristian Amlie | 2 (28.6%) |
| Lluis Campos | 1 (14.3%) |
| Mirza Krak | 1 (14.3%) |

| Developers with the most changed lines | |
|---|---|
| Nate Baker | 30 (42.3%) |
| Mirza Krak | 25 (35.2%) |
| Kristian Amlie | 14 (19.7%) |
| Lluis Campos | 2 (2.8%) |

| Developers with the most lines removed | |
|---|---|
| Mirza Krak | 22 (61.1%) |

| Developers with the most signoffs (total 3) | |
|---|---|
| Mirza Krak | 3 (100.0%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 4 (57.1%) |
| bakern@gmail.com | 3 (42.9%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 41 (57.7%) |
| bakern@gmail.com | 30 (42.3%) |

| Employers with the most signoffs (total 3) | |
|---|---|
| Northern.tech | 3 (100.0%) |

| Employers with the most hackers (total 4) | |
|---|---|
| Northern.tech | 3 (75.0%) |
| bakern@gmail.com | 1 (25.0%) |

### Changelogs

#### mender-convert (2.0.1)

New changes in mender-convert since 2.0.0:

* Don't truncate output diskimage while writing partitions.
* Fix 404 download errors when trying to run `docker-build`.

## mender-convert 2.0.0

_Released 03.06.2020_

### Statistics

A total of 3745 lines added, 4597 removed (delta -852)

| Developers with the most changesets | |
|---|---|
| Kristian Amlie | 34 (30.4%) |
| Lluis Campos | 25 (22.3%) |
| Ole Petter Orhagen | 22 (19.6%) |
| Mirza Krak | 19 (17.0%) |
| Drew Moseley | 10 (8.9%) |
| Fabio Tranchitella | 1 (0.9%) |
| Alf-Rune Siqveland | 1 (0.9%) |

| Developers with the most changed lines | |
|---|---|
| Mirza Krak | 6195 (81.8%) |
| Kristian Amlie | 442 (5.8%) |
| Ole Petter Orhagen | 410 (5.4%) |
| Lluis Campos | 237 (3.1%) |
| Drew Moseley | 168 (2.2%) |
| Alf-Rune Siqveland | 103 (1.4%) |
| Fabio Tranchitella | 21 (0.3%) |

| Developers with the most lines removed | |
|---|---|
| Mirza Krak | 1369 (29.8%) |

| Developers with the most signoffs (total 1) | |
|---|---|
| Kristian Amlie | 1 (100.0%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 112 (100.0%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 7576 (100.0%) |

| Employers with the most signoffs (total 1) | |
|---|---|
| Northern.tech | 1 (100.0%) |

| Employers with the most hackers (total 7) | |
|---|---|
| Northern.tech | 7 (100.0%) |

### Changelogs

#### mender-convert (2.0.0)

New changes in mender-convert since 2.0.0b1:

* Upgrade to GRUB 2.04.
* Add detection of problematic versions of U-Boot and kernel.
([MEN-2404](https://northerntech.atlassian.net/browse/MEN-2404))
* Added hooks to Mender convert
This extends the current functionality of the platform_ function
functionality into using hooks, so that each modification step can be called
from multiple configuration files.
The valid hooks are:
* PLATFORM_MODIFY_HOOKS
* PLATFORM_PACKAGE_HOOKS
* USER_LOCAL_MODIFY_HOOKS
and can be appended to as a regular bash array.
* Use consistent compression and archive naming.
* Update to Mender 2.3.0 components
* Added color to the terminal log messages

New changes in mender-convert since 1.2.2:

* remove mender-convert (version 1)
* add mender-convert (version 2)
([MEN-2608](https://northerntech.atlassian.net/browse/MEN-2608))
* Allow mender_local_config in current directory to be ignored by git.
* bbb: Add support for eMMC as boot media.
* configs: Support multiple config files on command line.
* Fix "yellow" HDMI output on Raspbian Buster
([MEN-2685](https://northerntech.atlassian.net/browse/MEN-2685))
* scripts: Refactor to support different Mender server options.
* Add support for Ubuntu Server images on Raspberry Pi 3
* README: Clarify server types as alternatives.
* modify: Add an extra function user_local_modify for end users to populate.
* mender: Rename mender.service to mender-client.service
* Add Raspberry Pi 0 WiFi support
([MEN-2788](https://northerntech.atlassian.net/browse/MEN-2788))
* Implement MENDER_COPY_BOOT_GAP feature
([MEN-2784](https://northerntech.atlassian.net/browse/MEN-2784))
* Raspberry Pi 3: Update U-Boot to 2019.01
* Raspberry Pi 0 WiFi: Update U-Boot to 2019.01
* Raspberry Pi: Add U-Boot version to image boot partition
* Add support for Raspberry Pi 4 Model B
* Make sure artifacts are owned by same user as the launch directory.
* Changed the calculation of occupied space on the rootfs
partition to a more accurate formula.
* Add support for controlling rootfs size with `IMAGE_*` variables.
* `IMAGE_ROOTFS_SIZE` - The base size of the rootfs. The other two
variables modify this value
* `IMAGE_ROOTFS_EXTRA_SIZE` - The amount of free space to add to the
base size of the rootfs
* `IMAGE_OVERHEAD_FACTOR` - Factor determining the amount of free
space to add to the base size of the rootfs
The final size will be the largest of the two calculations. Please see
the `mender_convert_config` file comments for more information.
* Add lzma compression option for `MENDER_COMPRESS_DISK_IMAGE`.
* Bump mender-artifact version to 3.2.1.
* Turn off default ext4 filesystem feature `metadata_csum`.
This feature is not supported by tools on Ubuntu 16.04.
* Change the output filename naming scheme to mender.img
([MEN-3051](https://northerntech.atlassian.net/browse/MEN-3051))
* mender-convert: Rename variables for consistency with meta-mender.
* Fix certain kernels hanging on boot. In particular, recent
versions of Debian for Beaglebone was affected, but several other
boards using UEFI may also have been affected.
* Make device_type specific to each Raspberry Pi model.
([MEN-3165](https://northerntech.atlassian.net/browse/MEN-3165))
* Switch to Mender 2.3.0b1 components.

## mender-convert 1.2.2

_Released 12.11.2019_

### Statistics

A total of 9 lines added, 10 removed (delta -1)

| Developers with the most changesets | |
|---|---|
| Lluis Campos | 2 (100.0%) |

| Developers with the most changed lines | |
|---|---|
| Lluis Campos | 10 (100.0%) |

| Developers with the most lines removed | |
|---|---|
| Lluis Campos | 1 (10.0%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 2 (100.0%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 10 (100.0%) |

| Employers with the most hackers (total 1) | |
|---|---|
| Northern.tech | 1 (100.0%) |

### Changelogs

#### mender-convert (1.2.2)

New changes in mender-convert since 1.2.1:

* Upgrade client and mender-artifact to 2.1.2 and 3.2.1, respectively

## mender-convert 1.2.1

_Released 10.24.2019_

### Statistics

A total of 27 lines added, 18 removed (delta 9)

| Developers with the most changesets | |
|---|---|
| Kristian Amlie | 2 (40.0%) |
| Mirza Krak | 2 (40.0%) |
| Simon Guigui | 1 (20.0%) |

| Developers with the most changed lines | |
|---|---|
| Kristian Amlie | 13 (46.4%) |
| Simon Guigui | 13 (46.4%) |
| Mirza Krak | 2 (7.1%) |

| Developers with the most lines removed | |
|---|---|
| Simon Guigui | 1 (5.6%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 4 (80.0%) |
| fyhertz@gmail.com | 1 (20.0%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 15 (53.6%) |
| fyhertz@gmail.com | 13 (46.4%) |

| Employers with the most hackers (total 3) | |
|---|---|
| Northern.tech | 2 (66.7%) |
| fyhertz@gmail.com | 1 (33.3%) |

### Changelogs

#### mender-convert (1.2.1)

New changes in mender-convert since 1.2.0:

* Fix "yellow" HDMI output on Raspbian Buster
([MEN-2685](https://northerntech.atlassian.net/browse/MEN-2685))
* Upgrade client and mender-artifact to 2.1.1 and 3.2.0, respectively.
* Fix some race conditions when running multiple instances of mender-convert in parallel

## mender-convert 1.2.0

_Released 09.17.2019_

### Statistics

A total of 268 lines added, 100 removed (delta 168)

| Developers with the most changesets | |
|---|---|
| Mirza Krak | 10 (32.3%) |
| Lluis Campos | 9 (29.0%) |
| Simon Ensslen | 3 (9.7%) |
| Simon Gamma | 3 (9.7%) |
| Manuel Zedel | 2 (6.5%) |
| Eystein Måløy Stenberg | 2 (6.5%) |
| Mario Kozjak | 1 (3.2%) |
| Marek Belisko | 1 (3.2%) |

| Developers with the most changed lines | |
|---|---|
| Mirza Krak | 199 (65.5%) |
| Manuel Zedel | 36 (11.8%) |
| Lluis Campos | 35 (11.5%) |
| Simon Ensslen | 15 (4.9%) |
| Eystein Måløy Stenberg | 10 (3.3%) |
| Simon Gamma | 7 (2.3%) |
| Mario Kozjak | 1 (0.3%) |
| Marek Belisko | 1 (0.3%) |

| Developers with the most signoffs (total 1) | |
|---|---|
| Yevgeniy Nurseitov | 1 (100.0%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 23 (74.2%) |
| Griesser AG | 3 (9.7%) |
| github@survive.ch | 3 (9.7%) |
| kozjakm1@gmail.com | 1 (3.2%) |
| open-nandra | 1 (3.2%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 280 (92.1%) |
| Griesser AG | 15 (4.9%) |
| github@survive.ch | 7 (2.3%) |
| kozjakm1@gmail.com | 1 (0.3%) |
| open-nandra | 1 (0.3%) |

| Employers with the most signoffs (total 1) | |
|---|---|
| enurseitov@gmail.com | 1 (100.0%) |

| Employers with the most hackers (total 8) | |
|---|---|
| Northern.tech | 4 (50.0%) |
| Griesser AG | 1 (12.5%) |
| github@survive.ch | 1 (12.5%) |
| kozjakm1@gmail.com | 1 (12.5%) |
| open-nandra | 1 (12.5%) |

### Changelogs

#### mender-convert (1.2.0)

New changes in mender-convert since 1.2.0b1:

* Update mender-convert to use Mender final release v2.1.0

New changes in mender-convert since 1.1.1:

* Expand existing environment '$PATH' variable instead of replacing it
* Use same environment '$PATH' variable when using sudo
* Fail the docker build when mandatory build-arg 'mender_client_version' is not set.
* Update Dockerfile to use latest stable mender-artifact, v2.4.0
* Use mender-artfact v3. Requires rebuild of device-image-shell container.
* Use LZMA for smaller Artifact size (but slower generation).
* Update mender-convert to use final Mender v2.0 release
* shrink expanded rootfs when running "from_raw_disk_image"
* rpi: Bump u-boot version to fix booting on rpi0w after raspi-config resize partition
([MEN-2436](https://northerntech.atlassian.net/browse/MEN-2436))
* Instruct U-Boot to be able to boot either a compressed or an uncompressed kernel. This is very useful e.g. when switching from Debian (Raspbian) created using mender-convert to a Yocto based environment that does not compress the Kernel by default.
* Implement feature (mender-convert needs option to build without server)
([MEN-2590](https://northerntech.atlassian.net/browse/MEN-2590))
* Since mender-convert now automatically resizes the input image, there is an additional step that is executed.
* parameterize target architecture when creating Docker container
* Update mender-convert to for Mender v2.0.1 release
* Support for RockPro64 board
* Fix console not being available on HDMI on Raspberry Pi in Raspbian Buster.
([MEN-2673](https://northerntech.atlassian.net/browse/MEN-2673))
* only install servert.crt.demo if --demo-host-ip/-i is set
* add ServerCertificate entry in mender.conf if servert.crt was installed
([MEN-2640](https://northerntech.atlassian.net/browse/MEN-2640))
* install /etc/mender/script/version file
* Update mender-convert to use Mender beta release v2.1.0b1

## mender-convert 1.1.1

_Released 07.01.2019_

### Statistics

A total of 26 lines added, 23 removed (delta 3)

| Developers with the most changesets | |
|---|---|
| Mirza Krak | 2 (40.0%) |
| Lluis Campos | 1 (20.0%) |
| Adam Podogrocki | 1 (20.0%) |
| Marek Belisko | 1 (20.0%) |

| Developers with the most changed lines | |
|---|---|
| Mirza Krak | 19 (47.5%) |
| Adam Podogrocki | 17 (42.5%) |
| Lluis Campos | 3 (7.5%) |
| Marek Belisko | 1 (2.5%) |

| Developers with the most lines removed | |
|---|---|
| Mirza Krak | 14 (60.9%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 3 (60.0%) |
| RnDity | 1 (20.0%) |
| open-nandra | 1 (20.0%) |

| Top lines changed by employer | |
|---|---|
| Northern.tech | 22 (55.0%) |
| RnDity | 17 (42.5%) |
| open-nandra | 1 (2.5%) |

| Employers with the most hackers (total 4) | |
|---|---|
| Northern.tech | 2 (50.0%) |
| RnDity | 1 (25.0%) |
| open-nandra | 1 (25.0%) |


### Changelogs

#### mender-convert (1.1.1)

New changes in mender-convert since 1.1.0:

* rpi: Bump u-boot version to fix booting on rpi0w after raspi-config resize partition
([MEN-2436](https://northerntech.atlassian.net/browse/MEN-2436))
* shrink expanded rootfs when running "from_raw_disk_image"
* Update mender-convert to for Mender v2.0.1 release

## mender-convert 1.1.0

_Released 05.08.2019_

### Statistics

A total of 1512 lines added, 996 removed (delta 516)

| Developers with the most changesets | |
|---|---|
| Mirza Krak | 19 (27.5%) |
| Adam Podogrocki | 16 (23.2%) |
| Eystein Måløy Stenberg | 13 (18.8%) |
| Lluis Campos | 9 (13.0%) |
| Marek Belisko | 4 (5.8%) |
| Simon Gamma | 3 (4.3%) |
| Max Bruckner | 1 (1.4%) |
| Adrian Cuzman | 1 (1.4%) |
| Dominik Adamski | 1 (1.4%) |
| Mika Tuupola | 1 (1.4%) |

| Developers with the most changed lines | |
|---|---|
| Adam Podogrocki | 853 (48.8%) |
| Eystein Måløy Stenberg | 359 (20.5%) |
| Mirza Krak | 301 (17.2%) |
| Lluis Campos | 186 (10.6%) |
| Marek Belisko | 37 (2.1%) |
| Simon Gamma | 7 (0.4%) |
| Max Bruckner | 1 (0.1%) |
| Adrian Cuzman | 1 (0.1%) |
| Dominik Adamski | 1 (0.1%) |
| Mika Tuupola | 1 (0.1%) |

| Developers with the most lines removed | |
|---|---|
| Mirza Krak | 164 (16.5%) |

| Top changeset contributors by employer | |
|---|---|
| Northern.tech | 41 (59.4%) |
| RnDity | 17 (24.6%) |
| open-nandra | 4 (5.8%) |
| github@survive.ch | 3 (4.3%) |
| max@maxbruckner.de | 1 (1.4%) |
| adriancuzman@gmail.com | 1 (1.4%) |
| tuupola@appelsiini.net | 1 (1.4%) |
| denismosolov@gmail.com | 1 (1.4%) |

| Top lines changed by employer | |
|---|---|
| RnDity | 854 (48.9%) |
| Northern.tech | 846 (48.4%) |
| open-nandra | 37 (2.1%) |
| github@survive.ch | 7 (0.4%) |
| max@maxbruckner.de | 1 (0.1%) |
| adriancuzman@gmail.com | 1 (0.1%) |
| tuupola@appelsiini.net | 1 (0.1%) |
| denismosolov@gmail.com | 1 (0.1%) |

| Employers with the most hackers (total 11) | |
|---|---|
| Northern.tech | 3 (27.3%) |
| RnDity | 2 (18.2%) |
| open-nandra | 1 (9.1%) |
| github@survive.ch | 1 (9.1%) |
| max@maxbruckner.de | 1 (9.1%) |
| adriancuzman@gmail.com | 1 (9.1%) |
| tuupola@appelsiini.net | 1 (9.1%) |
| denismosolov@gmail.com | 1 (9.1%) |


### Changelogs

#### mender-convert (1.1.0)

New changes in mender-convert since 1.1.0b1:

* Expand existing environment '$PATH' variable instead of replacing it
* Use same environment '$PATH' variable when using sudo
* Fail the docker build when mandatory build-arg 'mender_client_version' is not set.
* Update Dockerfile to use latest stable mender-artifact, v2.4.0
* Use mender-artfact v3. Requires rebuild of device-image-shell container.
* Use LZMA for smaller Artifact size (but slower generation).
* Update mender-convert to use final Mender v2.0 release

New changes in mender-convert since 1.0.0:

* Fix syntax error when calling "mender-convert raw-disk-image-shrink-rootfs"
* Experimental device emulation environment
* Create repartitioned Mender compliant image from Yocto image for qemu x86-64
([MEN-2207](https://northerntech.atlassian.net/browse/MEN-2207))
* Add commits check to mender-convert repo
([MEN-2282](https://northerntech.atlassian.net/browse/MEN-2282))
* Provide systemd service for Raspberry Pi boards to resize data partition
([MEN-2254](https://northerntech.atlassian.net/browse/MEN-2254))
* Install Mender related files to Mender image based on Yocto image for qemu x86-64
([MEN-2207](https://northerntech.atlassian.net/browse/MEN-2207))
* Check a Linux ext4 file system before resizing 'primary' partition
([MEN-2242](https://northerntech.atlassian.net/browse/MEN-2242))
* compile mender during docker image creation
* Switch to 1.6.0 Mender client as default for docker environment
* Add license check to mender-convert repo
([MEN-2282](https://northerntech.atlassian.net/browse/MEN-2282))
* Use a toolchain tuned for ARMv6 architecture to maintain support for Raspberry Pi Zero
([MEN-2399](https://northerntech.atlassian.net/browse/MEN-2399))
* Fix docker-mender-convert for paths with spaces
* Add version option for mender convert
([MEN-2257](https://northerntech.atlassian.net/browse/MEN-2257))
* Fix permission denied error in when calling "mender-convert raw-disk-image-shrink-rootfs"
* Give container access to host's kernel modules
([MEN-2255](https://northerntech.atlassian.net/browse/MEN-2255))
* Support compiling Mender client in mender-convert container.
* Document missing options in the scripts
([MEN-2248](https://northerntech.atlassian.net/browse/MEN-2248))
* Store sector size in raw/mender disk image related arrays
([MEN-2242](https://northerntech.atlassian.net/browse/MEN-2242))
* Avoid duplicate content in cmdline.txt
* rpi: update to 2018.07 U-boot
([MEN-2198](https://northerntech.atlassian.net/browse/MEN-2198))
* Add --storage-total-size-mb option to mender-convert tool
([MEN-2242](https://northerntech.atlassian.net/browse/MEN-2242))
* Make tool ready for handling input images containing 3 partitions
([MEN-2207](https://northerntech.atlassian.net/browse/MEN-2207))
* Allow to use "--demo" flag with any given server type
* Use local (checked out) version of mender-convert inside container
* Support passing mender-convert arguments to docker-mender-convert directly
* remove expert commands
* Refactor mender-convert to use make install target
([MEN-2411](https://northerntech.atlassian.net/browse/MEN-2411))
* Improve documentation
* Set production/demo intervals conditionally
([MEN-2248](https://northerntech.atlassian.net/browse/MEN-2248))
* Optimizations to speed up conversion, utilizing sparse
images.
* remove dependency on gcc6
* Install GRUB bootloader to Mender image based on Yocto image for qemu x86-64
([MEN-2207](https://northerntech.atlassian.net/browse/MEN-2207))

## mender-convert 1.0.0

_Released 12.13.2018_

### Statistics

A total of 4848 lines added, 1459 removed (delta 3389)

| Developers with the most changesets |            |
|-------------------------------------|------------|
| Adam Podogrocki                     | 32 (45.1%) |
| Dominik Adamski                     | 18 (25.4%) |
| Eystein Måløy Stenberg              | 13 (18.3%) |
| Mirza Krak                          | 6 (8.5%)   |
| Mika Tuupola                        | 1 (1.4%)   |
| Pierre-Jean Texier                  | 1 (1.4%)   |

| Developers with the most changed lines |              |
|----------------------------------------|--------------|
| Adam Podogrocki                        | 4297 (87.0%) |
| Eystein Måløy Stenberg                 | 324 (6.6%)   |
| Dominik Adamski                        | 241 (4.9%)   |
| Mirza Krak                             | 74 (1.5%)    |
| Mika Tuupola                           | 1 (0.0%)     |
| Pierre-Jean Texier                     | 1 (0.0%)     |

| Developers with the most lines removed |           |
|----------------------------------------|-----------|
| Mirza Krak                             | 33 (2.3%) |

| Developers with the most signoffs (total 70) |            |
|----------------------------------------------|------------|
| Adam Podogrocki                              | 31 (44.3%) |
| Dominik Adamski                              | 18 (25.7%) |
| Eystein Måløy Stenberg                       | 13 (18.6%) |
| Mirza Krak                                   | 6 (8.6%)   |
| Mika Tuupola                                 | 1 (1.4%)   |
| Pierre-Jean Texier                           | 1 (1.4%)   |

| Top changeset contributors by employer |            |
|----------------------------------------|------------|
| RnDity                                 | 50 (70.4%) |
| Northern.tech                          | 19 (26.8%) |
| tuupola@appelsiini.net                 | 1 (1.4%)   |
| Lafon Technologies                     | 1 (1.4%)   |

| Top lines changed by employer |              |
|-------------------------------|--------------|
| RnDity                        | 4538 (91.9%) |
| Northern.tech                 | 398 (8.1%)   |
| tuupola@appelsiini.net        | 1 (0.0%)     |
| Lafon Technologies            | 1 (0.0%)     |

| Employers with the most signoffs (total 70) |            |
|---------------------------------------------|------------|
| RnDity                                      | 49 (70.0%) |
| Northern.tech                               | 19 (27.1%) |
| tuupola@appelsiini.net                      | 1 (1.4%)   |
| Lafon Technologies                          | 1 (1.4%)   |

| Employers with the most hackers (total 6) |           |
|-------------------------------------------|-----------|
| RnDity                                    | 2 (33.3%) |
| Northern.tech                             | 2 (33.3%) |
| tuupola@appelsiini.net                    | 1 (16.7%) |
| Lafon Technologies                        | 1 (16.7%) |

### Changelogs

#### mender-convert (1.0.0)

Initial release of mender-convert! Some developer versions were tested along the
way, so here is the changelog since then:

* Make tool ready for handling input images containing 3 partitions
([MEN-2207](https://northerntech.atlassian.net/browse/MEN-2207))
* Support passing mender-convert arguments to docker-mender-convert directly
* Switch to 1.6.0 Mender client as default for docker environment
* Use local (checked out) version of mender-convert inside container
* Support compiling Mender client in mender-convert container.
* compile mender during docker image creation
* Install GRUB bootloader to Mender image based on Yocto image for qemu x86-64
([MEN-2207](https://northerntech.atlassian.net/browse/MEN-2207))
* fix image paths printed at end of conversion
* Docker environment for running mender-convert
* Create repartitioned Mender compliant image from Yocto image for qemu x86-64
([MEN-2207](https://northerntech.atlassian.net/browse/MEN-2207))
* Avoid duplicate content in cmdline.txt
* Install Mender related files to Mender image based on Yocto image for qemu x86-64
([MEN-2207](https://northerntech.atlassian.net/browse/MEN-2207))
* Increase default server retry interval from 1 to 30 seconds.
* Add version option for mender convert
([MEN-2257](https://northerntech.atlassian.net/browse/MEN-2257))

