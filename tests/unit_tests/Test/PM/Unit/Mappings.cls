/// Unit tests for CLS, PKG, LOC, MAC mappings
Class Test.PM.Unit.Mappings Extends %UnitTest.TestCase
{

Property Params As %Library.DynamicObject;

Property ResourceReferenceClass As %IPM.Storage.ResourceReference;

Property Default As %IPM.Storage.ModuleSetting.ProcessorDefault;

Method OnBeforeAllTests() As %Status
{
    Set ..Params = ##class(%Library.DynamicObject).%New()
    Do ..Params.%Set("Verbose", 0)
    Do ..Params.%Set("DeveloperMode", 0)
    Do ..Params.%Set("NoMapping", 0)
    Do ..Params.%Set("Compile", 1)
    Do ..Params.%Set("Phase", "Reload")
    Do ..Params.%Set("Namespace", "USER")
    Do ..Params.%Set("ResourceName", "")
    Do ..Params.%Set("ModuleName", "DefaultModule")

    Set ..ResourceReferenceClass = ##class(%IPM.Storage.ResourceReference).%New()
    Set ..ResourceReferenceClass.Module = ##class(%IPM.Storage.Module).%New()
    Set ..ResourceReferenceClass.Module.Defaults = ##class(%ListOfObjects).%New()
    Set ..Default = ##class(%IPM.Storage.ModuleSetting.ProcessorDefault).%New()
    Set ..Default.Conditions = ##class(%ListOfObjects).%New()
    Quit $$$OK
}

Method TestNoParentMappingsMAC()
{
    // Initialize ..ResourceReference as MAC file
    Set ..ResourceReferenceClass.Name = "Foo.Bar.MAC"

    // Create a default processor setting for MAC
    Set ..Default.Class = "%IPM.ResourceProcessor.Default.Routine"

    // Add the default setting to the module
    Do ..ResourceReferenceClass.Module.Defaults.Insert(..Default)

    Set testObjMAC = ##class(%IPM.ResourceProcessor.Default.Routine).%New(..ResourceReferenceClass)
    Set ns = "USER"
    Set parentRoutine = "Foo"
    Set childRoutine = "Foo.Bar"
    Set db = "HSLIB"

    // Start fresh
    Set sc = ##class(%IPM.Utils.Module).RemoveRoutineMapping(ns, parentRoutine)
    Do $$$AssertStatusOK(sc, "Remove mappings from parentRoutine Foo to start")
    Set sc = ##class(%IPM.Utils.Module).RemoveRoutineMapping(ns, childRoutine)
    Do $$$AssertStatusOK(sc, "Remove mappings from childRoutine Foo.Bar to start")

    Set prevNS = $namespace

	New $namespace
    Set $namespace = "%SYS"
	Do $$$AssertTrue('##class(Config.MapRoutines).Exists(ns, parentRoutine), "Confirm parentRoutine Foo does not have mappings")
    Set parentMapping = ##class(%SYS.Namespace).GetRoutineDest(ns, parentRoutine)
    Do $$$AssertTrue('$find($zcvt(parentMapping, "L"), $zcvt(db, "L")), "system^directory where parentRoutine Foo is mapped to should not contain DB HSLIB yet")

    // Verify neither Foo nor Foo.Bar is mapped
    New $namespace
    Set $namespace = "%SYS"
    Do $$$AssertTrue('##class(Config.MapRoutines).Exists(ns, parentRoutine), "Confirm mapping for parentRoutine Foo does not exist") 
	Do $$$AssertTrue('##class(Config.MapRoutines).Exists(ns, childRoutine), "Confirm mapping for childRoutine Foo.Bar does not exist") 
 
    // Run the OnConfigureMappings method
    New $namespace
	Set $namespace = prevNS
    Set sc = testObjMAC.OnConfigureMappings(..Params)
    Do $$$AssertStatusOK(sc, "OnConfigureMappings should succeed")

    // Verify neither Foo nor Foo.Bar is mapped
    New $namespace
    Set $namespace = "%SYS"
    Do $$$AssertTrue('##class(Config.MapRoutines).Exists(ns, parentRoutine), "Confirm mapping for parentRoutine Foo does not exist")
	Do $$$AssertTrue('##class(Config.MapRoutines).Exists(ns, childRoutine), "Confirm mapping for childRoutine Foo.Bar does not exist")
}

Method TestNoParentMappingsLOC()
{
    // Initialize ..ResourceReference as LOC file
    Set ..ResourceReferenceClass.Name = "Foo.Bar.LOC"

    // Create a default processor setting for LOC
    Set ..Default.Class = "%IPM.ResourceProcessor.Default.LocalizedMessages"

    // Add the default setting to the module
    Do ..ResourceReferenceClass.Module.Defaults.Insert(..Default)

    Set testObjLOC = ##class(%IPM.ResourceProcessor.Default.LocalizedMessages).%New(..ResourceReferenceClass)
    Set ns = "USER"
    Set parentRoutine = "Foo"
    Set childRoutine = "Foo.Bar"
    Set db = "HSLIB"

    // Start fresh
    Set sc = ##class(%IPM.Utils.Module).RemoveRoutineMapping(ns, parentRoutine)
    Do $$$AssertStatusOK(sc, "Remove mappings from parentRoutine Foo to start")
    Set sc = ##class(%IPM.Utils.Module).RemoveRoutineMapping(ns, childRoutine)
    Do $$$AssertStatusOK(sc, "Remove mappings from childRoutine Foo.Bar to start")

    Set prevNS = $namespace

	New $namespace
    Set $namespace = "%SYS"
	Do $$$AssertTrue('##class(Config.MapRoutines).Exists(ns, parentRoutine), "Confirm parentRoutine Foo does not have mappings")
    Set parentMapping = ##class(%SYS.Namespace).GetRoutineDest(ns, parentRoutine)
    Do $$$AssertTrue('$find($zcvt(parentMapping, "L"), $zcvt(db, "L")), "system^directory where parentRoutine Foo is mapped to should not contain DB HSLIB yet")

    // Verify neither Foo nor Foo.Bar is mapped
    New $namespace
    Set $namespace = "%SYS"
    Do $$$AssertTrue('##class(Config.MapRoutines).Exists(ns, parentRoutine), "Confirm mapping for parentRoutine Foo does not exist") 
	Do $$$AssertTrue('##class(Config.MapRoutines).Exists(ns, childRoutine), "Confirm mapping for childRoutine Foo.Bar does not exist") 
 
    // Run the OnConfigureMappings method
    New $namespace
	Set $namespace = prevNS
    Set sc = testObjLOC.OnConfigureMappings(..Params)
    Do $$$AssertStatusOK(sc, "OnConfigureMappings should succeed")

    // Verify neither Foo nor Foo.Bar is mapped
    New $namespace
    Set $namespace = "%SYS"
    Do $$$AssertTrue('##class(Config.MapRoutines).Exists(ns, parentRoutine), "Confirm mapping for parentRoutine Foo does not exist")
	Do $$$AssertTrue('##class(Config.MapRoutines).Exists(ns, childRoutine), "Confirm mapping for childRoutine Foo.Bar does not exist")
}

Method TestNoParentMappingsPKG()
{
    // Initialize ..ResourceReference as PKG file
    Set ..ResourceReferenceClass.Name = "Foo.Bar.Mappings.PKG"

    // Create a default processor setting for PKG
    Set ..Default.Class = "%IPM.ResourceProcessor.Default.Package"

    // Add the default setting to the module
    Do ..ResourceReferenceClass.Module.Defaults.Insert(..Default)

    Set testObjPKG = ##class(%IPM.ResourceProcessor.Default.Package).%New(..ResourceReferenceClass)
    Set ns = "USER"
    Set parentPackage = "Foo"
    Set childPackage = "Foo.Bar"
    Set db = "HSLIB"

    // Start fresh
    Set sc = ##class(%IPM.Utils.Module).RemovePackageMapping(ns, parentPackage)
    Do $$$AssertStatusOK(sc, "Remove mappings from parentPackage Foo to start")
    Set sc = ##class(%IPM.Utils.Module).RemovePackageMapping(ns, childPackage)
    Do $$$AssertStatusOK(sc, "Remove mappings from childPackage Foo.Bar to start")

    Set prevNS = $namespace

	New $namespace
    Set $namespace = "%SYS"
	Do $$$AssertTrue('##class(Config.MapPackages).Exists(ns, parentPackage), "Confirm parentPackage Foo does not have mappings")
    Set parentMapping = ##class(%SYS.Namespace).GetPackageDest(ns, parentPackage)
    Do $$$AssertTrue('$find($zcvt(parentMapping, "L"), $zcvt(db, "L")), "system^directory where parentPackage Foo is mapped to should not contain DB HSLIB yet")

    // Verify neither Foo nor Foo.Bar is mapped
    Do $$$AssertTrue('##class(Config.MapPackages).Exists(ns, parentPackage), "Confirm mapping for parentPackage Foo does not exist") 
	Do $$$AssertTrue('##class(Config.MapPackages).Exists(ns, childPackage), "Confirm mapping for childPackage Foo.Bar does not exist") 

    // Run the OnConfigureMappings method
    New $namespace
	Set $namespace = prevNS
    Set sc = testObjPKG.OnConfigureMappings(..Params)
    Do $$$AssertStatusOK(sc, "OnConfigureMappings should succeed")

    // Verify new mappings were created for Foo.Bar
    New $namespace
    Set $namespace = "%SYS"

    // Verify neither Foo nor Foo.Bar is mapped
    Do $$$AssertTrue('##class(Config.MapPackages).Exists(ns, parentPackage), "Confirm mapping for parentPackage Foo does not exist") 
	Do $$$AssertTrue('##class(Config.MapPackages).Exists(ns, childPackage), "Confirm mapping for childPackage Foo.Bar does not exist")
}

Method TestNoParentMappingsCLS()
{
    // Initialize ..ResourceReference as CLS file
    Set ..ResourceReferenceClass.Name = "Foo.Bar.Mappings.CLS"

    // Create a default processor setting for CLS
    Set ..Default.Class = "%IPM.ResourceProcessor.Default.Class"

    // Add the default setting to the module
    Do ..ResourceReferenceClass.Module.Defaults.Insert(..Default)

    Set testObjCLS = ##class(%IPM.ResourceProcessor.Default.Class).%New(..ResourceReferenceClass)
    Set ns = "USER"
    Set parentPackage = "Foo"
    Set childPackage = "Foo.Bar"
    Set db = "HSLIB"

    // Start fresh
    Set sc = ##class(%IPM.Utils.Module).RemovePackageMapping(ns, parentPackage)
    Do $$$AssertStatusOK(sc, "Remove mappings from parentPackage Foo to start")
    Set sc = ##class(%IPM.Utils.Module).RemovePackageMapping(ns, childPackage)
    Do $$$AssertStatusOK(sc, "Remove mappings from childPackage Foo.Bar to start")

    Set prevNS = $namespace

	New $namespace
    Set $namespace = "%SYS"
	Do $$$AssertTrue('##class(Config.MapPackages).Exists(ns, parentPackage), "Confirm parentPackage Foo does not have mappings")
    Set parentMapping = ##class(%SYS.Namespace).GetPackageDest(ns, parentPackage)
    Do $$$AssertTrue('$find($zcvt(parentMapping, "L"), $zcvt(db, "L")), "system^directory where parentPackage Foo is mapped to should not contain DB HSLIB yet")

    // Verify neither Foo nor Foo.Bar is mapped
    Do $$$AssertTrue('##class(Config.MapPackages).Exists(ns, parentPackage), "Confirm mapping for parentPackage Foo does not exist") 
	Do $$$AssertTrue('##class(Config.MapPackages).Exists(ns, childPackage), "Confirm mapping for childPackage Foo.Bar does not exist") 

    // Run the OnConfigureMappings method
    New $namespace
	Set $namespace = prevNS
    Set sc = testObjCLS.OnConfigureMappings(..Params)
    Do $$$AssertStatusOK(sc, "OnConfigureMappings should succeed")

    // Verify new mappings were created for Foo.Bar
    New $namespace
    Set $namespace = "%SYS"

    // Verify neither Foo nor Foo.Bar is mapped
    Do $$$AssertTrue('##class(Config.MapPackages).Exists(ns, parentPackage), "Confirm mapping for parentPackage Foo does not exist") 
	Do $$$AssertTrue('##class(Config.MapPackages).Exists(ns, childPackage), "Confirm mapping for childPackage Foo.Bar does not exist")
}

Method TestMappingsParentMappingExistsCLS()
{
    // Initialize ..ResourceReference as CLS file
    Set ..ResourceReferenceClass.Name = "Foo.Bar.Mappings.CLS"

    // Create a default processor setting for CLS
    Set ..Default.Class = "%IPM.ResourceProcessor.Default.Class"

    // Add the default setting to the module
    Do ..ResourceReferenceClass.Module.Defaults.Insert(..Default)

    Set testObjCLS = ##class(%IPM.ResourceProcessor.Default.Class).%New(..ResourceReferenceClass)
    Set ns = "USER"
    Set parentPackage = "Foo"
    Set childPackage = "Foo.Bar"
    Set db = "HSLIB"

    // Start fresh
    Set sc = ##class(%IPM.Utils.Module).RemovePackageMapping(ns, parentPackage)
    Do $$$AssertStatusOK(sc, "Remove mappings from parentPackage Foo to start")
    Set sc = ##class(%IPM.Utils.Module).RemovePackageMapping(ns, childPackage)
    Do $$$AssertStatusOK(sc, "Remove mappings from childPackage Foo.Bar to start")

    Set prevNS = $namespace

	New $namespace
    Set $namespace = "%SYS"
	Do $$$AssertTrue('##class(Config.MapPackages).Exists(ns, parentPackage), "Confirm parentPackage Foo does not have mappings")
    Set parentMapping = ##class(%SYS.Namespace).GetPackageDest(ns, parentPackage)
    Do $$$AssertTrue('$find($zcvt(parentMapping, "L"), $zcvt(db, "L")), "system^directory where parentPackage Foo is mapped to should not contain DB HSLIB yet")

    // Create a package mapping for Foo
    New $namespace
	Set $namespace = prevNS
    Set sc = ##class(%IPM.Utils.Module).AddPackageMapping(ns, parentPackage, db)
    Do $$$AssertStatusOK(sc, "Create mapping for parentPackage Foo")

    // Verify Foo is mapped, but Foo.Bar is not
    Set parentMapping = ##class(%SYS.Namespace).GetPackageDest(ns, parentPackage)
    Do $$$AssertTrue($find($zcvt(parentMapping, "L"), $zcvt(db, "L")), "system^directory where parentPackage Foo is mapped to should contain DB HSLIB because of mapping")

    New $namespace
    Set $namespace = "%SYS"
    Do $$$AssertTrue(##class(Config.MapPackages).Exists(ns, parentPackage), "Confirm mapping for parentPackage Foo exists") 
	Do $$$AssertTrue('##class(Config.MapPackages).Exists(ns, childPackage), "Confirm mapping for childPackage Foo.Bar does not exist yet") 

    // Run the OnConfigureMappings method
    New $namespace
	Set $namespace = prevNS
    Set sc = testObjCLS.OnConfigureMappings(..Params)
    Do $$$AssertStatusOK(sc, "OnConfigureMappings should succeed")

    // Verify new mappings were created for Foo.Bar
    New $namespace
    Set $namespace = "%SYS"
    Do $$$AssertTrue(##class(Config.MapPackages).Exists(ns, childPackage), "childPackage Foo.Bar should have mappings now")
}

Method TestMappingsParentMappingExistsPKG()
{
    // Initialize ..ResourceReference as PKG file
    Set ..ResourceReferenceClass.Name = "Foo.Bar.PKG"

    // Create a default processor setting for PKG
    Set ..Default.Class = "%IPM.ResourceProcessor.Default.Package"

    // Add the default setting to the module
    Do ..ResourceReferenceClass.Module.Defaults.Insert(..Default)

    Set testObjPKG = ##class(%IPM.ResourceProcessor.Default.Package).%New(..ResourceReferenceClass)
    Set ns = "USER"
    Set parentPackage = "Foo"
    Set childPackage = "Foo.Bar"
    Set db = "HSLIB"

    // Start fresh
    Set sc = ##class(%IPM.Utils.Module).RemovePackageMapping(ns, parentPackage)
    Do $$$AssertStatusOK(sc, "Remove mappings from parentPackage Foo to start")
    Set sc = ##class(%IPM.Utils.Module).RemovePackageMapping(ns, childPackage)
    Do $$$AssertStatusOK(sc, "Remove mappings from childPackage Foo.Bar to start")

    Set prevNS = $namespace

	New $namespace
    Set $namespace = "%SYS"
	Do $$$AssertTrue('##class(Config.MapPackages).Exists(ns, parentPackage), "Confirm parentPackage Foo does not have mappings")
    Set parentMapping = ##class(%SYS.Namespace).GetPackageDest(ns, parentPackage)
    Do $$$AssertTrue('$find($zcvt(parentMapping, "L"), $zcvt(db, "L")), "system^directory where parentPackage Foo is mapped to should not contain DB HSLIB yet")

    // Create a package mapping for Foo
    New $namespace
	Set $namespace = prevNS
    Set sc = ##class(%IPM.Utils.Module).AddPackageMapping(ns, parentPackage, db)
    Do $$$AssertStatusOK(sc, "Create mapping for parentPackage Foo")

    // Verify Foo is mapped, but Foo.Bar is not
    Set parentMapping = ##class(%SYS.Namespace).GetPackageDest(ns, parentPackage)
    Do $$$AssertTrue($find($zcvt(parentMapping, "L"), $zcvt(db, "L")), "system^directory where parentPackage Foo is mapped to should contain DB HSLIB because of mapping")

    New $namespace
    Set $namespace = "%SYS"
    Do $$$AssertTrue(##class(Config.MapPackages).Exists(ns, parentPackage), "Confirm mapping for parentPackage Foo exists") 
	Do $$$AssertTrue('##class(Config.MapPackages).Exists(ns, childPackage), "Confirm mapping for childPackage Foo.Bar does not exist yet") 

    // Run the OnConfigureMappings method
    New $namespace
	Set $namespace = prevNS
    Set sc = testObjPKG.OnConfigureMappings(..Params)
    Do $$$AssertStatusOK(sc, "OnConfigureMappings should succeed")

    // Verify new mappings were created for Foo.Bar
    New $namespace
    Set $namespace = "%SYS"
    Do $$$AssertTrue(##class(Config.MapPackages).Exists(ns, childPackage), "childPackage Foo.Bar should have mappings now")
}

Method TestMappingsParentMappingExistsLOC()
{
    // Initialize ..ResourceReference as LOC file
    Set ..ResourceReferenceClass.Name = "Foo.Bar.LOC"

    // Create a default processor setting for LOC
    Set ..Default.Class = "%IPM.ResourceProcessor.Default.LocalizedMessages"

    // Add the default setting to the module
    Do ..ResourceReferenceClass.Module.Defaults.Insert(..Default)

    Set testObjLOC = ##class(%IPM.ResourceProcessor.Default.LocalizedMessages).%New(..ResourceReferenceClass)
    Set ns = "USER"
    Set parentRoutine = "Foo"
    Set childRoutine = "Foo.Bar"
    Set db = "HSLIB"

    // Start fresh
    Set sc = ##class(%IPM.Utils.Module).RemoveRoutineMapping(ns, parentRoutine)
    Do $$$AssertStatusOK(sc, "Remove mappings from parentRoutine Foo to start")
    Set sc = ##class(%IPM.Utils.Module).RemoveRoutineMapping(ns, childRoutine)
    Do $$$AssertStatusOK(sc, "Remove mappings from childRoutine Foo.Bar to start")

    Set prevNS = $namespace

	New $namespace
    Set $namespace = "%SYS"
	Do $$$AssertTrue('##class(Config.MapRoutines).Exists(ns, parentRoutine), "Confirm parentRoutine Foo does not have mappings")
    Set parentMapping = ##class(%SYS.Namespace).GetRoutineDest(ns, parentRoutine)
    Do $$$AssertTrue('$find($zcvt(parentMapping, "L"), $zcvt(db, "L")), "system^directory where parentRoutine Foo is mapped to should not contain DB HSLIB yet")

    // Create a routine mapping for Foo
    New $namespace
	Set $namespace = prevNS
    Set sc = ##class(%IPM.Utils.Module).AddRoutineMapping(ns, parentRoutine, , db)
    Do $$$AssertStatusOK(sc, "Create mapping for parentRoutine Foo")

    // Verify Foo is mapped, but Foo.Bar is not
    Set parentMapping = ##class(%SYS.Namespace).GetRoutineDest(ns, parentRoutine)
    Do $$$AssertTrue($find($zcvt(parentMapping, "L"), $zcvt(db, "L")), "system^directory where parentRoutine Foo is mapped to should contain DB HSLIB because of mapping")

    New $namespace
    Set $namespace = "%SYS"
    Do $$$AssertTrue(##class(Config.MapRoutines).Exists(ns, parentRoutine), "Confirm mapping for parentRoutine Foo exists") 
	Do $$$AssertTrue('##class(Config.MapRoutines).Exists(ns, childRoutine), "Confirm mapping for childRoutine Foo.Bar does not exist yet") 

    // Run the OnConfigureMappings method
    New $namespace
	Set $namespace = prevNS
    Set sc = testObjLOC.OnConfigureMappings(..Params)
    Do $$$AssertStatusOK(sc, "OnConfigureMappings should succeed")

    // Verify new mappings were created for Foo.Bar
    New $namespace
    Set $namespace = "%SYS"
    Do $$$AssertTrue(##class(Config.MapRoutines).Exists(ns, childRoutine), "childRoutine Foo.Bar should have mappings now")
}

Method TestMappingsParentMappingExistsMAC()
{
    // Initialize ..ResourceReference as MAC file
    Set ..ResourceReferenceClass.Name = "Foo.Bar.MAC"

    // Create a default processor setting for MAC
    Set ..Default.Class = "%IPM.ResourceProcessor.Default.Routine"

    // Add the default setting to the module
    Do ..ResourceReferenceClass.Module.Defaults.Insert(..Default)

    Set testObjMAC = ##class(%IPM.ResourceProcessor.Default.Routine).%New(..ResourceReferenceClass)
    Set ns = "USER"
    Set parentRoutine = "Foo"
    Set childRoutine = "Foo.Bar"
    Set db = "HSLIB"

    // Start fresh
    Set sc = ##class(%IPM.Utils.Module).RemoveRoutineMapping(ns, parentRoutine)
    Do $$$AssertStatusOK(sc, "Remove mappings from parentRoutine Foo to start")
    Set sc = ##class(%IPM.Utils.Module).RemoveRoutineMapping(ns, childRoutine)
    Do $$$AssertStatusOK(sc, "Remove mappings from childRoutine Foo.Bar to start")

    Set prevNS = $namespace

	New $namespace
    Set $namespace = "%SYS"
	Do $$$AssertTrue('##class(Config.MapRoutines).Exists(ns, parentRoutine), "Confirm parentRoutine Foo does not have mappings")
    Set parentMapping = ##class(%SYS.Namespace).GetRoutineDest(ns, parentRoutine)
    Do $$$AssertTrue('$find($zcvt(parentMapping, "L"), $zcvt(db, "L")), "system^directory where parentRoutine Foo is mapped to should not contain DB HSLIB yet")

    // Create a routine mapping for Foo
    New $namespace
	Set $namespace = prevNS
    Set sc = ##class(%IPM.Utils.Module).AddRoutineMapping(ns, parentRoutine, , db)
    Do $$$AssertStatusOK(sc, "Create mapping for parentRoutine Foo")

    // Verify Foo is mapped, but Foo.Bar is not
    Set parentMapping = ##class(%SYS.Namespace).GetRoutineDest(ns, parentRoutine)
    Do $$$AssertTrue($find($zcvt(parentMapping, "L"), $zcvt(db, "L")), "system^directory where parentRoutine Foo is mapped to should contain DB HSLIB because of mapping")

    New $namespace
    Set $namespace = "%SYS"
    Do $$$AssertTrue(##class(Config.MapRoutines).Exists(ns, parentRoutine), "Confirm mapping for parentRoutine Foo exists") 
	Do $$$AssertTrue('##class(Config.MapRoutines).Exists(ns, childRoutine), "Confirm mapping for childRoutine Foo.Bar does not exist yet") 

    // Run the OnConfigureMappings method
    New $namespace
	Set $namespace = prevNS
    Set sc = testObjMAC.OnConfigureMappings(..Params)
    Do $$$AssertStatusOK(sc, "OnConfigureMappings should succeed")

    // Verify new mappings were created for Foo.Bar
    New $namespace
    Set $namespace = "%SYS"
    Do $$$AssertTrue(##class(Config.MapRoutines).Exists(ns, childRoutine), "childRoutine Foo.Bar should have mappings now")
}

}
