-- Copyright 2012-2013 Samplecount S.L.
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

module Shakefile.C.OSX (
    DeveloperPath
  , getDeveloperPath
  , getSystemVersion
  , getLatestPlatform
  , macOSX
  , iPhoneOS
  , iPhoneSimulator
  , target
  , getDefaultToolChain
  , toolChain
  , macosx_version_min
  , macosx_version_target
  , iphoneos_version_min
  , iphoneos_version_target
  , universalBinary
) where

import           Control.Applicative
import           Data.List (stripPrefix)
import           Data.List.Split (splitOn)
import           Data.Version (Version(..), showVersion)
import           Development.Shake as Shake
import           Development.Shake.FilePath
import           Shakefile.C
import           Shakefile.Label (append, get, prepend, set)
import qualified System.Directory as Dir
import           System.Process (readProcess)

archFlags :: Target -> [String]
archFlags target = ["-arch", archString (get targetArch target)]

newtype DeveloperPath = DeveloperPath { developerPath :: FilePath }

-- | Get base path of development tools on OSX.
getDeveloperPath :: IO DeveloperPath
getDeveloperPath =
  (DeveloperPath . head . splitOn "\n")
    <$> readProcess "xcode-select" ["--print-path"] ""

platformDeveloperPath :: DeveloperPath -> String -> FilePath
platformDeveloperPath developer platform =
  developerPath developer </> "Platforms" </> (platform ++ ".platform") </> "Developer"

macOSX :: Version -> Platform
macOSX = Platform "MacOSX"

iPhoneOS :: Version -> Platform
iPhoneOS = Platform "iPhoneOS"

iPhoneSimulator :: Version -> Platform
iPhoneSimulator = Platform "iPhoneSimulator"

target :: Arch -> Platform -> Target
target arch = mkTarget arch "darwin"

platformSDKPath :: DeveloperPath -> Platform -> FilePath
platformSDKPath developer platform =
      platformDeveloperPath developer name
  </> "SDKs"
  </> (name ++ showVersion (platformVersion platform) ++ ".sdk")
  where name = platformName platform

getLatestPlatform :: DeveloperPath -> (Version -> Platform) -> IO Platform
getLatestPlatform developer mkPlatform = do
  dirs <- Dir.getDirectoryContents $ platformDeveloperPath developer name </> "SDKs"
  let maxVersion = case [ x | Just x <- map (fmap (  map read {- slip in an innocent read, can't fail, can it? -}
                                                   . splitOn "."
                                                   . dropExtension)
                                                  . stripPrefix name)
                                            dirs ] of
                      [] -> error "OSX: No SDK found"
                      xs -> maximum xs
  return $ mkPlatform $ Version maxVersion []
  where name = platformName (mkPlatform (Version [] []))

-- | Get OSX system version (first two digits).
getSystemVersion :: IO Version
getSystemVersion =
  flip Version []
    <$> (map read . take 2 . splitOn ".")
    <$> readProcess "sw_vers" ["-productVersion"] ""

getDefaultToolChain :: IO (Target, Action ToolChain)
getDefaultToolChain = do
    myVersion <- getSystemVersion
    let defaultTarget = target (X86 X86_64) (macOSX myVersion)
    return (defaultTarget, toolChain <$> liftIO getDeveloperPath <*> pure defaultTarget)

toolChain :: DeveloperPath -> Target -> ToolChain
toolChain developer target =
    set variant LLVM
  $ set toolDirectory (Just (developerPath developer </> "Toolchains/XcodeDefault.xctoolchain/usr/bin"))
  $ set compilerCommand "clang"
  $ set archiverCommand "libtool"
  $ set archiver (\toolChain buildFlags inputs output -> do
      need inputs
      command_ [] (tool toolChain archiverCommand)
        $  get archiverFlags buildFlags
        ++ ["-static"]
        ++ ["-o", output]
        ++ inputs
    )
  $ set linkerCommand "clang++"
  $ set linker (\linkResult toolChain ->
      case linkResult of
        Executable      -> defaultLinker toolChain
        SharedLibrary   -> defaultLinker toolChain . prepend linkerFlags ["-dynamiclib"]
        LoadableLibrary -> defaultLinker toolChain . prepend linkerFlags ["-bundle"]
    )
  $ set defaultBuildFlags ( append preprocessorFlags [ "-isysroot", sysRoot ]
                          . append compilerFlags [(Nothing, archFlags target)]
                          . append linkerFlags (archFlags target ++ [ "-isysroot", sysRoot ]) )
  $ defaultToolChain
  where sysRoot = platformSDKPath developer (get targetPlatform target)

macosx_version_min :: Version -> BuildFlags -> BuildFlags
macosx_version_min version = append compilerFlags [(Nothing, ["-mmacosx-version-min=" ++ showVersion version])]

macosx_version_target :: Target -> BuildFlags -> BuildFlags
macosx_version_target = macosx_version_min . platformVersion . get targetPlatform

iphoneos_version_min :: Version -> BuildFlags -> BuildFlags
iphoneos_version_min version = append compilerFlags [(Nothing, ["-miphoneos-version-min=" ++ showVersion version])]

iphoneos_version_target :: Target -> BuildFlags -> BuildFlags
iphoneos_version_target = iphoneos_version_min . platformVersion . get targetPlatform

universalBinary :: [FilePath] -> FilePath -> Rules FilePath
universalBinary inputs output = do
    output ?=> \_ -> do
        need inputs
        command_ [] "lipo" $ ["-create", "-output", output] ++ inputs
    return output
