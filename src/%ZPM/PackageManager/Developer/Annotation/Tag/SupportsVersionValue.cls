/// abstract base class for tags with a semantic version value property; used only as a secondary superclass
Class %ZPM.PackageManager.Developer.Annotation.Tag.SupportsVersionValue [ Abstract, NoExtent ]
{

/// expected to be a module version (using semantic versioning). We do not use 
/// <class>%ZPM.PackageManager.Core.SemanticVersion</class> for this because it is incompatible with our 
/// desired XML output behavior using the XMLPROJECTION property parameter.  
Property VersionValue As %String(XMLNAME = "Version", XMLPROJECTION = "attribute");

Method ValidateAndAssignVersion(pVersionValue As %String = "", pContextObject As %ZPM.PackageManager.Developer.Annotation.CosEntity.CommentableEntity, pTagName As %String)
{
	if pVersionValue '= "" {
		// it would be nice to use this as the actual property type but it doesn't work with our XML output plans
		set tTestVal = ##class(%ZPM.PackageManager.Core.SemanticVersion).FromString(pVersionValue)
		set tSC = tTestVal.%ValidateObject()
		
		if $$$ISERR(tSC) {
			$$$ThrowOnError(pContextObject.StoreWarning("Invalid version expression on " _ pTagName _ " tag: " _ pVersionValue))
		}
		else {
			set ..VersionValue = pVersionValue
		}
	}
	else {
		set tWarningMsg = pTagName _ " tag with no version info"
		set tSC = pContextObject.StoreWarning(tWarningMsg)
		$$$ThrowOnError(tSC)
	}
}

Method HandleVersionContent(ByRef pCommentBlock As %Library.RawString, pContextObject As %ZPM.PackageManager.Developer.Annotation.CosEntity.CommentableEntity, pTagName As %String) [ Private ]
{
	set tLineContent = ##class(%ZPM.PackageManager.Developer.Annotation.Utils).PopCommentLine(.pCommentBlock)
	set tLineContent = $zstrip(tLineContent, "*W")
	
	do ..ValidateAndAssignVersion(tLineContent, pContextObject, pTagName)
}

}
