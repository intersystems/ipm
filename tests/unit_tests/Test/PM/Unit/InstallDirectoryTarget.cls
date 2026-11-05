Class Test.PM.Unit.InstallDirectoryTarget Extends %UnitTest.TestCase
{

Parameter INSTALLDIR = "/usr/irissys/";

Parameter DATADIR = "/durable/iris/";

Method TestUnderInstallDirectory()
{
    do $$$AssertTrue(..InDurableLayout("/usr/irissys/csp/myapp/"))
    do $$$AssertTrue(..InDurableLayout("/usr/irissys/lib/mylib.so"))
    do $$$AssertTrue(..InDurableLayout("/usr/irissys"))
}

Method TestUnderDataDirectory()
{
    do $$$AssertNotTrue(..InDurableLayout("/durable/iris/mgr/myapp/"))
}

Method TestOutsideBoth()
{
    do $$$AssertNotTrue(..InDurableLayout("/opt/myapp/"))
    do $$$AssertNotTrue(..InDurableLayout("/usr/irissys-other/myapp/"))
}

Method TestSameInstallAndDataDirectory()
{
    set inInstall = ##class(%IPM.Utils.File).IsInInstallDirectoryOnly("/usr/irissys/csp/myapp/", ..#INSTALLDIR, ..#INSTALLDIR)
    do $$$AssertNotTrue(inInstall)
}

Method TestDataDirectoryInsideInstallDirectory()
{
    set dataDir = "/usr/irissys/data/"
    set inInstall = ##class(%IPM.Utils.File).IsInInstallDirectoryOnly("/usr/irissys/data/mgr/myapp/", ..#INSTALLDIR, dataDir)
    do $$$AssertNotTrue(inInstall)
    set inInstall = ##class(%IPM.Utils.File).IsInInstallDirectoryOnly("/usr/irissys/csp/myapp/", ..#INSTALLDIR, dataDir)
    do $$$AssertTrue(inInstall)
}

/// Checks path against separate install and data directories, the layout of a container with durable %SYS.
ClassMethod InDurableLayout(path As %String) As %Boolean
{
    return ##class(%IPM.Utils.File).IsInInstallDirectoryOnly(path, ..#INSTALLDIR, ..#DATADIR)
}

}
