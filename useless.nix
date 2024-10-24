
# WTF
iosPostInstall =  {pkgs, system}: bundleName: ''
  ${pkgs.tree}/bin/tree $out
  mkdir tmp
  find ./dist -name "libHS*-ghc*.a" -exec cp {} tmp \;
  (cd tmp; ${pkgs.tree}/bin/tree .; ar x libHS*.a; for o in *.o; do if /usr/bin/otool -xv $o|grep ldadd ; then echo $o; fi; done; cd ..; rm -fR tmp)
  mkdir -p $out/_pkg
  # copy over includes, we might want those, but maybe not.
  # cp -r $out/lib/*/*/include $out/_pkg/
  # find the libHS...ghc-X.Y.Z.a static library; this is the
  # rolled up one with all dependencies included.
  find ./dist -name "libHS*.a" -exec cp {} $out/_pkg \;
  find ${pkgs.libffi.overrideAttrs (old: { dontDisableStatic = true; })}/lib -name "*.a" -exec cp {} $out/_pkg \;
  find ${pkgs.gmp6.override { withStatic = true; }}/lib -name "*.a" -exec cp {} $out/_pkg \;
  # There is no static libc
  ${pkgs.tree}/bin/tree $out/_pkg
  for pkg in $out/_pkg/*.a; do
    chmod +w $pkg
    ${mac2ios.packages.${system}.mac2ios}/bin/mac2ios $pkg
    chmod -w $pkg
  done

  mkdir tmp
  find $out/_pkg -name "libHS*-ghc*.a" -exec cp {} tmp \;
  (cd tmp; ${pkgs.tree}/bin/tree .; ar x libHS*.a; for o in *.o; do if /usr/bin/otool -xv $o|grep ldadd ; then echo $o; fi; done; cd ..; rm -fR tmp)

  sha256sum $out/_pkg/*.a

  (cd $out/_pkg; ${pkgs.zip}/bin/zip -r -9 $out/${bundleName}.zip *)
  rm -fR $out/_pkg
  mkdir -p $out/nix-support
  echo "file binary-dist \"$(echo $out/*.zip)\"" \
      > $out/nix-support/hydra-build-products
'';


# This module can be used on buildSimplexLib as input while doing ios dev.
    iosOverridesModule = bundleName: {
      smallAddressSpace = true;
      enableShared = false;
      # we need threaded here, otherwise all the queing logic doesn't work properly.
      # for iOS we also use -staticlib, to get one rolled up library.
      # still needs mac2ios patching of the archives.
      ghcOptions = [ "-staticlib" "-threaded" "-DIOS" ];
      postInstall = iosPostInstall bundleName;
    };


# STATIC simplex lib:support (?) for aarch64-linux
              "armv7a-android:lib:support" = (buildSimplexLib android32Compiler).android-support.components.library.override (p: {
                smallAddressSpace = true;
                # we won't want -dyamic (see aarch64-android:lib:simplex-chat)
                enableShared = false;
                # we also do not want to have any dependencies listed (especially no rts!)
                enableStatic = false;

                # This used to work with 8.10.7...
                # setupBuildFlags = p.component.setupBuildFlags ++ map (x: "--ghc-option=${x}") [ "-shared" "-o" "libsupport.so" ];
                # ... but now with 9.6+
                # we have to do the -shared thing by hand.
                postBuild = ''
                  armv7a-unknown-linux-androideabi-ghc -shared -o libsupport.so \
                    -optl-Wl,-u,setLineBuffering \
                    -optl-Wl,-u,pipe_std_to_socket \
                    dist/build/*.a
                '';

                postInstall = ''

                  mkdir -p $out/_pkg
                  cp libsupport.so $out/_pkg
                  ${pkgs.patchelf}/bin/patchelf --remove-needed libunwind.so.1 $out/_pkg/libsupport.so
                  (cd $out/_pkg; ${pkgs.zip}/bin/zip -r -9 $out/pkg-armv7a-android-libsupport.zip *)
                  rm -fR $out/_pkg

                  mkdir -p $out/nix-support
                  echo "file binary-dist \"$(echo $out/*.zip)\"" \
                        > $out/nix-support/hydra-build-products
                '';
              });
              #end of aarch64-linux lib:support (?) drv

            # builds for iOS and iOS simulator
            "aarch64-darwin" = {


              # aarch64-darwin iOS build (to be patched with mac2ios)
              "aarch64-darwin-ios:lib:simplex-chat" = (simplexPureBuild {
                pkgs' = pkgs;
                extra-modules = [{
                  packages.simplex-chat.flags.swift = true;
                  packages.simplexmq.flags.swift = true;
                  packages.direct-sqlcipher.flags.commoncrypto = true;
                  packages.entropy.flags.DoNotGetEntropy = true;
                  packages.simplexmq.components.library.libs = pkgs.lib.mkForce [
                    # TODO: have a cross override for iOS, that sets this.
                    ((pkgs.openssl.override { static = true; }).overrideDerivation (old: { CFLAGS = "-mcpu=apple-a7 -march=armv8-a+norcpc" ;}))
                  ];
                }];
              }).simplex-chat.components.library.override (
                iosOverridesModule "pkg-ios-aarch64-swift-json"
              );


	          # aarch64-darwin build with tagged JSON format (for Mac & Flutter)
              "aarch64-darwin:lib:simplex-chat" = (simplexPureBuild {
                pkgs' = pkgs;
                extra-modules = [{
                  packages.direct-sqlcipher.flags.commoncrypto = true;
                  packages.entropy.flags.DoNotGetEntropy = true;
                  packages.simplexmq.components.library.libs = pkgs.lib.mkForce [
                    ((pkgs.openssl.override { static = true; }).overrideDerivation (old: { CFLAGS = "-mcpu=apple-a7 -march=armv8-a+norcpc" ;}))
                  ];
                }];
              }).simplex-chat.components.library.override (
                iosOverridesModule "pkg-ios-aarch64-tagged-json"
              );
            };
"x86_64-darwin" = {

              # x86_64-darwin iOS simulator build (to be patched with mac2ios)
              "x86_64-darwin-ios:lib:simplex-chat" = (simplexPureBuild {
                pkgs' = pkgs;
                extra-modules = [{
                  packages.simplex-chat.flags.swift = true;
                  packages.simplexmq.flags.swift = true;
                  packages.direct-sqlcipher.flags.commoncrypto = true;
                  packages.entropy.flags.DoNotGetEntropy = true;
                  packages.simplexmq.components.library.libs = pkgs.lib.mkForce [
                    (pkgs.openssl.override { static = true; })
                  ];
                }];
              }).simplex-chat.components.library.override (
                iosOverridesModule "pkg-ios-x86_64-swift-json"
              );


              # x86_64-darwin build with tagged JSON format (for Mac & Flutter iOS simulator)
              "x86_64-darwin:lib:simplex-chat" = (simplexPureBuild {
                pkgs' = pkgs;
                extra-modules = [{
                  packages.direct-sqlcipher.flags.commoncrypto = true;
                  packages.entropy.flags.DoNotGetEntropy = true;
                  packages.simplexmq.components.library.libs = pkgs.lib.mkForce [
                    (pkgs.openssl.override { static = true; })
                  ];
                }];
              }).simplex-chat.components.library.override (
                iosOverridesModule "pkg-ios-x86_64-tagged-json"
              );


            };
