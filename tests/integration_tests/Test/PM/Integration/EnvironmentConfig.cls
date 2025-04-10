Class Test.PM.Integration.EnvironmentConfig Extends Test.PM.Integration.Base
{

Method TestInstallTimeConfig()
{
    Set TargetPath = "install-time-config"
    Set localRepoPath = ..GetModuleDir(TargetPath)
    Set packageName = "install-time-config"
    Set envPath1 = ##class(%File).Construct($Get(^UnitTestRoot), "_data", TargetPath, "env1.json")
    Set envPath2 = ##class(%File).Construct($Get(^UnitTestRoot), "_data", TargetPath, "env2.json")

    Set tSC = ##class(%IPM.Main).Shell("repo -fs -name local -path " _ localRepoPath)
    Do $$$AssertStatusOK(tSC, "Set up local repo successfully")

    Do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    // If the env.json files is not properly read, the RunOnLoad() method generator in the package will throw an error, causing a `Compile` failure
    Set tSC = ##class(%IPM.Main).Shell($$$FormatText("install %1 -env %2;%3", packageName, envPath1, envPath2))
    Do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)
    Do $$$AssertStatusOK(tSC, "Installed module with its dependency successfully")
    Do $$$AssertTrue(..FindStringInMultiDimArray("Successfully acquired magic value: 1234", .output))
    Do $$$AssertTrue(..FindStringInMultiDimArray("Successfully acquired magic value: 42", .output))

    Set tSC = ##class(%IPM.Main).Shell("repo -delete-all")
    Do $$$AssertStatusOK(tSC, "Deleted all repos successfully")

    Set tSC = ##class(%IPM.Main).Shell("repo -reset-defaults")
    Do $$$AssertStatusOK(tSC, "Reset repo to default successfully")
}

Method TestPhaseConfig()
{
    Set TargetPath = "phase-config"
    Set packagePath = ..GetModuleDir(TargetPath, "package")
    Set envPath = ##class(%File).Construct($Get(^UnitTestRoot), "_data", TargetPath, "env.json")
    Set packageName = "phase-config"

    Do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    Set tSC = ##class(%IPM.Main).Shell($$$FormatText("load %1 -env %2", packagePath, envPath))
    Do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)
    Do $$$AssertStatusOK(tSC, "Loaded module successfully")
    Do $$$AssertTrue(..FindStringInMultiDimArray("AfterCompile: xxx", .output))

    For template = "verify %1 -only -env %2", "%1 verify -only -env %2" {
        Do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
        Set tSC = ##class(%IPM.Main).Shell($$$FormatText(template, packageName, envPath))
        Do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)
        Do $$$AssertStatusOK(tSC, "Verified module successfully")
        Do $$$AssertTrue(..FindStringInMultiDimArray("BeforeVerify: yyy", .output))
    }

    Do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    Set tSC = ##class(%IPM.Main).Shell($$$FormatText("%1 CustomPhase -env %2", packageName, envPath))
    Do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)
    Do $$$AssertStatusOK(tSC, "Ran custom phase ""MyPhase"" successfully")
    Do $$$AssertTrue(..FindStringInMultiDimArray("MyPhase: zzz", .output))
}

}
