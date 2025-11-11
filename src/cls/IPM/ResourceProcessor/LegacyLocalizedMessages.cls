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

Method OnBeforePhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set tInitTLevel = $tlevel
    set tSC = $$$OK
    try {
        if (pPhase = "Validate") {
            if (..includeFiles = "") || (..includeFiles = $char(0)) {
                set tMsg = $$$FormatText("Must specify an 'includeFiles' attribute for resource processor class %1 on resource %2",$classname(),..ResourceReference.Name)
                $$$ThrowStatus($$$ERROR($$$GeneralError,tMsg))
            } elseif (..includeFiles [ ",") || (..includeFiles [ ":") {
                // TODO: Use a regex for validation?
                set tIncludeList = $listfromstring(..includeFiles,",")
                set tPtr = 0
                while $listnext(tIncludeList,tPtr,tInclude) {
                    if '$data(tInclude) || ($piece(..includeFiles,":") = "") || ($piece(..includeFiles,":",2) = "") {
                        $$$ThrowStatus($$$ERROR($$$GeneralError,"Invalid value for 'includeFiles': "_..includeFiles))
                    }
                }
            }

            // Ensure domains are listed if we are expecting to merge them.
            if (..merge) {
                do ..GetDomainMap(.tDomainMap)
                if '$data(tDomainMap) {
                    set tMsg = $$$FormatText("To merge domains, you must explicitly map them to include file names in the 'includeFiles' attribute of resource %1",..ResourceReference.Name)
                    set tSC = $$$ERROR($$$GeneralError,tMsg)
                    $$$ThrowStatus(tSC)
                }
            }
        } elseif (pPhase = "Compile") {
            set tFile = ..ResourceReference.Module.Root_..ResourceReference.Name

            // Build map of domain to target include file (for multi-include case)
            // Also gets array of domains to save and restore
            do ..GetDomainMap(.tDomainMap)

            tstart
            if (..merge) {
                // Get old contents of ^IRIS.Msg and ^IRIS.MsgNames for selected domains
                do ..GetDomains(.tDomainMap,.tOldMsg,.tOldMsgNames)
            }

            // Copied from HSLIB error load process
            // This will wipe out any existing messages in the domains in the file.
            set tSC = $$Import^%occMsgXML(tFile,.tPresentDomains,1)
            if $$$ISERR(tSC) {
                quit
            }

            if (..merge) {
                // Get new contents of ^IRIS.Msg and ^IRIS.MsgNames for selected domains
                // This is *only* what was in the file.
                do ..GetDomains(.tDomainMap,.tNewMsg,.tNewMsgNames)
            }

            // Build map of include file to domain (for all cases; for a single include file this is trivial)
            set tMultiInclude = ($length(..includeFiles,",") > 1) || ($length(..includeFiles,":") > 1)
            set tDomain = ""
            for {
                set tDomain=$order(tPresentDomains(tDomain))
                quit:tDomain=""

                // Generate the include
                if (tMultiInclude) {
                    if $data(tDomainMap(tDomain),tTarget) && (tTarget '= "") {
                        set tIncludeMap(tTarget) = $get(tIncludeMap(tTarget))_$listbuild(tDomain)
                    } else {
                        set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Domain %1 in resource %2 is not mapped to an include file.",tDomain,..ResourceReference.Name))
                        quit
                    }
                } else {
                    set tIncludeMap(..includeFiles) = $get(tIncludeMap(..includeFiles))_$listbuild(tDomain)
                }
            }
            if $$$ISERR(tSC) {
                quit
            }

            // Generate all include files
            set tInclude = ""
            for {
                set tInclude = $order(tIncludeMap(tInclude),1,tDomainList)
                quit:tInclude=""

                do GenerateInclude^%occMsgXML(tInclude,0,$listtostring(tDomainList),1)
            }

            // Restore ^IRIS.Msg and ^IRIS.MsgNames - first merge in old, then merge in new (possibly overwriting some of the old)
            do ..MergeMessageDomains(.tOldMsg,.tOldMsgNames)
            do ..MergeMessageDomains(.tNewMsg,.tNewMsgNames)
            tcommit
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    while ($tlevel > tInitTLevel) {
        trollback 1
    }
    quit tSC
}

/// Builds map of domain to target include file (for multi-include case)
Method GetDomainMap(Output pMap) [ Private ]
{
    set tIncludeList = $listfromstring(..includeFiles,",")
    set tPtr = 0
    while $listnext(tIncludeList,tPtr,tInclude) {
        if $length(tInclude,":") > 1 {
            set pMap($piece(tInclude,":")) = $piece(tInclude,":",2)
        }
    }
}

ClassMethod GetDomains(
	ByRef pDomains,
	Output pMsg,
	Output pMsgNames) [ Private ]
{
    kill pMsg,pMsgNames
    set tDomainKey = ""
    for {
        set tDomainKey = $order(pDomains(tDomainKey))
        if (tDomainKey = "") {
            quit
        }
        merge pMsg(tDomainKey) = ^IRIS.Msg(tDomainKey)
        merge pMsgNames(tDomainKey) = ^IRIS.MsgNames(tDomainKey)
    }
}

ClassMethod MergeMessageDomains(
	ByRef pMsg,
	ByRef pMsgNames) [ Private ]
{
    merge ^IRIS.Msg = pMsg
    merge ^IRIS.MsgNames = pMsgNames
}

Method OnResolveChildren(ByRef pResourceArray) As %Status
{
    set tSC = $$$OK
    try {
        if (..includeFiles [ ",") || (..includeFiles [ ":") {
            set tIncludeList = $listfromstring(..includeFiles,",")
            set tPtr = 0
            while $listnext(tIncludeList,tPtr,tInclude) {
                if $data(tInclude) || ($piece(..includeFiles,":") '= "") {
                    set tName = $piece(..includeFiles,":",2)_".INC"
                    set pResourceArray(tName) = ..ResourceReference.Module.Name
                    set pResourceArray(tName,"Generated") = 1
                }
            }
        } elseif (..includeFiles '= "") {
            set pResourceArray(..includeFiles_".INC") = ..ResourceReference.Module.Name
            set pResourceArray(..includeFiles_".INC","Generated") = 1
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

}
