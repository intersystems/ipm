Class %ZPM.PackageManager.Developer.Processor.LegacyErrorMessages Extends %ZPM.PackageManager.Developer.Processor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Processes a message dictionary export of error message names, generating an include file with macros to represent them.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "includeFiles";

/// Acceptable Formats:
/// <include file name>
/// <domain>:<include file name>[,<domain>:<include file name>[,<domain>:<include file name>...]]
Property includeFiles As %String [ Required ];

Method OnBeforePhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		If (pPhase = "Validate") {
			If (..includeFiles = "") || (..includeFiles = $c(0)) {
				Set tMsg = $$$FormatText("Must specify an 'includeFiles' attribute for resource processor class %1 on resource %2",$classname(),..ResourceReference.Name)
				$$$ThrowStatus($$$ERROR($$$GeneralError,tMsg))
			} ElseIf (..includeFiles [ ",") || (..includeFiles [ ":") {
				// TODO: Use a regex for validation?
				Set tIncludeList = $ListFromString(..includeFiles,",")
				Set tPtr = 0
				While $ListNext(tIncludeList,tPtr,tInclude) {
					If '$Data(tInclude) || ($Piece(..includeFiles,":") = "") || ($Piece(..includeFiles,":",2) = "") {
						$$$ThrowStatus($$$ERROR($$$GeneralError,"Invalid value for 'includeFiles': "_..includeFiles))
					}
				}
			}
		} ElseIf (pPhase = "Compile") {
			Set tFile = ..ResourceReference.Module.Root_..ResourceReference.Name
			
			// Copied from HSLIB error load process
			Set tSC = $$Import^%occMsgXML(tFile,.tPresentDomains,1)
			If $$$ISERR(tSC) {
				Quit
			}
			
			// Build map of domain to target include file (for multi-include case)
			Set tMultiInclude = ($Length(..includeFiles,",") > 1) || ($Length(..includeFiles,":") > 1)
			If (tMultiInclude) {
				Set tIncludeList = $ListFromString(..includeFiles,",")
				Set tPtr = 0
				While $ListNext(tIncludeList,tPtr,tInclude) {
					Set tDomainMap($Piece(tInclude,":")) = $Piece(tInclude,":",2)
				}
			}
			
			// Build map of include file to domain (for all cases; for a single include file this is trivial)
			Set tDomain = ""
			For {
				Set tDomain=$Order(tPresentDomains(tDomain))
				Quit:tDomain=""
				
				// Generate the include
				If (tMultiInclude) {
					If $Data(tDomainMap(tDomain),tTarget) && (tTarget '= "") {
						Set tIncludeMap(tTarget) = $Get(tIncludeMap(tTarget))_$ListBuild(tDomain)
					} Else {
						Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Domain %1 in resource %2 is not mapped to an include file."),tDomain,..ResourceReference.Name)
						Quit
					}
				} Else {
					Set tIncludeMap(..includeFiles) = $Get(tIncludeMap(..includeFiles))_$ListBuild(tDomain)
				}
			}
			If $$$ISERR(tSC) {
				Quit
			}
			
			// Generate all include files
			Set tInclude = ""
			For {
				Set tInclude = $Order(tIncludeMap(tInclude),1,tDomainList)
				Quit:tInclude=""
				
				Do GenerateInclude^%occMsgXML(tInclude,0,$lts(tDomainList),1)
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnResolveChildren(ByRef pResourceArray) As %Status
{
	Set tSC = $$$OK
	Try {
		If (..includeFiles [ ",") || (..includeFiles [ ":") {
			Set tIncludeList = $ListFromString(..includeFiles,",")
			Set tPtr = 0
			While $ListNext(tIncludeList,tPtr,tInclude) {
				If $Data(tInclude) || ($Piece(..includeFiles,":") '= "") {
					Set tName = $Piece(..includeFiles,":")_".INC"
					Set pResourceArray(tName) = ..ResourceReference.Module.Name
					Set pResourceArray(tName,"Generated") = 1
				}
			}
		} ElseIf (..includeFiles '= "") {
			Set pResourceArray(..includeFiles_".INC") = ..ResourceReference.Module.Name
			Set pResourceArray(..includeFiles_".INC","Generated") = 1
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
