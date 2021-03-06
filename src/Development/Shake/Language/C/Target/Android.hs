-- Copyright 2012-2016 Samplecount S.L.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

{-|
Description: Toolchain definitions and utilities for Android

This module provides toolchain definitions and utilities for targeting Android.
See "Development.Shake.Language.C.Rules" for examples of how to use a target
toolchain.

The minimum required Android NDK revision is 11c.
-}
module Development.Shake.Language.C.Target.Android (
    target
  , sdkVersion
  , toolChain
  , abiString
  , gnustl
  , libcxx
  , native_app_glue
) where

import           Control.Category ((>>>))
import           Development.Shake.FilePath
import           Data.Version (Version(..), showVersion)
import           Development.Shake.Language.C.BuildFlags
import           Development.Shake.Language.C.Target
import           Development.Shake.Language.C.Label
import           Development.Shake.Language.C.ToolChain
import qualified System.Info as System

unsupportedArch :: Arch -> a
unsupportedArch arch = error $ "Unsupported Android target architecture " ++ show arch

toolChainPrefix :: Target -> String
toolChainPrefix x =
    case targetArch x of
        X86 _ -> "x86-"
        Arm Arm64 -> "aarch64-linux-android-"
        Arm _ -> "arm-linux-androideabi-"
        arch  -> unsupportedArch arch

toolPrefix_ :: Target -> String
toolPrefix_ x =
  case targetArch x of
    X86 _ -> "i686-linux-android-"
    _     -> toolChainPrefix x

osPrefix :: String
osPrefix = System.os ++ "-" ++ cpu
    where cpu = case System.arch of
                    "i386" -> "x86"
                    arch   -> arch

-- | Android target for architecture.
target :: Arch -> Target
target = Target Android (Platform "android")

mkDefaultBuildFlags :: FilePath -> Version -> Arch -> BuildFlags -> BuildFlags
mkDefaultBuildFlags ndk version arch =
      append compilerFlags [(Nothing, [sysroot, march])]
  >>> append compilerFlags (archCompilerFlags arch)
  >>> append compilerFlags [(Nothing, [
        "-fpic"
      , "-ffunction-sections"
      , "-funwind-tables"
      , "-fstack-protector"
      , "-no-canonical-prefixes"])]
  >>> append linkerFlags [sysroot, march]
  >>> append linkerFlags (archLinkerFlags arch)
  >>> append linkerFlags ["-Wl,--no-undefined", "-Wl,-z,relro", "-Wl,-z,now"]
  >>> append linkerFlags ["-no-canonical-prefixes"]
  >>> append archiverFlags ["crs"]
  where
    sysroot =    "--sysroot="
              ++ ndk
              </> "platforms"
              </> "android-" ++ show (head (versionBranch version))
              </> "arch-" ++ case arch of
                              (X86 _)     -> "x86"
                              (Arm Arm64) -> "arm64"
                              (Arm _)     -> "arm"
                              _           -> unsupportedArch arch
    march = "-march=" ++ case arch of
                          X86 I386   -> "i386"
                          X86 I686   -> "i686"
                          X86 X86_64 -> "x86_64"
                          Arm Armv5  -> "armv5te"
                          Arm Armv6  -> "armv5te"
                          Arm Armv7  -> "armv7-a"
                          Arm Arm64  -> "armv8-a"
                          _ -> unsupportedArch arch
    archCompilerFlags (Arm Armv7) = [(Nothing, ["-mfloat-abi=softfp", "-mfpu=neon"])]
    archCompilerFlags (Arm Arm64) = []
    archCompilerFlags (Arm _)     = [(Nothing, ["-mtune=xscale", "-msoft-float"])]
    archCompilerFlags _           = []
    archLinkerFlags (Arm Armv7)   = ["-Wl,--fix-cortex-a8"]
    archLinkerFlags _             = []

-- | Construct a version record from an integral Android SDK version.
--
-- prop> sdkVersion 19 == Version [19] []
sdkVersion :: Int -> Version
sdkVersion n = Version [n] []

gccToolChain :: FilePath -> Target -> FilePath
gccToolChain ndk target =
  ndk </> "toolchains"
      </> toolChainPrefix target ++ showVersion (Version [4,9] [])
      </> "prebuilt"
      </> osPrefix

-- | Construct an Android toolchain.
toolChain :: FilePath                     -- ^ NDK source directory
          -> Version                      -- ^ SDK version, see `sdkVersion`
          -> ToolChainVariant             -- ^ Toolchain variant
          -> Target                       -- ^ Build target, see `target`
          -> ToolChain                    -- ^ Resulting toolchain
toolChain "" _ _ _ = error "Empty NDK directory"
toolChain ndk version GCC t =
    set variant GCC
  $ set toolDirectory (Just (gccToolChain ndk t </> "bin"))
  $ set toolPrefix (toolPrefix_ t)
  $ set compilerCommand "gcc"
  $ set archiverCommand "ar"
  $ set linkerCommand "g++"
  $ set defaultBuildFlags (return $ mkDefaultBuildFlags ndk version (targetArch t))
  $ defaultToolChain
toolChain ndk version LLVM t =
    set variant LLVM
  $ set toolDirectory (Just (ndk </> "toolchains"
                                 </> "llvm"
                                 </> "prebuilt"
                                 </> osPrefix
                                 </> "bin"))
  $ set compilerCommand "clang"
  $ set archiverCommand (gccToolChain ndk t </> "bin" </> toolPrefix_ t ++ "ar")
  $ set linkerCommand "clang++"
  $ set defaultBuildFlags (return $
    let flags = [ "-target", llvmTarget t
                , "-gcc-toolchain", gccToolChain ndk t ]
    in  mkDefaultBuildFlags ndk version (targetArch t)
      . append compilerFlags [(Nothing, flags)]
      . append linkerFlags flags
    )
  $ defaultToolChain
  where
    llvmTarget x =
      case targetArch x of
        Arm Armv5 -> "armv5te-none-linux-androideabi"
        Arm Armv7 -> "armv7-none-linux-androideabi"
        Arm Arm64 -> "aarch64-none-linux-android"
        X86 I386  -> "i686-none-linux-android"
        arch      -> unsupportedArch arch
toolChain _ _ tcVariant _ =
  error $ "Unsupported toolchain variant " ++ show tcVariant

-- | Valid Android ABI identifier for the given architecture.
abiString :: Arch -> String
abiString (Arm Armv5) = "armeabi"
abiString (Arm Armv6) = "armeabi"
abiString (Arm Armv7) = "armeabi-v7a"
abiString (Arm Arm64) = "arm64-v8a"
abiString (X86 _)     = "x86"
abiString arch        = unsupportedArch arch

-- | Source paths and build flags for the @native_app_glue@ module.
native_app_glue :: FilePath -- ^ NDK source directory
                -> ([FilePath], BuildFlags -> BuildFlags)
native_app_glue ndk =
  ( [ndk </> "sources/android/native_app_glue/android_native_app_glue.c"]
  , append systemIncludes [ndk </> "sources/android/native_app_glue"] )

-- | Build flags for building with and linking against the GNU @gnustl@ standard C++ library.
gnustl :: Version                     -- ^ GNU STL version
       -> Linkage                     -- ^ `Static` or `Shared`
       -> FilePath                    -- ^ NDK source directory
       -> Target                      -- ^ Build target, see `target`
       -> (BuildFlags -> BuildFlags)  -- ^ 'BuildFlags' modification function
gnustl version linkage ndk t =
    append systemIncludes [stlPath </> "include", stlPath </> "libs" </> abi </> "include"]
  . append libraryPath [stlPath </> "libs" </> abi]
  . append libraries [lib]
    where stlPath = ndk </> "sources/cxx-stl/gnu-libstdc++" </> showVersion version
          abi = abiString (targetArch t)
          lib = case linkage of
                  Static -> "gnustl_static"
                  Shared -> "gnustl_shared"

-- | Build flags for building with and linking against the LLVM @libc++@ standard C++ library.
libcxx :: Linkage                     -- ^ `Static` or `Shared`
       -> FilePath                    -- ^ NDK source directory
       -> Target                      -- ^ Build target, see `target`
       -> (BuildFlags -> BuildFlags)  -- ^ 'BuildFlags' modification function
libcxx linkage ndk t =
    append systemIncludes [ stl </> "llvm-libc++" </> "libcxx" </> "include"
                          -- NOTE: libcxx needs to be first in include path!
                          , stl </> "llvm-libc++abi" </> "libcxxabi" </> "include"
                          , ndk </> "sources" </> "android" </> "support" </> "include" ]
  . append compilerFlags [(Just Cpp, ["-stdlib=libc++"])]
  . append libraryPath [stl </> "llvm-libc++" </> "libs" </> abi]
  . prepend libraries [lib]
    where stl = ndk </> "sources" </> "cxx-stl"
          abi = abiString (targetArch t)
          lib = case linkage of
                  Static -> "c++_static"
                  Shared -> "c++_shared"
