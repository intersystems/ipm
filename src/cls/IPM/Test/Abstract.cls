/// The class serves as the base class for all the unit test result formatting.
Class %IPM.Test.Abstract Extends %RegisteredObject
{

ClassMethod ToFile(
	pFileName As %String,
	pCaseStatus As %String = "",
	pTestIndex As %Integer = {$order(^UnitTest.Result(""),-1)}) As %Status [ Abstract ]
{
}

ClassMethod OutputToDevice(
	pTestIndex As %Integer = {$order(^UnitTest.Result(""),-1)},
	pTestStatus As %String = "") [ Abstract ]
{
}

Query FilteredTestResults(
	pInstance As %Integer,
	pTestStatus) As %SQLQuery(ROWSPEC = "TotalCounts:%Integer,namespace:%String,duration:%String,testDateTime:%String,suiteName:%String,testcaseName:%String,methodName:%String,testMethod:%String,assertAction:%String,assertCounter:%Integer,assertDescription:%String,assertLocation:%String", SELECTMODE = "DISPLAY")
{
SELECT
count(*) as TotalCounts,
tinstance.Namespace AS namespace,
tinstance.Duration AS duration,
tinstance.DateTime AS testDateTime,
tsuite.Name AS suiteName,
tcase.Name AS testcaseName,
tmethod.Name AS methodName,
tassert.TestMethod AS testMethod,
tassert.Action AS assertAction,
tassert.Counter AS assertCounter,
tassert.Description AS assertDescription,
tassert.Location AS assertLocation
FROM
%UnitTest_Result.TestInstance tinstance
JOIN %UnitTest_Result.TestSuite tsuite ON tsuite.TestInstance=tinstance.ID
JOIN %UnitTest_Result.TestCase tcase  ON tcase.TestSuite=tsuite.ID
JOIN %UnitTest_Result.TestMethod tmethod ON tmethod.TestCase=tcase.ID
JOIN %UnitTest_Result.TestAssert tassert ON tassert.TestMethod=tmethod.ID
WHERE tinstance.ID=:pInstance AND tassert.Status=:pTestStatus
}

Query GetAllTestResults(pInstance As %Integer) As %SQLQuery(ROWSPEC = "TotalCounts:%String,namespace:%String,duration:%String,testDateTime:%String,suiteName:%String,testcaseName:%String,methodName:%String,testMethod:%String,assertAction:%String,assertCounter:%Integer,assertDescription:%String,assertLocation:%String", SELECTMODE = "DISPLAY")
{
SELECT
count(*) as TotalCounts,
tinstance.Namespace AS namespace,
tinstance.Duration AS duration,
tinstance.DateTime AS testDateTime,
tsuite.Name AS suiteName,
tcase.Name AS testcaseName,
tmethod.Name AS methodName,
tassert.TestMethod AS testMethod,
tassert.Action AS assertAction,
tassert.Counter AS assertCounter,
tassert.Description AS assertDescription,
tassert.Location AS assertLocation
FROM
%UnitTest_Result.TestInstance tinstance
JOIN %UnitTest_Result.TestSuite tsuite ON tsuite.TestInstance=tinstance.ID
JOIN %UnitTest_Result.TestCase tcase  ON tcase.TestSuite=tsuite.ID
JOIN %UnitTest_Result.TestMethod tmethod ON tmethod.TestCase=tcase.ID
JOIN %UnitTest_Result.TestAssert tassert ON tassert.TestMethod=tmethod.ID
WHERE tinstance.ID=:pInstance
}

}
