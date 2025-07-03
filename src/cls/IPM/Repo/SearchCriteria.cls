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
    if $isobject(%value) {
        set i%Keywords = %value
    } else {
        do ..Keywords.Clear()
        if '$listvalid(%value) {
            set %value = $listfromstring(%value," ")
        }
        set tPointer = 0
        while $listnext(%value,tPointer,tValue) {
            if ($get(tValue) '= "") {
                do ..Keywords.Insert(tValue)
            }
        }
    }
}

}
