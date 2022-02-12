/// Some text up here.
/// @SampleTestClass
Class Test.PM.Unit.Annotations Extends %UnitTest.TestCase
{

/// @TestMethod
Method TestAnnotationRetrieval()
{
	#; #dim tAnnotation As %IPM.PackageManager.Developer.Annotation
	
	#; Do $$$AssertStatusOK(##class(%IPM.PackageManager.Developer.Annotation.Utils).ExtractAnnotations($classname(),.tList),"Extracted annotations from current class.")
	
	#; Set tExpected($ListBuild("Test.PM.Unit.Annotations","","","SampleTestClass")) = ""
	#; Set tExpected($ListBuild("Test.PM.Unit.Annotations","Method","TestAnnotationRetrieval","TestMethod")) = ""
	#; Set tExpected($ListBuild("Test.PM.Unit.Annotations","Method","Something","Deprecated")) = ""
	#; Set tExpected($ListBuild("Test.PM.Unit.Annotations","Query","MyQuery","Query")) = ""
	#; Set tExpected($ListBuild("Test.PM.Unit.Annotations","Property","AFunProperty","Fun")) = ""
	#; Set tExpected($ListBuild("Test.PM.Unit.Annotations","XData","MyXData","OtherThing")) = "SomeData"
	
	#; For i=1:1:tList.Count() {
	#; 	Set tAnnotation = tList.GetAt(i)
	#; 	Set tKey = $ListBuild(tAnnotation.Classname,tAnnotation.MemberType,tAnnotation.MemberName,tAnnotation.Tag)
	#; 	If $$$AssertEquals($Data(tExpected(tKey),tValue),1,"Expected annotation found: "_$LTS(tKey,"/")) {
	#; 		Do $$$AssertEquals(tValue,tAnnotation.Value,"Annotation had expected value '"_tValue_"'")
	#; 	}
	#; 	Kill tExpected(tKey)
	#; }
		
	#; Do $$$AssertEquals($Data(tExpected),0,"All expected things were present.")
}

/// @Deprecated
ClassMethod Something()
{
}

/// @Query
Query MyQuery() As %SQLQuery
{
	select 1
}

/// @Fun
/// No annotations here.
Property AFunProperty As %String;

/// No annotations here.
Property ABoringProperty As %String;

/// @OtherThing("SomeData")
XData MyXData
{
}

}
