Class %ZPM.PackageManager.Core.SemanticVersion Extends (%SerialObject, %XML.Adaptor) [ StorageStrategy = "" ]
{

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Property Major As %Integer(MINVAL = 0) [ Required ];

Property Minor As %Integer(MINVAL = 0) [ Required ];

Property Patch As %Integer(MINVAL = 0) [ Required ];

Property Prerelease As RegExString(MAXLEN = 100, REGEX = "([0-9A-Za-z-])+(\.([0-9A-Za-z-])+)*");

Property Build As RegExString(MAXLEN = 100, REGEX = "([0-9A-Za-z-])+(\.([0-9A-Za-z-])+)*");

Method ToString() As %String [ CodeMode = expression ]
{
..Major_"."_..Minor_"."_..Patch_$Case(..Prerelease,"":"",:"-"_..Prerelease)_$Case(..Build,"":"",:"+"_..Build)
}

ClassMethod FromString(pString As %String) As %ZPM.PackageManager.Core.SemanticVersion
{
	Set tVer = ..%New()
	Set tVer.Major = $Piece(pString,".",1)
	Set tVer.Minor = $Piece(pString,".",2)
	Set tVer.Patch = $Piece($Piece($Piece(pString,".",3),"-"),"+")
	Set tVer.Prerelease = $Piece($Piece($Piece(pString,".",3,*),"-",2,*),"+")
	Set tVer.Build = $Piece(pString,"+",2)
	Quit tVer
}

ClassMethod FromListBuild(pList As %List) As %ZPM.PackageManager.Core.SemanticVersion
{
	Set tVer = ..%New()
	Do tVer.%SetSerial(pList)
	Quit tVer
}

ClassMethod IsValid(pString As %String) As %Status
{
	Set tVer = ..FromString(pString)
	Quit tVer.%ValidateObject()
}

/// This callback method is invoked by the <METHOD>%ValidateObject</METHOD> method to 
/// provide notification that the current object is being validated.
/// 
/// <P>If this method returns an error then <METHOD>%ValidateObject</METHOD> will fail.
Method %OnValidateObject() As %Status [ Private, ServerOnly = 1 ]
{
	If (..Major '= +..Major) {
		Quit $$$ERROR($$$GeneralError,$$$FormatText("Major version (%1) must be a positive integer without trailing zeros.",..Major))
	}
	If (..Minor '= +..Minor) {
		Quit $$$ERROR($$$GeneralError,$$$FormatText("Minor version (%1) must be a positive integer without trailing zeros.",..Minor))
	}
	If (..Patch '= +..Patch) {
		Quit $$$ERROR($$$GeneralError,$$$FormatText("Patch version (%1) must be a positive integer without trailing zeros.",..Patch))
	}
	Set tSC = $$$OK
	Set tPointer = 0
	Set tPreIdentifiers = $ListFromString(..Prerelease,".")
	While $ListNext(tPreIdentifiers,tPointer,tIdentifier) {
		If (+tIdentifier > 0) && (+tIdentifier '= tIdentifier) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Numeric identifier (%1) in version's prerelease (%2) cannot contain leading zeros.",tIdentifier,..Prerelease))
		}
	}
	Quit tSC
}

Method IsSnapshot() As %Boolean
{
	Quit ($ZConvert(..Build,"L") = "snapshot")
}

/// Returns 1 if this version's number indicates that it supports in <var>pVersion</var>.
/// That is, it has the same major and minor version as <var>pVersion</var>.
Method IsCompatibleWith(pVersion As %ZPM.PackageManager.Core.SemanticVersion) As %Boolean [ CodeMode = expression ]
{
(pVersion.Major = ..Major) && (pVersion.Minor = ..Minor)
}

/// Returns 1 if this version's number indicates that it will also support everything in <var>pVersion</var>.
/// That is, it has the same major and a later or equal minor version to <var>pVersion</var>.
Method IsBackwardCompatibleWith(pVersion As %ZPM.PackageManager.Core.SemanticVersion) As %Boolean [ CodeMode = expression ]
{
(pVersion.Major = ..Major) && (pVersion.Minor <= ..Minor)
}

/// Returns 1 if this version is a later version than <var>pVersion</var>.
/// TODO: Account for prerelease?
Method Follows(pVersion As %ZPM.PackageManager.Core.SemanticVersion) As %Boolean [ CodeMode = expression ]
{
(..Major > pVersion.Major) ||
	((..Major = pVersion.Major) && (..Minor > pVersion.Minor)) ||
	((..Major = pVersion.Major) && (..Minor = pVersion.Minor) && (..Patch > pVersion.Patch))
}

Method Satisfies(pExpression As %ZPM.PackageManager.Core.SemanticVersionExpression) As %Boolean
{
	Quit pExpression.IsSatisfiedBy($this)
}

Storage Default
{
<Data name="SemanticVersionState">
<Value name="1">
<Value>Major</Value>
</Value>
<Value name="2">
<Value>Minor</Value>
</Value>
<Value name="3">
<Value>Patch</Value>
</Value>
<Value name="4">
<Value>Prerelease</Value>
</Value>
<Value name="5">
<Value>Build</Value>
</Value>
</Data>
<State>SemanticVersionState</State>
<StreamLocation>^ZPM.PackageManager9CFF.SemanticVerF1F5S</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
