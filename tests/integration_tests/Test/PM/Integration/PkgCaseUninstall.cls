/// Tests that uninstall correctly handles PKG resources where the casing of the package
/// name in module.xml differs from the casing of the stored class/routine/include names,
/// and that resources owned by other modules within the same package are not deleted.
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

/// Verifies that uninstalling a PKG module with a casing mismatch does not delete resources
/// owned by a different module that happen to fall within the same package prefix.
Method TestPkgCaseOwnershipExclusion()
{
    set moduleDirA = ..GetModuleDir(..#ModuleName)
    set moduleDirB = ..GetModuleDir("pkg-case-extra")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ moduleDirA), "Loaded pkg-case-test")
    do $$$AssertStatusOK(##class(%IPM.Main).Shell("load " _ moduleDirB), "Loaded pkg-case-extra")

    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("Test.PkgCase.ExtraClass"), "ExtraClass exists after load")

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall " _ ..#ModuleName), "Uninstalled pkg-case-test")

    // ExtraClass belongs to pkg-case-extra and must survive uninstall of pkg-case-test
    do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("Test.PkgCase.ExtraClass"), "ExtraClass not removed by uninstall of pkg-case-test")

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("uninstall pkg-case-extra"), "Uninstalled pkg-case-extra")

    // ExtraClass should now be removed after uninstalling its owning module
    do $$$AssertNotTrue(##class(%Dictionary.ClassDefinition).%ExistsId("Test.PkgCase.ExtraClass"), "ExtraClass removed by uninstall of pkg-case-extra")
}

}
