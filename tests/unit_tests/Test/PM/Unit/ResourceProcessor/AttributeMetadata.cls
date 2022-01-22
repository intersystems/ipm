Class Test.PM.Unit.ResourceProcessor.AttributeMetadata Extends (%UnitTest.TestCase, %ZPM.PackageManager.Developer.Processor.Abstract)
{

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "MinText,ListControl,Answer";

/// Text
Property MinText As %String(MINLEN = 5) [ InitialExpression = {$classname()}, Required ];

Method TestMinText()
{
	If '..UtilGetRow("MinText",.tRow) {
		Quit
	}
	Do $$$AssertEquals(tRow.%Get("Type"),"string")
	Do $$$AssertEquals(tRow.%Get("Description"),"Text")
	Do $$$AssertEquals(tRow.%Get("Default"),$classname())
	Do $$$AssertEquals(tRow.%Get("Required"),1)
	Do $$$AssertEquals(tRow.%Get("VALUELIST"),"")
	Do $$$AssertEquals(tRow.%Get("DISPLAYLIST"),"")
	Do $$$AssertEquals(tRow.%Get("MINLEN"),5)
	Do $$$AssertEquals(tRow.%Get("MAXLEN"),50)
	Do $$$AssertEquals(tRow.%Get("MINVAL"),"")
	Do $$$AssertEquals(tRow.%Get("MAXVAL"),"")
}

/// List
Property ListControl As %String(ATTRIBUTEREQUIRED = 0, DISPLAYLIST = ",A,B,C", MAXLEN = 40, VALUELIST = ",1,2,3") [ Required ];

Method TestListControl()
{
	If '..UtilGetRow("ListControl",.tRow) {
		Quit
	}
	Do $$$AssertEquals(tRow.%Get("Type"),"string")
	Do $$$AssertEquals(tRow.%Get("Description"),"List")
	Do $$$AssertEquals(tRow.%Get("Default"),"")
	Do $$$AssertEquals(tRow.%Get("Required"),0)
	Do $$$AssertEquals(tRow.%Get("VALUELIST"),",1,2,3")
	Do $$$AssertEquals(tRow.%Get("DISPLAYLIST"),",A,B,C")
	Do $$$AssertEquals(tRow.%Get("MINLEN"),"")
	Do $$$AssertEquals(tRow.%Get("MAXLEN"),40)
	Do $$$AssertEquals(tRow.%Get("MINVAL"),"")
	Do $$$AssertEquals(tRow.%Get("MAXVAL"),"")
}

/// 42
Property Answer As %Integer(ATTRIBUTEREQUIRED = 1, MAXVAL = 43, MINVAL = 41);

Method TestAnswer()
{
	If '..UtilGetRow("Answer",.tRow) {
		Quit
	}
	Do $$$AssertEquals(tRow.%Get("Type"),"long")
	Do $$$AssertEquals(tRow.%Get("Description"),42)
	Do $$$AssertEquals(tRow.%Get("Default"),"")
	Do $$$AssertEquals(tRow.%Get("Required"),1)
	Do $$$AssertEquals(tRow.%Get("VALUELIST"),"")
	Do $$$AssertEquals(tRow.%Get("DISPLAYLIST"),"")
	Do $$$AssertEquals(tRow.%Get("MINLEN"),"")
	Do $$$AssertEquals(tRow.%Get("MAXLEN"),"")
	Do $$$AssertEquals(tRow.%Get("MINVAL"),41)
	Do $$$AssertEquals(tRow.%Get("MAXVAL"),43)
}

Method UtilGetRow(pName As %String, Output pResult As %SQL.StatementResult) As %Boolean
{
	Set pResult = $$$NULLOREF
	Try {
		Set pResult = ##class(%SQL.Statement).%ExecDirect(,"call %ZPM_PackageManager_Developer.API_ListProcessorAttributes(?)",$classname())
		If (pResult.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(pResult.%SQLCODE,pResult.%Message)
		}
		While pResult.%Next(.tSC) {
			If (pResult.%Get("Name") = pName) {
				Return 1
			}
		}
		$$$ThrowOnError(tSC)
		$$$ThrowStatus($$$ERROR($$$GeneralError,"Attribute metadata not found for "_pName))
	} Catch e {
		Set pResult = $$$NULLOREF
		Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
	}
	Quit 0
}

}
