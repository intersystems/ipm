Class %IPM.ResourceProcessor.LegacyLocalizedMessages Extends %IPM.ResourceProcessor.Abstract
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Processes a message dictionary export of error message names, generating an include file with macros to represent them.";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "includeFiles,merge";

/// Acceptable Formats:
/// <include file name>
/// <domain>:<include file name>[,<domain>:<include file name>[,<domain>:<include file name>...]]
Property includeFiles As %String [ Required ];

/// Set to 1 to merge the *domain* (i.e., in ^IRIS.Msg(domain)/^IRIS.MsgNames(domain)) with contents loaded from other error message XML files.
/// Additional work will likely be required to make the domain available for localization in such cases, likely using the LocalizationExport
/// resource processor. (See the HSBASE module for an example of this.)
Property merge As %Boolean [ InitialExpression = 0 ];

Method OnBeforePhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tInitTLevel = $TLevel
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
			
			// Ensure domains are listed if we are expecting to merge them.
			If (..merge) {
				Do ..GetDomainMap(.tDomainMap)
				If '$Data(tDomainMap) {
					Set tMsg = $$$FormatText("To merge domains, you must explicitly map them to include file names in the 'includeFiles' attribute of resource %1",..ResourceReference.Name)
					Set tSC = $$$ERROR($$$GeneralError,tMsg)
					$$$ThrowStatus(tSC)
				}
			}
		} ElseIf (pPhase = "Compile") {
			Set tFile = ..ResourceReference.Module.Root_..ResourceReference.Name
			
			// Build map of domain to target include file (for multi-include case)
			// Also gets array of domains to save and restore
			Do ..GetDomainMap(.tDomainMap)
			
			TSTART
			If (..merge) {
				// Get old contents of ^IRIS.Msg and ^IRIS.MsgNames for selected domains
				Do ..GetDomains(.tDomainMap,.tOldMsg,.tOldMsgNames)
			}
			
			// Copied from HSLIB error load process
			// This will wipe out any existing messages in the domains in the file.
			Set tSC = $$Import^%occMsgXML(tFile,.tPresentDomains,1)
			If $$$ISERR(tSC) {
				Quit
			}
			
			If (..merge) {
				// Get new contents of ^IRIS.Msg and ^IRIS.MsgNames for selected domains
				// This is *only* what was in the file.
				Do ..GetDomains(.tDomainMap,.tNewMsg,.tNewMsgNames)
			}
			
			// Build map of include file to domain (for all cases; for a single include file this is trivial)
			Set tMultiInclude = ($Length(..includeFiles,",") > 1) || ($Length(..includeFiles,":") > 1)
			Set tDomain = ""
			For {
				Set tDomain=$Order(tPresentDomains(tDomain))
				Quit:tDomain=""
				
				// Generate the include
				If (tMultiInclude) {
					If $Data(tDomainMap(tDomain),tTarget) && (tTarget '= "") {
						Set tIncludeMap(tTarget) = $Get(tIncludeMap(tTarget))_$ListBuild(tDomain)
					} Else {
						Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Domain %1 in resource %2 is not mapped to an include file.",tDomain,..ResourceReference.Name))
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
			
			// Restore ^IRIS.Msg and ^IRIS.MsgNames - first merge in old, then merge in new (possibly overwriting some of the old)
			Do ..MergeMessageDomains(.tOldMsg,.tOldMsgNames)
			Do ..MergeMessageDomains(.tNewMsg,.tNewMsgNames)
			TCOMMIT
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) {
		TROLLBACK 1
	}
	Quit tSC
}

/// Builds map of domain to target include file (for multi-include case)
Method GetDomainMap(Output pMap) [ Private ]
{
	Set tIncludeList = $ListFromString(..includeFiles,",")
	Set tPtr = 0
	While $ListNext(tIncludeList,tPtr,tInclude) {
		If $Length(tInclude,":") > 1 {
			Set pMap($Piece(tInclude,":")) = $Piece(tInclude,":",2)
		}
	}
}

ClassMethod GetDomains(ByRef pDomains, Output pMsg, Output pMsgNames) [ Private ]
{
	Kill pMsg,pMsgNames
	Set tDomainKey = ""
	For {
		Set tDomainKey = $Order(pDomains(tDomainKey))
		If (tDomainKey = "") {
			Quit
		}
		Merge pMsg(tDomainKey) = ^IRIS.Msg(tDomainKey)
		Merge pMsgNames(tDomainKey) = ^IRIS.MsgNames(tDomainKey)
	}
}

ClassMethod MergeMessageDomains(ByRef pMsg, ByRef pMsgNames) [ Private ]
{
	Merge ^IRIS.Msg = pMsg
	Merge ^IRIS.MsgNames = pMsgNames
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
					Set tName = $Piece(..includeFiles,":",2)_".INC"
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
