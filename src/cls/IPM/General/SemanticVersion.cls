Class %IPM.General.SemanticVersion Extends (%SerialObject, %IPM.General.SemanticVersion.Properties) [ StorageStrategy = "" ]
{

Parameter DEFAULTGLOBAL = "^IPM.General.SemanticVersion";

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

/// This is an alias for Prerelease. It is used for code readability when SemVerPostRelease is enabled.
Property Postrelease As %IPM.DataType.RegExString(MAXLEN = 100, REGEX = "([0-9A-Za-z-])+(\.([0-9A-Za-z-])+)*") [ Calculated, SqlComputeCode = { set {*} = {Prerelease} }, SqlComputed, Transient ];

Method PostreleaseGet() As %IPM.DataType.RegExString
{
    quit ..Prerelease
}

Method ToString() As %String [ CodeMode = expression ]
{
..Major
_ "." _ ..Minor
_ $case(..Patch, "": "", : "." _ ..Patch)
_ $case(..Prerelease, "": "", : "-" _ ..Prerelease)
_ $case(..Build, "": "", : "+" _ ..Build)
}

Method ToStringWithoutBuild() As %String [ CodeMode = expression ]
{
..Major
_ "." _ ..Minor
_ $case(..Patch, "": "", : "." _ ..Patch)
_ $case(..Prerelease, "": "", : "-" _ ..Prerelease)
}

ClassMethod FromString(pString As %String) As %IPM.General.SemanticVersion
{
    set tVer = ..%New()
    set tVer.Major = $piece($piece($piece(pString,".",1),"-"),"+")
    set tVer.Minor = 0
    set tVer.Patch = 0
    if ($length($piece(pString, "-"), ".") > 3) {
        set tVer.Patch = $piece(pString,".",3)
        set tVer.Build = $piece(pString,".",4)
    }
    if ($length($piece(pString, "-"), ".") > 1) {
        set tVer.Minor = $piece($piece($piece(pString,".",2),"-"),"+")
    }
    if ($length($piece(pString, "-"), ".") > 2) {
        set tVer.Patch = $piece($piece($piece(pString,".",3),"-"),"+")
    }
    set tVer.Prerelease = $piece($piece(pString, "-", 2, *), "+")
    if ($length(pString, "+") > 1) {
        set tVer.Build = $piece(pString, "+", 2)
    }
    quit tVer
}

ClassMethod FromListBuild(pList As %List) As %IPM.General.SemanticVersion
{
    set tVer = ..%New()
    do tVer.%SetSerial(pList)
    quit tVer
}

ClassMethod IsValid(
	pString As %String,
	ByRef pVersion As %IPM.General.SemanticVersion) As %Status
{
    set pVersion = ..FromString(pString)
    quit pVersion.%ValidateObject()
}

/// This callback method is invoked by the <METHOD>%ValidateObject</METHOD> method to
/// provide notification that the current object is being validated.
/// 
/// <P>If this method returns an error then <METHOD>%ValidateObject</METHOD> will fail.
Method %OnValidateObject() As %Status [ Private, ServerOnly = 1 ]
{
    if (..Major '= +..Major) {
        quit $$$ERROR($$$GeneralError,$$$FormatText("Major version (%1) must be a positive integer without trailing zeros.",..Major))
    }
    if (..Minor '= +..Minor) {
        quit $$$ERROR($$$GeneralError,$$$FormatText("Minor version (%1) must be a positive integer without trailing zeros.",..Minor))
    }
    if (..Patch '= +..Patch) {
        quit $$$ERROR($$$GeneralError,$$$FormatText("Patch version (%1) must be a positive integer without trailing zeros.",..Patch))
    }
    set tSC = $$$OK
    set tPointer = 0
    set tPreIdentifiers = $listfromstring(..Prerelease,".")
    while $listnext(tPreIdentifiers,tPointer,tIdentifier) {
        // Cannot have a numeric identifier with a leading zeroes (leading zeroes in an alphanumeric are OK)
        if ($locate(tIdentifier,"^0[0-9]+$")) {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Numeric identifier (%1) in version's prerelease (%2) cannot contain leading zeros.",tIdentifier,..Prerelease))
        }
    }
    quit tSC
}

Method IsSnapshot() As %Boolean
{
    quit ($zconvert(..Build,"L") = "snapshot")
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
    set tFollows = (..Major > pVersion.Major) ||
        ((..Major = pVersion.Major) && (..Minor > pVersion.Minor)) ||
        ((..Major = pVersion.Major) && (..Minor = pVersion.Minor) && (..Patch > pVersion.Patch))

    // Handle post-releases if enabled. With this, post-releases are considered as higher version numbers.
    if ##class(%IPM.Repo.UniversalSettings).GetValue("SemVerPostRelease") {
        if tFollows {
            return 1
        }
        if (..Major < pVersion.Major) || (..Minor < pVersion.Minor) || (..Patch < pVersion.Patch) {
            return 0
        }
        // If it reaches here, major, minor, and patch are equal. We need to check post-releases.
        if (..Postrelease = "") {
            return 0
        } elseif (pVersion.Postrelease = "") {
            return 1
        }
        // If it reaches here, major, minor, and patch are equal. Both post-releases are non-empty. Compare them.
        return ..CompareDotSeparatedStrings(..Postrelease, pVersion.Postrelease)
    }

    // Handle prereleases - messy!!
    set tEquals = (..Major = pVersion.Major) && (..Minor = pVersion.Minor) && (..Patch = pVersion.Patch)
    if (..Prerelease '= "") || (pVersion.Prerelease '= "") {
        if 'tEquals {
            if (..Prerelease '= "") && (pVersion.Prerelease '= "") {
                quit 0
            } else {
                quit tFollows
            }
        } elseif (..Prerelease = pVersion.Prerelease) {
            // They are equal; neither comes before the other, unless pVersion is a snapshot version and this version is not
            quit (pVersion.IsSnapshot() && '..IsSnapshot())
        } elseif (..Prerelease '= "") && (pVersion.Prerelease = "") {
            // This version has a prerelease, so it is earlier than pVersion.
            quit 0
        } elseif (..Prerelease = "") && (pVersion.Prerelease '= "") {
            // We are comparing equal versions where the earlier has a prerelease.
            quit 1
        } else{
            quit ..CompareDotSeparatedStrings(..Prerelease, pVersion.Prerelease)
        }
    } elseif tEquals {
        quit (pVersion.IsSnapshot() && '..IsSnapshot())
    }
    quit tFollows
}

/// Compare two dot-separated strings (usually prerelease or postrelease identifiers).
Method CompareDotSeparatedStrings(
	pThis As %String,
	pOther As %String) As %Boolean
{
    set tThisParts = $listfromstring(pThis,".")
    set tOtherParts = $listfromstring(pOther,".")

    set tOtherHasData = 1
    set tThisPointer = 0
    set tOtherPointer = 0
    while $listnext(tThisParts,tThisPointer,tThisPart) {
        set tOtherHasData = $listnext(tOtherParts,tOtherPointer,tOtherPart)
        if 'tOtherHasData {
            // The prerelease version has more parts for this one.
            return 1
        }
        if (tOtherPart = tThisPart) {
            // Keep looking through dot-separated parts.
            continue
        }

        // "Collates after" operator works nicely here.
        // e.g., the following are true: "beta" ]] 11, 11 ]] 2, 2 ]] 1
        if (tThisPart ]] tOtherPart) {
            return 1
        } else {
            return 0
        }
    }
    return 0
}

Method Satisfies(pExpression As %IPM.General.SemanticVersionExpression) As %Boolean
{
    quit pExpression.IsSatisfiedBy($this)
}

Method WithBumpMajor() As %IPM.General.SemanticVersion
{
    set tVer = ..%New()
    set tVer.Major = ..Major + 1
    set tVer.Minor = 0
    set tVer.Patch = 0
    set tVer.Prerelease = ""
    set tVer.Build = ""
    quit tVer
}

Method WithBumpMinor() As %IPM.General.SemanticVersion
{
    set tVer = ..%New()
    set tVer.Major = ..Major
    set tVer.Minor = ..Minor + 1
    set tVer.Patch = 0
    set tVer.Prerelease = ""
    set tVer.Build = ""
    quit tVer
}

Method WithBumpPatch() As %IPM.General.SemanticVersion
{
    set tVer = ..%New()
    set tVer.Major = ..Major
    set tVer.Minor = ..Minor
    set tVer.Patch = ..Patch + 1
    set tVer.Prerelease = ""
    set tVer.Build = ""
    quit tVer
}

Method WithPrerelease(pPrerelease As %String) As %IPM.General.SemanticVersion
{
    set tVer = ..%New()
    set tVer.Major = ..Major
    set tVer.Minor = ..Minor
    set tVer.Patch = ..Patch
    set tVer.Prerelease = pPrerelease
    set tVer.Build = ..Build
    quit tVer
}

Method WithBuild(pBuild As %String) As %IPM.General.SemanticVersion
{
    set tVer = ..%New()
    set tVer.Major = ..Major
    set tVer.Minor = ..Minor
    set tVer.Patch = ..Patch
    set tVer.Prerelease = ..Prerelease
    set tVer.Build = pBuild
    quit tVer
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
