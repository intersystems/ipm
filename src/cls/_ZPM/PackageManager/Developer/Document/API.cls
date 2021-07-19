Class %ZPM.PackageManager.Developer.Document.API Extends %ZPM.PackageManager.Developer.Document.AbstractDocument [ DependsOn = %ZPM.PackageManager.Developer.Document.APIStream ]
{

Projection RegisterExtension As %ZPM.PackageManager.Developer.Document.Projection(DocumentDescription = "API Documentation", DocumentExtension = "API", DocumentNew = 0, DocumentType = "xml", XMLNamespace = "http://www.intersystems.com/HealthShare/APIDoc");

Parameter EXTENSION = ".API";

Parameter INFOGLOBAL = "^%ZPM.Dev.APIDoc";

Parameter STREAMCLASS = "%ZPM.PackageManager.Developer.Document.APIStream";

Query ItemList() As %SQLQuery(ROWSPEC = "name:%String,modified:%TimeStamp") [ SqlProc ]
{
	select Name, LastModifiedTimestamp from %ZPM_PackageManager_Developer_Document.APIStream
}

/// Return true if this is generated and zero otherwise.
/// Default implementation opens instance to find the property value, it is much more efficient to override this to provide
/// a better implementation.
ClassMethod IsGenerated(name As %String) As %Boolean
{
	Quit 1
}

/// An API document is related to the module for which it was generated, and vice versa.
ClassMethod GetOther(Name As %String) As %String
{
	Set tOthers = ""
	Set tName = $Piece(Name,".",1,*-1)
	Set tExt = $Piece(Name,".",*)
	If (tExt = "API") {
		If ##class(%ZPM.PackageManager.Developer.Module).NameExists(tName) {
			Set tOthers = tName_".ZPM"
		}
	} ElseIf (tExt = "MODULE") {
		If ##class(%ZPM.PackageManager.Developer.Document.APIStream).NameExists(tName) {
			Set tOthers = tName_".API"
		}
	}
	Quit tOthers
}

}
