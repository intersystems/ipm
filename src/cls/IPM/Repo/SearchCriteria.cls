Class %IPM.Repo.SearchCriteria Extends (%RegisteredObject, %XML.Adaptor)
{

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Parameter XMLIGNOREINVALIDTAG = 1;

Parameter XMLIGNOREINVALIDATTRIBUTE = 1;

Property Name As %String;

Property VersionExpression As %String;

Property Registry As %String;

Property IncludePrerelease As %Boolean;

Property IncludeSnapshots As %Boolean;

Property Keywords As list Of %String;

Property AllVersions As %Boolean;

Method KeywordsSet(%value) As %Status
{
	If $IsObject(%value) {
		Set i%Keywords = %value
	} Else {
		Do ..Keywords.Clear()
		If '$ListValid(%value) {
			Set %value = $ListFromString(%value," ")
		}
		Set tPointer = 0
		While $ListNext(%value,tPointer,tValue) {
			If ($Get(tValue) '= "") {
				Do ..Keywords.Insert(tValue)
			}
		}
	}
}

}
