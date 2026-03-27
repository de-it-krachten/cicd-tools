# 1.0.0 (2026-03-27)


### Bug Fixes

* Add azure requirements for virtual environments ([525cd88](https://github.com/de-it-krachten/cicd-tools/commit/525cd88fe713dd8c84e84d036efbcc4b9e6cf6c9))
* ci | add 'jinja[spacing]' to be ignored by ansible-lint ([701b84a](https://github.com/de-it-krachten/cicd-tools/commit/701b84af61528ecacebc28a81e3cf76030200a7f))
* Delete faulty code ([09ea16e](https://github.com/de-it-krachten/cicd-tools/commit/09ea16e2d8467c308ffde91fd32353716d7e226f))
* Enforce using system python ([ea0fae3](https://github.com/de-it-krachten/cicd-tools/commit/ea0fae3480372208f204b8bbdff6464310c42519))
* Final fix for 'ansible-collections.sh' ([6433e4a](https://github.com/de-it-krachten/cicd-tools/commit/6433e4a585381911965a9ca4cff2f92a512b15a7))
* Fix collections merge ([f7e7d56](https://github.com/de-it-krachten/cicd-tools/commit/f7e7d56b0c21babd61e8cc1ab579123e0f52488d))
* Fix molecule requirements for other orgs ([6aa0133](https://github.com/de-it-krachten/cicd-tools/commit/6aa0133bb3e95a518fcdd340dffe123647e23aaa))
* Fix support for ansible 2.16 / python 3.6 ([0343e8d](https://github.com/de-it-krachten/cicd-tools/commit/0343e8de3cad483f777221619deb7aa7cdc77c54))
* Fix workflow links in README files ([2cb5088](https://github.com/de-it-krachten/cicd-tools/commit/2cb50883c8f6e20b3bb8dc1af5b4b84fb961d527))
* Github workflow activation no longer make script fail ([dcf65d8](https://github.com/de-it-krachten/cicd-tools/commit/dcf65d894da7b06a9de43872b5f0831a42da6a37))
* Make ansible9 work (SELinux issue solved) ([98849ca](https://github.com/de-it-krachten/cicd-tools/commit/98849cac0e32e46d9f36ab57f75ac5250742c50b))
* Make github releases work on protected branch ([0ca9e56](https://github.com/de-it-krachten/cicd-tools/commit/0ca9e5617598cf908cf03cd807fdf9bff527ac2f))
* Make python.sh exit cleanly ([f46d926](https://github.com/de-it-krachten/cicd-tools/commit/f46d92625db4dfe5af869ad2b49d8922dc47e4b7))
* Multiple fixes for GA ([88fa7ea](https://github.com/de-it-krachten/cicd-tools/commit/88fa7eae56a1d66cb477b93123820915950266b6))
* No support for overlapping parent and child images ([40766ef](https://github.com/de-it-krachten/cicd-tools/commit/40766ef316e44872cbd73a1272b39a7ee4044cd2))
* Refactor 'ansible-collections.sh' for proper output ([97dfdf0](https://github.com/de-it-krachten/cicd-tools/commit/97dfdf03d38f243cc2cfcf59b3f006f34887615c))
* Refactor 'ansible-collections.sh' for simplification ([b412196](https://github.com/de-it-krachten/cicd-tools/commit/b412196270e53a0d88aee7c403b30db0a094244e))
* Remove all deprecation warnings ([de3a983](https://github.com/de-it-krachten/cicd-tools/commit/de3a98343afac731670a02806f5d55f005f7f34a))
* Remove hard-code proxy ([89a9566](https://github.com/de-it-krachten/cicd-tools/commit/89a95666a28171d8fc76121bc28c652a53197c57))
* Remove HOME overwrite ([fa4a3cc](https://github.com/de-it-krachten/cicd-tools/commit/fa4a3cc5780edc1a22411b3f38c9daea2cd12ed2))
* Rename multiple scripts ([f4bb8df](https://github.com/de-it-krachten/cicd-tools/commit/f4bb8dfd0dfd00898648ef1f6d7fd792c6113b4d))
* Support custom ansible venvs ([6dbaba7](https://github.com/de-it-krachten/cicd-tools/commit/6dbaba7629d8dfb433a5d8fc83c013477c338e0b))
* Update ansible-role CI workflow to download the debian package ([67e7852](https://github.com/de-it-krachten/cicd-tools/commit/67e7852d5f1eb5d9b977f44210988fb2c6cf5747))
* Update CI templates ([e35cb69](https://github.com/de-it-krachten/cicd-tools/commit/e35cb696faca108990b0d030dbb5785ea2b11c0f))
* Update code to allign with customer setup ([7a9c098](https://github.com/de-it-krachten/cicd-tools/commit/7a9c0981dd023568d66af52e7fd6ef1399d6bcc6))
* Update docker-build scripts ([49216b4](https://github.com/de-it-krachten/cicd-tools/commit/49216b4cda827ca0f3628f088bd7f62370d5a666))


### Features

* Add ansible-navigator (in venv) ([bc858c7](https://github.com/de-it-krachten/cicd-tools/commit/bc858c7d760af308287e598f95b8df02e29dc442))
* Add jinjanator in venv ([923840b](https://github.com/de-it-krachten/cicd-tools/commit/923840ba824ae57f676efab52277055e4f3fd6d9))
* Add script to setup python virtual environments ([31f00af](https://github.com/de-it-krachten/cicd-tools/commit/31f00afb291e111ae29d76b5621007fa2dc9140f))
* Add support for OpenSUSE/SLES 16 ([6da7ba7](https://github.com/de-it-krachten/cicd-tools/commit/6da7ba73b5b324d347a994e674fe29f8fb105ada))
* Add support for support changes ([11211e6](https://github.com/de-it-krachten/cicd-tools/commit/11211e6ccbeb7056703b6b7cea25523d17da0b9c))
* docker-build | add docker-squash to reduce image size ([f4df9fa](https://github.com/de-it-krachten/cicd-tools/commit/f4df9fafbfa2ae467f821ffaf10c073c79638415))
* first release ([f46d282](https://github.com/de-it-krachten/cicd-tools/commit/f46d282c91d84cdc43e46903a82c0ec25cbe1d95))
* Molecule | Add support for collections ([6fa1832](https://github.com/de-it-krachten/cicd-tools/commit/6fa18323948194d0d29b5498ce5eb5710697477b))
* refactor docker-build.sh ([e3d9d55](https://github.com/de-it-krachten/cicd-tools/commit/e3d9d55cbba242eea6e46dcedc2a42fc77ddb2a2))
* Support self-hosted collections (git) ([a540236](https://github.com/de-it-krachten/cicd-tools/commit/a540236105660fb39110f926f0c349caf64df10f))

# 1.0.0 (2026-03-27)


### Bug Fixes

* Add azure requirements for virtual environments ([525cd88](https://github.com/de-it-krachten/cicd-tools/commit/525cd88fe713dd8c84e84d036efbcc4b9e6cf6c9))
* ci | add 'jinja[spacing]' to be ignored by ansible-lint ([701b84a](https://github.com/de-it-krachten/cicd-tools/commit/701b84af61528ecacebc28a81e3cf76030200a7f))
* Delete faulty code ([09ea16e](https://github.com/de-it-krachten/cicd-tools/commit/09ea16e2d8467c308ffde91fd32353716d7e226f))
* Enforce using system python ([ea0fae3](https://github.com/de-it-krachten/cicd-tools/commit/ea0fae3480372208f204b8bbdff6464310c42519))
* Final fix for 'ansible-collections.sh' ([6433e4a](https://github.com/de-it-krachten/cicd-tools/commit/6433e4a585381911965a9ca4cff2f92a512b15a7))
* Fix collections merge ([f7e7d56](https://github.com/de-it-krachten/cicd-tools/commit/f7e7d56b0c21babd61e8cc1ab579123e0f52488d))
* Fix molecule requirements for other orgs ([6aa0133](https://github.com/de-it-krachten/cicd-tools/commit/6aa0133bb3e95a518fcdd340dffe123647e23aaa))
* Fix support for ansible 2.16 / python 3.6 ([0343e8d](https://github.com/de-it-krachten/cicd-tools/commit/0343e8de3cad483f777221619deb7aa7cdc77c54))
* Fix workflow links in README files ([2cb5088](https://github.com/de-it-krachten/cicd-tools/commit/2cb50883c8f6e20b3bb8dc1af5b4b84fb961d527))
* Github workflow activation no longer make script fail ([dcf65d8](https://github.com/de-it-krachten/cicd-tools/commit/dcf65d894da7b06a9de43872b5f0831a42da6a37))
* Make ansible9 work (SELinux issue solved) ([98849ca](https://github.com/de-it-krachten/cicd-tools/commit/98849cac0e32e46d9f36ab57f75ac5250742c50b))
* Make github releases work on protected branch ([0ca9e56](https://github.com/de-it-krachten/cicd-tools/commit/0ca9e5617598cf908cf03cd807fdf9bff527ac2f))
* Make python.sh exit cleanly ([f46d926](https://github.com/de-it-krachten/cicd-tools/commit/f46d92625db4dfe5af869ad2b49d8922dc47e4b7))
* Multiple fixes for GA ([88fa7ea](https://github.com/de-it-krachten/cicd-tools/commit/88fa7eae56a1d66cb477b93123820915950266b6))
* No support for overlapping parent and child images ([40766ef](https://github.com/de-it-krachten/cicd-tools/commit/40766ef316e44872cbd73a1272b39a7ee4044cd2))
* Refactor 'ansible-collections.sh' for proper output ([97dfdf0](https://github.com/de-it-krachten/cicd-tools/commit/97dfdf03d38f243cc2cfcf59b3f006f34887615c))
* Refactor 'ansible-collections.sh' for simplification ([b412196](https://github.com/de-it-krachten/cicd-tools/commit/b412196270e53a0d88aee7c403b30db0a094244e))
* Remove all deprecation warnings ([de3a983](https://github.com/de-it-krachten/cicd-tools/commit/de3a98343afac731670a02806f5d55f005f7f34a))
* Remove hard-code proxy ([89a9566](https://github.com/de-it-krachten/cicd-tools/commit/89a95666a28171d8fc76121bc28c652a53197c57))
* Remove HOME overwrite ([fa4a3cc](https://github.com/de-it-krachten/cicd-tools/commit/fa4a3cc5780edc1a22411b3f38c9daea2cd12ed2))
* Rename multiple scripts ([f4bb8df](https://github.com/de-it-krachten/cicd-tools/commit/f4bb8dfd0dfd00898648ef1f6d7fd792c6113b4d))
* Support custom ansible venvs ([6dbaba7](https://github.com/de-it-krachten/cicd-tools/commit/6dbaba7629d8dfb433a5d8fc83c013477c338e0b))
* Update ansible-role CI workflow to download the debian package ([67e7852](https://github.com/de-it-krachten/cicd-tools/commit/67e7852d5f1eb5d9b977f44210988fb2c6cf5747))
* Update CI templates ([e35cb69](https://github.com/de-it-krachten/cicd-tools/commit/e35cb696faca108990b0d030dbb5785ea2b11c0f))
* Update code to allign with customer setup ([7a9c098](https://github.com/de-it-krachten/cicd-tools/commit/7a9c0981dd023568d66af52e7fd6ef1399d6bcc6))
* Update docker-build scripts ([49216b4](https://github.com/de-it-krachten/cicd-tools/commit/49216b4cda827ca0f3628f088bd7f62370d5a666))


### Features

* Add ansible-navigator (in venv) ([bc858c7](https://github.com/de-it-krachten/cicd-tools/commit/bc858c7d760af308287e598f95b8df02e29dc442))
* Add jinjanator in venv ([923840b](https://github.com/de-it-krachten/cicd-tools/commit/923840ba824ae57f676efab52277055e4f3fd6d9))
* Add script to setup python virtual environments ([31f00af](https://github.com/de-it-krachten/cicd-tools/commit/31f00afb291e111ae29d76b5621007fa2dc9140f))
* Add support for OpenSUSE/SLES 16 ([6da7ba7](https://github.com/de-it-krachten/cicd-tools/commit/6da7ba73b5b324d347a994e674fe29f8fb105ada))
* Add support for support changes ([11211e6](https://github.com/de-it-krachten/cicd-tools/commit/11211e6ccbeb7056703b6b7cea25523d17da0b9c))
* docker-build | add docker-squash to reduce image size ([f4df9fa](https://github.com/de-it-krachten/cicd-tools/commit/f4df9fafbfa2ae467f821ffaf10c073c79638415))
* first release ([f46d282](https://github.com/de-it-krachten/cicd-tools/commit/f46d282c91d84cdc43e46903a82c0ec25cbe1d95))
* Molecule | Add support for collections ([6fa1832](https://github.com/de-it-krachten/cicd-tools/commit/6fa18323948194d0d29b5498ce5eb5710697477b))
* refactor docker-build.sh ([e3d9d55](https://github.com/de-it-krachten/cicd-tools/commit/e3d9d55cbba242eea6e46dcedc2a42fc77ddb2a2))
* Support self-hosted collections (git) ([a540236](https://github.com/de-it-krachten/cicd-tools/commit/a540236105660fb39110f926f0c349caf64df10f))

## [1.9.2](https://github.com/de-it-krachten/cicd-tools/compare/v1.9.1...v1.9.2) (2026-03-25)


### Bug Fixes

* Remove HOME overwrite ([04d9fed](https://github.com/de-it-krachten/cicd-tools/commit/04d9fed4c5b6a089efdef55e774411d0f72afb84))

## [1.9.1](https://github.com/de-it-krachten/cicd-tools/compare/v1.9.0...v1.9.1) (2026-03-24)


### Bug Fixes

* Remove hard-code proxy ([808f45a](https://github.com/de-it-krachten/cicd-tools/commit/808f45ac8fd42eb761a23077c25afa10849ce05f))

# [1.9.0](https://github.com/de-it-krachten/cicd-tools/compare/v1.8.0...v1.9.0) (2026-03-24)


### Features

* refactor docker-build.sh ([cbdb0d7](https://github.com/de-it-krachten/cicd-tools/commit/cbdb0d702d761ac54903c88f3d09b328db49e53a))

# [1.8.0](https://github.com/de-it-krachten/cicd-tools/compare/v1.7.0...v1.8.0) (2026-03-18)


### Bug Fixes

* ci | add 'jinja[spacing]' to be ignored by ansible-lint ([899d4fc](https://github.com/de-it-krachten/cicd-tools/commit/899d4fc6b992a7eebba5123e4b9e258b7f7c8c6a))


### Features

* docker-build | add docker-squash to reduce image size ([893da00](https://github.com/de-it-krachten/cicd-tools/commit/893da00a2ed08db76c56f657bfa82613ddfb03a0))

# [1.7.0](https://github.com/de-it-krachten/cicd-tools/compare/v1.6.0...v1.7.0) (2026-03-15)


### Bug Fixes

* Enforce using system python ([9034262](https://github.com/de-it-krachten/cicd-tools/commit/90342628a02c13dd22c2742407d4e98e6cf4cda9))
* Remove all deprecation warnings ([02ba7ec](https://github.com/de-it-krachten/cicd-tools/commit/02ba7ec87c8a5447676155b29d84fe59fe0e0eac))
* Update docker-build scripts ([3d3816a](https://github.com/de-it-krachten/cicd-tools/commit/3d3816ac82635394d1bd27122fbafe35870a9f9c))


### Features

* Add support for support changes ([98191bf](https://github.com/de-it-krachten/cicd-tools/commit/98191bfde36b5045c1d221db266850411e4d0efd))

# [1.6.0](https://github.com/de-it-krachten/cicd-tools/compare/v1.5.2...v1.6.0) (2026-02-25)


### Bug Fixes

* Update CI templates ([27b0b65](https://github.com/de-it-krachten/cicd-tools/commit/27b0b6500431496d0a028209dce1c87d45be108a))


### Features

* Add support for OpenSUSE/SLES 16 ([29e655a](https://github.com/de-it-krachten/cicd-tools/commit/29e655a89d1318947efb3540579f7d5f6a3de25b))

## [1.5.2](https://github.com/de-it-krachten/cicd-tools/compare/v1.5.1...v1.5.2) (2026-02-07)


### Bug Fixes

* Multiple fixes for GA ([60cee9a](https://github.com/de-it-krachten/cicd-tools/commit/60cee9a6664f8127e426edf945a449f19c8cb7f7))

## [1.5.1](https://github.com/de-it-krachten/cicd-tools/compare/v1.5.0...v1.5.1) (2026-02-04)


### Bug Fixes

* Fix collections merge ([5ed6d63](https://github.com/de-it-krachten/cicd-tools/commit/5ed6d630dc90c862289c10d4fe488c663ad077f6))

# [1.5.0](https://github.com/de-it-krachten/cicd-tools/compare/v1.4.1...v1.5.0) (2026-02-04)


### Features

* Support self-hosted collections (git) ([96ee2cb](https://github.com/de-it-krachten/cicd-tools/commit/96ee2cbf2c5611438e6c1179928ffb20e6d58198))

## [1.4.1](https://github.com/de-it-krachten/cicd-tools/compare/v1.4.0...v1.4.1) (2026-02-03)


### Bug Fixes

* Make github releases work on protected branch ([068d377](https://github.com/de-it-krachten/cicd-tools/commit/068d37764982f96e3d2471f588b7ab76e561cbbd))

# [1.4.0](https://github.com/de-it-krachten/cicd-tools/compare/v1.3.3...v1.4.0) (2026-02-03)


### Bug Fixes

* Fix molecule requirements for other orgs ([4b72362](https://github.com/de-it-krachten/cicd-tools/commit/4b723622647fed3bd1c3db3169e729d9f6763cb9))
* Fix workflow links in README files ([679c6d4](https://github.com/de-it-krachten/cicd-tools/commit/679c6d4225ab94a01f1565c15fb490ffe57ae44d))


### Features

* Molecule | Add support for collections ([c7028c4](https://github.com/de-it-krachten/cicd-tools/commit/c7028c4e7fed5429c642dfc0e0d469014e009279))

## [1.3.3](https://github.com/de-it-krachten/cicd-tools/compare/v1.3.2...v1.3.3) (2026-01-31)


### Bug Fixes

* Update code to allign with customer setup ([61d1711](https://github.com/de-it-krachten/cicd-tools/commit/61d1711be6cc783da71c59b10b82db2e4964de73))

## [1.3.2](https://github.com/de-it-krachten/cicd-tools/compare/v1.3.1...v1.3.2) (2026-01-29)


### Bug Fixes

* Github workflow activation no longer make script fail ([964fe32](https://github.com/de-it-krachten/cicd-tools/commit/964fe329a96a1be9af7ce576eb693983d97fb012))

## [1.3.1](https://github.com/de-it-krachten/cicd-tools/compare/v1.3.0...v1.3.1) (2026-01-28)


### Bug Fixes

* Make python.sh exit cleanly ([9a39d5e](https://github.com/de-it-krachten/cicd-tools/commit/9a39d5e3cb4f52e30e7633c9250ed2748530b8f0))

# [1.3.0](https://github.com/de-it-krachten/cicd-tools/compare/v1.2.0...v1.3.0) (2026-01-28)


### Bug Fixes

* Support custom ansible venvs ([3863368](https://github.com/de-it-krachten/cicd-tools/commit/38633684e89564ceb2884c8fda22597a72d46f3e))


### Features

* Add ansible-navigator (in venv) ([ce54448](https://github.com/de-it-krachten/cicd-tools/commit/ce54448a0f63b28ecac635588443fd02e23ba529))

# [1.2.0](https://github.com/de-it-krachten/cicd-tools/compare/v1.1.8...v1.2.0) (2025-12-11)


### Bug Fixes

* Make ansible9 work (SELinux issue solved) ([ec8f4cb](https://github.com/de-it-krachten/cicd-tools/commit/ec8f4cb44045323aeb1ae2acb4c2ec4f07468874))


### Features

* Add jinjanator in venv ([d0ce439](https://github.com/de-it-krachten/cicd-tools/commit/d0ce4397bed0b36c20e63dcd3cd7a7aee3500bdd))

## [1.1.8](https://github.com/de-it-krachten/cicd-tools/compare/v1.1.7...v1.1.8) (2025-12-06)


### Bug Fixes

* Final fix for 'ansible-collections.sh' ([9ad0fd0](https://github.com/de-it-krachten/cicd-tools/commit/9ad0fd0e7e4977a1325d6c686a8a4af2f6057e0e))

## [1.1.7](https://github.com/de-it-krachten/cicd-tools/compare/v1.1.6...v1.1.7) (2025-12-06)


### Bug Fixes

* Refactor 'ansible-collections.sh' for proper output ([dbbfcff](https://github.com/de-it-krachten/cicd-tools/commit/dbbfcffa052524d720fc8f2436add39f664e62df))

## [1.1.6](https://github.com/de-it-krachten/cicd-tools/compare/v1.1.5...v1.1.6) (2025-12-06)


### Bug Fixes

* Refactor 'ansible-collections.sh' for simplification ([fac4a8b](https://github.com/de-it-krachten/cicd-tools/commit/fac4a8b84ed747dfb7f0b8be3caa7d7ea1f75dfa))

## [1.1.5](https://github.com/de-it-krachten/cicd-tools/compare/v1.1.4...v1.1.5) (2025-12-06)


### Bug Fixes

* Delete faulty code ([a30b2e0](https://github.com/de-it-krachten/cicd-tools/commit/a30b2e00d6e5bb4f08aa392d9b005f8eac49085a))

## [1.1.4](https://github.com/de-it-krachten/cicd-tools/compare/v1.1.3...v1.1.4) (2025-12-06)


### Bug Fixes

* Fix support for ansible 2.16 / python 3.6 ([ab31be5](https://github.com/de-it-krachten/cicd-tools/commit/ab31be5f2d261deb992c679359b9e83dbbd985c8))

## [1.1.3](https://github.com/de-it-krachten/cicd-tools/compare/v1.1.2...v1.1.3) (2025-10-13)


### Bug Fixes

* Update ansible-role CI workflow to download the debian package ([0cdfb20](https://github.com/de-it-krachten/cicd-tools/commit/0cdfb2026bcd8fceadff3780bc9aed7f31b3c6a1))

## [1.1.2](https://github.com/de-it-krachten/cicd-tools/compare/v1.1.1...v1.1.2) (2025-10-13)


### Bug Fixes

* Rename multiple scripts ([de1ba14](https://github.com/de-it-krachten/cicd-tools/commit/de1ba14984003bc20ab340d0b49d75974bf14bd2))

## [1.1.1](https://github.com/de-it-krachten/cicd-tools/compare/v1.1.0...v1.1.1) (2025-09-22)


### Bug Fixes

* Add azure requirements for virtual environments ([54aad18](https://github.com/de-it-krachten/cicd-tools/commit/54aad184d102766fdf51f9ec221c0d0639181b8b))

# [1.1.0](https://github.com/de-it-krachten/cicd-tools/compare/v1.0.0...v1.1.0) (2025-09-22)


### Features

* Add script to setup python virtual environments ([d6c66d6](https://github.com/de-it-krachten/cicd-tools/commit/d6c66d6b0e955f2a5c7d2083b93f399ec5e410b8))

# 1.0.0 (2025-09-21)


### Features

* first release ([fb8b356](https://github.com/de-it-krachten/cicd-tools/commit/fb8b35619c8d6e8af8ab22bc0de95cb8a533450b))
