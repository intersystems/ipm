/// Tests that uninstall removes all resources under a PKG resource even when the casing
/// of the package name in module.xml differs from the casing of the stored class/routine/include names.
/// See: GetChildren uses %Dictionary.ClassDefinition/%Dictionary.RoutineDefinition for case-insensitive lookup.
Class Test.PM.Integration.PkgCaseUninstall Extends Test.PM.Integration.Base
{

/// module.xml declares Test.PKGCASE.PKG (uppercase) but actual resources are Test.PkgCase.*
Parameter ModuleName = "pkg-case-test";

Method TestPkgCaseMismatchUninstall()
{
    set moduleDir = ..GetModuleDir(..#ModuleName)
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ moduleDir), "Loaded pkg-case-test")

    // Confirm resources were loaded
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("Test.PkgCase.MyClass"), "Class exists after load")
    do $$$AssertTrue(##class(%Library.Routine).Exists("Test.PkgCase.MyRoutine.MAC"), "Routine exists after load")
    do $$$AssertTrue(##class(%Library.Routine).Exists("Test.PkgCase.MyInclude.INC"), "Include exists after load")

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ ..#ModuleName), "Uninstalled pkg-case-test")

    // All three resource types must be removed despite the casing mismatch in module.xml
    do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("Test.PkgCase.MyClass"), "Class removed after uninstall")
    do $$$AssertNotTrue(##class(%Library.Routine).Exists("Test.PkgCase.MyRoutine.MAC"), "Routine removed after uninstall")
    do $$$AssertNotTrue(##class(%Library.Routine).Exists("Test.PkgCase.MyInclude.INC"), "Include removed after uninstall")
}

}
