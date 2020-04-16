/// Unit tests for the "zpm" command line (although not using the "zpm" command itself)
Class Test.PM.Unit.CLI Extends %UnitTest.TestCase
{

Method TestParser()
{
	
	// Test cases
	Set tCommands($i(tCommands)) = "help -v repo"
	Set tResults(tCommands)="help"
	Set tResults(tCommands,"modifiers","verbose")=""
	Set tResults(tCommands,"parameters","command")="repo"
	
	Set tCommands($i(tCommands)) = "repo -name UTFILE -fs -path ""C:\\Program Files\\stuff\\"" -depth 42"
	Set tResults(tCommands)="repo"
	Set tResults(tCommands,"modifiers","depth")=42
	Set tResults(tCommands,"modifiers","filesystem")=""
	Set tResults(tCommands,"modifiers","name")="UTFILE"
	Set tResults(tCommands,"modifiers","path")="C:\Program Files\stuff\"
	
	Set tCommands($i(tCommands)) = "ZPM activate -dev -DUIFW.force=1"
	// Old behavior:
	/*
	Set tResults(tCommands)="module-action"
	Set tResults(tCommands,"parameters","actions")="activate -dev -DUIFW.force=1"
	Set tResults(tCommands,"parameters","module")="ZPM"
	*/
	Set tResults(tCommands)="module-action"
	Set tResults(tCommands,"parameters","actions")="activate"
	Set tResults(tCommands,"parameters","module")="ZPM"
	Set tResults(tCommands,"data","DeveloperMode")=1
	Set tResults(tCommands,"data","UIFW","force")=1
	
	Set tCommands($i(tCommands)) = "ZPM clean install -dev -DUIFW.force=1 -DSomething=""quoted\"" value"""
	// Old behavior:
	/*
	Set tResults(tCommands)="module-action"
	Set tResults(tCommands,"parameters","actions")="clean install -dev -DUIFW.force=1 -DSomething=""quoted"" value"""
	Set tResults(tCommands,"parameters","module")="ZPM"
	*/
	Set tResults(tCommands)="module-action"
	Set tResults(tCommands,"parameters","actions")="clean install"
	Set tResults(tCommands,"parameters","module")="ZPM"
	Set tResults(tCommands,"data","DeveloperMode")=1
	Set tResults(tCommands,"data","UIFW","force")=1
	Set tResults(tCommands,"data","zpm","Something")="quoted"" value"
	
	Set tCommands($i(tCommands)) = "module-action isc-dev publish"
	Set tResults(tCommands)="module-action"
	Set tResults(tCommands,"parameters","actions")="publish"
	Set tResults(tCommands,"parameters","module")="isc-dev"
	
	Set tCommands($i(tCommands)) = "list-installed -t"
	Set tResults(tCommands)="list-installed"
	Set tResults(tCommands,"modifiers","tree")=""
	
	Set tCommands($i(tCommands)) = "install SomeModule"
	Set tResults(tCommands)="install"
	Set tResults(tCommands,"parameters","module")="SomeModule"
	
	Set tCommands($i(tCommands)) = "install SomeModule 0.0.1-prerelease.42+snapshot"
	Set tResults(tCommands)="install"
	Set tResults(tCommands,"parameters","module")="SomeModule"
	Set tResults(tCommands,"parameters","version")="0.0.1-prerelease.42+snapshot"
	
	/*
	Set tCommands($i(tCommands)) = 
	Set tResults(tCommands)=
	Set tResults(tCommands,
	*/
	
	// Verify output matches
	For i=1:1:tCommands {
		Kill tParsedCommandInfo,tExpectedCommandInfo
		Do $$$AssertStatusOK(##class(%ZPM.PackageManager).%ParseCommandInput(tCommands(i),.tParsedCommandInfo))
		Merge tExpectedCommandInfo = tResults(i)
		If '$$$AssertTrue(..CompareArrays(.tParsedCommandInfo,.tExpectedCommandInfo,.tMessage),"Parsed correctly: "_tCommands(i)) {
			Do $$$LogMessage(tMessage)
			Write !,"Expected:",! zw tExpectedCommandInfo
			Write !,"Actual:",! zw tParsedCommandInfo
		}
	}
}

Method TestRepository()
{
	// Cleanup
	Do ..RunCommand("repo -delete-all")
	Do ..RunCommand("repo -list")
	
	// Create repositories
	Set tDir = ##class(%File).ManagerDirectory()
	Do ##class(%Studio.General).GetWebServerPort(.tPort)
	Set tUrl = "https://pm.community.intersystems.com/"
	Do ..AssertNoException("repo -name UTFILE -fs -path "_tDir_" -depth 1")
	Do ..AssertNoException("repo -n UTSERVER -r -url "_tUrl)
	Do ..RunCommand("repo -list")
	
	// Update repositories
	Do ..AssertNoException("repo -n UTFILE -fs -snapshots 0")
	Do ..AssertNoException("repo -name UTSERVER -r -prereleases 0")
	Do ..RunCommand("repo -list")
	
	// Cleanup (again)
	Do ..RunCommand("repo -n UTFILE -delete")
	Do ..RunCommand("repo -name UTSERVER -delete")
}

Method RunCommand(pCommand As %String)
{
	Do ##class(%ZPM.PackageManager).Shell(pCommand)
	Do $$$LogMessage("Run command: "_pCommand)
}

Method AssertNoException(pCommand As %String)
{
	Do ##class(%ZPM.PackageManager).ShellInternal(pCommand,.tException)
	If '$$$AssertEquals(tException,"","No exceptions occurred running command: "_pCommand) {
		Do $$$LogMessage(tException.DisplayString())
	}
}

/// Returns true if arrays <var>first</var> and <var>second</var> have all the same subscripts and all
/// the same values at those subscripts. <br />
/// If <var>first</var> and <var>second</var> both happen to be either undefined or unsubscripted variables,
/// returns true if they're both undefined or have the same value.<br />
/// <var>pMessage</var> has details of the first difference found, if any.
/// See https://community.intersystems.com/post/best-way-compare-two-arrays-equality-same-subscripts-and-values
Method CompareArrays(ByRef first, ByRef second, Output pMessage) As %Boolean [ PublicList = (tRef1, tRef2, first, second) ]
{
    New tRef1,tRef2
    Set pMessage = ""
    Set tEqual = 1
    Set tRef1 = "first"
    Set tRef2 = "second"
    While (tRef1 '= "") || (tRef2 '= "") {
        #; See if the subscript is the same for both arrays.
        #; If not, one of them has a subscript the other doesn't, and they're not equal.
        If ($Piece(tRef1,"first",2) '= $Piece(tRef2,"second",2)) {
            Set tEqual = 0
            Set pMessage = "Different subscripts encountered by $Query: "_
                $Case(tRef1,"":"<end>",:tRef1)_"; "_$Case(tRef2,"":"<end>",:tRef2)
            Quit
        }
        
        Kill tRef1Value,tRef2Value
        Set tRef1Data = $Data(@tRef1,tRef1Value)
        Set tRef2Data = $Data(@tRef2,tRef2Value)
        #; See if the $Data values are the same for the two.
        #; This is really only useful to detect if one of the arrays is undefined on the first pass;
        #; $Query only returns subscripts with data.
        #; This will catch only one being defined, or one being an array and
        #; ​the other being a regular variable.
        If (tRef1Data '= tRef2Data) {
            Set tEqual = 0
            Set pMessage = "$Data("_tRef1_")="_tRef1Data_"; $Data("_tRef2_")="_tRef2Data
            Quit
        } ElseIf (tRef1Data#2) && (tRef2Data#2) {
            #; See if the value at the subscript is the same for both arrays.
            #; If not, they're not equal.
            If (tRef1Value '= tRef2Value) {
                Set tEqual = 0
                Set pMessage = tRef1_"="_@tRef1_"; "_tRef2_"="_@tRef2
                Quit
            }
        }
        
        Set tRef1 = $Query(@tRef1)
        Set tRef2 = $Query(@tRef2)
    }
    Quit tEqual
}

}
