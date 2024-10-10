Class Test.PM.Migration.GloballyEnabled Extends %UnitTest.TestCase
{

Method TestEnabledInSYS()
{
    Do $$$AssertTrue($Data(^|"%SYS"|oddCOM("%IPM.Main")))
    Do $$$AssertEquals(##class(%SYS.Namespace).GetPackageDest($Namespace,"%IPM"),##class(%SYS.Namespace).GetPackageDest("%SYS","%IPM"))
}

}
