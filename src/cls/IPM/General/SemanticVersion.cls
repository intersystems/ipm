Class %IPM.General.SemanticVersion Extends (%SerialObject, %XML.Adaptor) [ StorageStrategy = "" ]
{

Parameter DEFAULTGLOBAL = "^IPM.General.SemanticVersion";

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Property Major As %Integer(MINVAL = 0) [ Required ];

Property Minor As %Integer(MINVAL = 0) [ Required ];

Property Patch As %Integer(MINVAL = 0) [ Required ];

Property Prerelease As %IPM.DataType.RegExString(MAXLEN = 100, REGEX = "([0-9A-Za-z-])+(\.([0-9A-Za-z-])+)*");

/// This is an alias for Prerelease. It is used for code readability when SemVerPostRelease is enabled.
Property Postrelease As %IPM.DataType.RegExString(MAXLEN = 100, REGEX = "([0-9A-Za-z-])+(\.([0-9A-Za-z-])+)*") [ Calculated, SqlComputeCode = { Set {*} = {Prerelease} }, SqlComputed, Transient ];

Property Build As %IPM.DataType.RegExString(MAXLEN = 100, REGEX = "([0-9A-Za-z-])+(\.([0-9A-Za-z-])+)*");

Method PostreleaseGet() As %IPM.DataType.RegExString
{
	Quit ..Prerelease
}

Method ToString() As %String [ CodeMode = expression ]
{
..Major 
_ "." _ ..Minor 
_ $Case(..Patch, "": "", : "." _ ..Patch) 
_ $Case(..Prerelease, "": "", : "-" _ ..Prerelease) 
_ $Case(..Build, "": "", : "+" _ ..Build)
}

ClassMethod FromString(pString As %String) As %IPM.General.SemanticVersion
{
  Set tVer = ..%New()
  Set tVer.Major = $Piece($Piece($Piece(pString,".",1),"-"),"+")
  Set tVer.Minor = 0
  Set tVer.Patch = 0
  If ($Length($Piece(pString, "-"), ".") > 3) {
    Set tVer.Patch = $Piece(pString,".",3)
    Set tVer.Build = $Piece(pString,".",4)
  }
  If ($Length($Piece(pString, "-"), ".") > 1) {
    Set tVer.Minor = $Piece($Piece($Piece(pString,".",2),"-"),"+")
  }
  If ($Length($Piece(pString, "-"), ".") > 2) {
    Set tVer.Patch = $Piece($Piece($Piece(pString,".",3),"-"),"+")
  }
  Set tVer.Prerelease = $Piece($Piece(pString, "-", 2, *), "+")
  If ($Length(pString, "+") > 1) {
    Set tVer.Build = $Piece(pString, "+", 2)
  }
  Quit tVer
}

ClassMethod FromListBuild(pList As %List) As %IPM.General.SemanticVersion
{
	Set tVer = ..%New()
	Do tVer.%SetSerial(pList)
	Quit tVer
}

ClassMethod IsValid(pString As %String, ByRef pVersion As %IPM.General.SemanticVersion) As %Status
{
	Set pVersion = ..FromString(pString)
	Quit pVersion.%ValidateObject()
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
		Set tNumeric = $ZStrip(tIdentifier, "*ACPW")
		If (+tNumeric > 0) && (+tNumeric '= tNumeric) {
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
Method IsCompatibleWith(pVersion As %IPM.General.SemanticVersion) As %Boolean [ CodeMode = expression ]
{
(pVersion.Major = ..Major) && (pVersion.Minor = ..Minor)
}

/// Returns 1 if this version's number indicates that it will also support everything in <var>pVersion</var>.
/// That is, it has the same major and a later or equal minor version to <var>pVersion</var>.
Method IsBackwardCompatibleWith(pVersion As %IPM.General.SemanticVersion) As %Boolean [ CodeMode = expression ]
{
(pVersion.Major = ..Major) && (pVersion.Minor <= ..Minor)
}

/// Returns 1 if this version is a later version than <var>pVersion</var>. <br />
/// From <a href="http://semver.org/spec/v2.0.0.html#spec-item-11">the SemVer 2.0.0 specification</a>: <br />
/// 1.0.0-alpha &lt; 1.0.0-alpha.1 &lt; 1.0.0-alpha.beta &lt; 1.0.0-beta &lt; 1.0.0-beta.2 &lt; 1.0.0-beta.11 &lt; 1.0.0-rc.1 &lt; 1.0.0
/// Also, two prerelease versions with mismatched major/minor/patch should *not* follow each other; see: <a href="https://github.com/npm/node-semver#prerelease-tags">node-semver</a>
Method Follows(pVersion As %IPM.General.SemanticVersion) As %Boolean
{
	Set tFollows = (..Major > pVersion.Major) ||
		((..Major = pVersion.Major) && (..Minor > pVersion.Minor)) ||
		((..Major = pVersion.Major) && (..Minor = pVersion.Minor) && (..Patch > pVersion.Patch))
	
	// Handle post-releases if enabled. With this, post-releases are considered as higher version numbers.
	If ##class(%IPM.Repo.UniversalSettings).GetValue("SemVerPostRelease") {
		If tFollows {
			Return 1
		} 
		If (..Major < pVersion.Major) || (..Minor < pVersion.Minor) || (..Patch < pVersion.Patch) {
			Return 0
		} 
		// If it reaches here, major, minor, and patch are equal. We need to check post-releases.
		If (..Postrelease = "") {
			Return 0
		} ElseIf (pVersion.Postrelease = "") {
			Return 1
		} 	
		// If it reaches here, major, minor, and patch are equal. Both post-releases are non-empty. Compare them.
		Return ..CompareDotSeparatedStrings(..Postrelease, pVersion.Postrelease)

	}
	
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
			Quit ..CompareDotSeparatedStrings(..Prerelease, pVersion.Prerelease)
		}
	} ElseIf tEquals {
		Quit (pVersion.IsSnapshot() && '..IsSnapshot())
	}
	Quit tFollows
}

/// Compare two dot-separated strings (usually prerelease or postrelease identifiers).
Method CompareDotSeparatedStrings(pThis As %String, pOther As %String) As %Boolean
{
	Set tThisParts = $ListFromString(pThis,".")
	Set tOtherParts = $ListFromString(pOther,".")
	
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
	Return 0
}

Method Satisfies(pExpression As %IPM.General.SemanticVersionExpression) As %Boolean
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
<StreamLocation>^IPM.General.SemanticVersionS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
