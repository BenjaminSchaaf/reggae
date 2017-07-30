/**
 High-level rules for building dub projects. The rules in this module
 only replicate what dub does itself. This allows a reggaefile.d to
 reuse the information that dub already knows about.
 */

module reggae.rules.dub;

import reggae.config; // isDubProject

static if(isDubProject) {

    import reggae.dub.info;
    import reggae.types;
    import reggae.build;
    import reggae.rules.common;
    import std.typecons;
    import std.traits;

    /**
     Builds the main dub target (equivalent of "dub build")
    */
    Target dubDefaultTarget(Flags compilerFlags = Flags(), Flag!"allTogether" allTogether = No.allTogether)() {
        enum config = "default";
        const dubInfo = configToDubInfo[config];
        enum targetName = dubInfo.targetName;
        enum linkerFlags = dubInfo.mainLinkerFlags;
        return dubTarget!(() { Target[] t; return t;})
            (
                targetName,
                dubInfo,
                compilerFlags.value,
                Yes.main,
                allTogether,
                linkerFlags
            );
    }


    /**
       A target corresponding to `dub test`
     */
    Target dubTestTarget(Flags compilerFlags = Flags())() {
        const config = "unittest" in configToDubInfo ? "unittest" : "default";

        auto actualCompilerFlags = compilerFlags.value;
        if("unittest" !in configToDubInfo) actualCompilerFlags ~= " -unittest";

        const hasMain = configToDubInfo[config].packages[0].mainSourceFile != "";
        const linkerFlags = hasMain ? [] : ["-main"];

        // since dmd has a bug pertaining to separate compilation and __traits(getUnitTests),
        // we default here to compiling all-at-once for the unittest build
        return dubTarget!()(TargetName("ut"),
                            configToDubInfo[config],
                            actualCompilerFlags,
                            Yes.main,
                            Yes.allTogether,
                            linkerFlags);
    }

    /**
     Builds a particular dub configuration (executable, unittest, etc.)
     */
    Target dubConfigurationTarget(Configuration config = Configuration("default"),
                                  Flags compilerFlags = Flags(),
                                  Flag!"main" includeMain = Yes.main,
                                  Flag!"allTogether" allTogether = No.allTogether,
                                  alias objsFunction = () { Target[] t; return t; },
                                  )
        () if(isCallable!objsFunction)
    {
        const dubInfo = configToDubInfo[config.value];
        return dubTarget!objsFunction(dubInfo.targetName,
                                      dubInfo,
                                      compilerFlags.value,
                                      includeMain,
                                      allTogether);
    }


    Target dubTarget(alias objsFunction = () { Target[] t; return t;})
                    (in TargetName targetName,
                     in DubInfo dubInfo,
                     in string compilerFlags,
                     in Flag!"main" includeMain = Yes.main,
                     in Flag!"allTogether" allTogether = No.allTogether,
                     in string[] linkerFlags = [])
    {

        import reggae.rules.common: staticLibraryTarget;
        import std.array: join;
        import std.path: buildPath;

        const sharedFlags = dubInfo.targetType == "dynamicLibrary"
            ? "-lib"
            : "";
        const allLinkerFlags = (linkerFlags ~ dubInfo.linkerFlags ~ sharedFlags).join(" ");
        auto dubObjs = dubInfo.toTargets(includeMain, compilerFlags, allTogether);
        auto allObjs = objsFunction() ~ dubObjs;

        const postBuildCommands = dubInfo.postBuildCommands;

        string realName() {
            // otherwise the target wouldn't be top-level in the presence of
            // postBuildCommands
            return postBuildCommands == ""
                ? targetName.value
                : buildPath("$project", targetName.value);
        }

        auto target = dubInfo.targetType == "library" || dubInfo.targetType == "staticLibrary"
            ? staticLibraryTarget(realName, allObjs)[0]
            : link(ExeName(realName),
                   allObjs,
                   Flags(allLinkerFlags));

        return postBuildCommands == ""
            ? target
            : Target.phony("postBuild", postBuildCommands, target);
    }
}
