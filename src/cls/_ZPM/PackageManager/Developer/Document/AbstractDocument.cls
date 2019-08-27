Class %ZPM.PackageManager.Developer.Document.AbstractDocument Extends %Studio.AbstractDocument [ Abstract, Owner = {%Developer} ]
{

Parameter EXTENSION [ Abstract ];

Parameter INFOGLOBAL [ Abstract ];

/// CompileDocument is called when the document is to be compiled
/// It has already called the source control hooks at this point
Method CompileDocument(ByRef qstruct As %String) As %Status
{
	// SuspendErrorCount allows things this calls to return error statuses without resulting in:
	// ERROR #6084: Unknown errors detected, but no error code reported
	// There may be cases where error statuses are not exceptional cases and are handled properly
	// without needing to return the error status.
	$$$SuspendErrorCount
	
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		Set tSC = ..%ValidateName(..Name)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ..OnCompileDocument(.qstruct)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) { TROLLBACK 1 }
	
	If $Get(qstruct("displaylog")) && $$$ISERR(tSC) {
		Write !,$System.Status.GetErrorText(tSC)
	}
	Quit tSC
}

/// Save the module definition document.
Method Save() As %Status
{
	Set tName = ..Name
	Set tSC = ..ImportStream(.tName,..Code)
	If $$$ISERR(tSC) {
		Quit tSC
	}
	Set ..Name = tName
	Quit ..Load()
}

/// Export this document to the current device in XML format
Method ExportToXML(flags As %String) As %Status
{
	Set ..Code.LineTerminator=$c(10)
	Do ..Code.Rewind()
	Do ..Code.ReadLine()  // omit xml header
	While '(..Code.AtEnd) {
		Write ..Code.Read(16000)
	}
	Quit $$$OK
}

/// Import from the stream in XML format
Method ImportFromXML(stream As %RegisteredObject, flags As %String) As %Status
{
	Do ..Code.Clear()
	Do ..Code.WriteLine("<?xml version=""1.0""?>") //add XML header
	Do ..Code.CopyFrom(stream)
	Quit $$$OK
}

/// Return the compile time of routine 'name' in %TimeStamp format. The format should be $zdatetime($horolog,3),
/// or "" if the routine does not exist.
ClassMethod CompileTime(name As %String) As %TimeStamp
{
	If '..%ValidateName(name) {
		Quit ""
	}
	
	Quit $Get(@..#INFOGLOBAL@($Piece(name,".",1,*-1),"compile"),0)
}

ClassMethod %ValidateName(name As %String) As %Status
{
	Set tSC = $$$OK
	If (("."_$ZConvert($Piece(name,".",*),"U")) '= ..#EXTENSION) {
		Set tSC = $$$ERROR($$$GeneralError,"Invalid name '"_name_"' - doesn't match "_("."_$ZConvert($Piece(name,".",*),"L")))
	}
	Quit tSC
}

/// Subclasses must override
Query ItemList() As %SQLQuery(ROWSPEC = "name:%String,modified:%TimeStamp") [ SqlProc ]
{
	select top 0 null,null
}

Query List(Directory As %String, Flat As %Boolean, System As %Boolean) As %Query(ROWSPEC = "name:%String,modified:%TimeStamp,size:%Integer,directory:%String") [ SqlProc ]
{
}

ClassMethod ListExecute(ByRef qHandle As %Binary, Directory As %String, Flat As %Boolean, System As %Boolean) As %Status
{
	If (Directory '= "") Set qHandle = "" Quit $$$OK
	Set tSC = $$$OK
	Set tStmt = ##class(%SQL.Statement).%New()
	Set tSC = tStmt.%PrepareClassQuery($classname(),"ItemList")
	If $$$ISERR(tSC) {
		Quit tSC
	}
	Set qHandle = tStmt.%Execute()
	If (qHandle.%SQLCODE < 0) {
		Set tSC = $$$ERROR($$$SQLCode,qHandle.%SQLCODE,qHandle.%Message)
	}
	If $$$ISERR(tSC) {
		Quit tSC
	}
	If 'qHandle.%Next(.tSC) {
		Set qHandle = ""
	}
	Quit tSC
}

ClassMethod ListFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = ListExecute ]
{
	Quit:qHandle="" $$$OK
	Set Row = $ListBuild(qHandle.%GetData(1)_..#EXTENSION,qHandle.%GetData(2),1000,"")
	Set AtEnd = 'qHandle.%Next(.tSC)
	Quit tSC
}

ClassMethod ListClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = ListExecute ]
{
	Quit $$$OK
}

}
