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
..Major 
_ "." _ ..Minor 
_ $Case(..Patch, "": "", : "." _ ..Patch) 
_ $Case(..Prerelease, "": "", : "-" _ ..Prerelease) 
_ $Case(..Build, "": "", : "+" _ ..Build)
}

ClassMethod FromString(pString As %String) As %ZPM.PackageManager.Core.SemanticVersion
{
  Set tVer = ..%New()
  Set tVer.Major = $Piece($Piece($Piece(pString,".",1),"-"),"+")
  Set tVer.Minor = 0
  Set tVer.Patch = 0
  If ($Length(pString, ".") > 3) {
    Set tVer.Patch = $Piece(pString,".",3)
    Set tVer.Build = $Piece(pString,".",4)
  }
  If ($Length(pString, ".") > 2) {
    Set tVer.Patch = +$Piece($Piece($Piece(pString,".",3),"-"),"+")
  }
  If ($Length(pString, ".") > 1) {
    Set tVer.Minor = +$Piece($Piece($Piece(pString,".",2),"-"),"+")
    Set tVer.Patch = +$Piece($Piece($Piece(pString,".",3),"-"),"+")
  }
  Set tVer.Prerelease = $Piece($Piece($Piece(pString,".",*),"-",2,*),"+")
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

/// Returns 1 if this version is a later version than <var>pVersion</var>. <br />
/// From <a href="http://semver.org/spec/v2.0.0.html#spec-item-11">the SemVer 2.0.0 specification</a>: <br />
/// 1.0.0-alpha &lt; 1.0.0-alpha.1 &lt; 1.0.0-alpha.beta &lt; 1.0.0-beta &lt; 1.0.0-beta.2 &lt; 1.0.0-beta.11 &lt; 1.0.0-rc.1 &lt; 1.0.0
/// Also, two prerelease versions with mismatched major/minor/patch should *not* follow each other; see: <a href="https://github.com/npm/node-semver#prerelease-tags">node-semver</a>
Method Follows(pVersion As %ZPM.PackageManager.Core.SemanticVersion) As %Boolean
{
	Set tFollows = (..Major > pVersion.Major) ||
		((..Major = pVersion.Major) && (..Minor > pVersion.Minor)) ||
		((..Major = pVersion.Major) && (..Minor = pVersion.Minor) && (..Patch > pVersion.Patch))
	
	// Handle prereleases - messy!!
	Set tEquals = (..Major = pVersion.Major) && (..Minor = pVersion.Minor) && (..Patch = pVersion.Patch)
	If (..Prerelease '= "") || (pVersion.Prerelease '= "") {
		If 'tEquals {
			If (..Prerelease '= "") && (pVersion.Prerelease '= "") {
				Quit 0
			} Else {
				Quit tFollows
			}
		} ElseIf (..Prerelease = pVersion.Prerelease) {
			// They are equal; neither comes before the other, unless pVersion is a snapshot version and this version is not
			Quit (pVersion.IsSnapshot() && '..IsSnapshot())
		} ElseIf (..Prerelease '= "") && (pVersion.Prerelease = "") {
			// This version has a prerelease, so it is earlier than pVersion.
			Quit 0
		} ElseIf (..Prerelease = "") && (pVersion.Prerelease '= "") {
			// We are comparing equal versions where the earlier has a prerelease.
			Quit 1
		} Else{
			// Both have a prerelease, and they're different.
			// Compare dot-separated parts of the prerelease.
			Set tFollows = 1
			Set tThisParts = $ListFromString(..Prerelease,".")
			Set tOtherParts = $ListFromString(pVersion.Prerelease,".")
			
			Set tOtherHasData = 1
			Set tThisPointer = 0
			Set tOtherPointer = 0
			While $ListNext(tThisParts,tThisPointer,tThisPart) {
				Set tOtherHasData = $ListNext(tOtherParts,tOtherPointer,tOtherPart)
				If 'tOtherHasData {
					// The prerelease version has more parts for this one.
					Return 1
				}
				If (tOtherPart = tThisPart) {
					// Keep looking through dot-separated parts.
					Continue
				}
				
				// "Collates after" operator works nicely here.
				// e.g., the following are true: "beta" ]] 11, 11 ]] 2, 2 ]] 1
				If (tThisPart ]] tOtherPart) {
					Return 1
				} Else {
					Return 0
				}
			}
			If tFollows && tOtherHasData && $ListNext(tOtherParts,tOtherPointer,tOtherPart) {
				// If there are still dot-separated parts left in the prerelease of the version we are comparing to,
				// it has more than this version, and therefore this version does not follow it.
				Quit 0
			}
		}
	} ElseIf tEquals {
		Quit (pVersion.IsSnapshot() && '..IsSnapshot())
	}
	Quit tFollows
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
