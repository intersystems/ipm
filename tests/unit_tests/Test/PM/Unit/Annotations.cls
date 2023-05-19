/// Some text up here.
/// @SampleTestClass
Class Test.PM.Unit.Annotations Extends %UnitTest.TestCase
{

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
