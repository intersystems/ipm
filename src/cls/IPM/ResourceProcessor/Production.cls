/// Resource processor for IRIS Interoperability productions.
/// Manages runtime state: autostart registration, auto-update on activate, and stop on uninstall.
Class %IPM.ResourceProcessor.Production Extends %IPM.ResourceProcessor.Abstract
{

Parameter DESCRIPTION As STRING = "Manages the runtime lifecycle of an IRIS Interoperability production: autostart, auto-update on activate, and stopping on uninstall.";

Parameter ATTRIBUTES As STRING = "Name,AutoStart,AutoUpdate";

/// The class name of the production to manage.
Property Name As %String(MAXLEN = "") [ Required ];

/// If true, registers this production as the namespace autostart production and starts it during Activate.
Property AutoStart As %Boolean [ InitialExpression = 0 ];

/// If true, queues an update if the production needs updating during Activate.
Property AutoUpdate As %Boolean [ InitialExpression = 1 ];

Method OnGetUniqueName(Output pUniqueName)
{
    // an arbitrary extension chosen not to collide with future document types
    set pUniqueName = ..Name _ ".ZPRODUCTION"
}

Method OnBeforePhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set sc = $$$OK
    try {
        set sc = ##super(pPhase, .pParams)
        if $$$ISERR(sc) {
            quit
        }

        if (pPhase = "Validate") {
            set sysReqs = ..ResourceReference.Module.SystemRequirements
            if '$isobject(sysReqs) || (sysReqs.Interoperability '= "enabled") {
                set sc = $$$ERROR($$$GeneralError, $$$FormatText("Module '%1' must declare <SystemRequirements Interoperability=""enabled""/> to use the Production resource processor.", ..ResourceReference.Module.Name))
                quit
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    quit sc
}

Method OnAfterPhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set sc = $$$OK
    try {
        set sc = ##super(pPhase, .pParams)
        if $$$ISERR(sc) {
            quit
        }

        if (pPhase = "Activate") {
            if ..AutoStart {
                // Set this production as the namespace autostart production
                set sc = ##class(Ens.Director).SetAutoStart(..Name)
                if $$$ISERR(sc) {
                    quit
                }

                set sc = ##class(Ens.Director).GetProductionStatus(.runningName, .state)
                if $$$ISERR(sc) {
                    quit
                }

                if state = 0 {
                    // StartProduction issues transaction control statements that break
                    // IPM's outer transaction, so run it in a worker job
                    set workmgr = $system.WorkMgr.%New()
                    if workmgr = "" {
                        set sc = %objlasterror
                        quit
                    }
                    set sc = workmgr.Queue("##class(Ens.Director).StartProduction", ..Name)
                    if $$$ISERR(sc) {
                        quit
                    }
                    set sc = workmgr.Sync()
                    if $$$ISERR(sc) {
                        quit
                    }
                }
            }

            if ..AutoUpdate {
                if ##class(Ens.Director).ProductionNeedsUpdate() {
                    set timeout = ##class(Ens.Director).GetRunningProductionUpdateTimeout()
                    set workmgr = $system.WorkMgr.%New()
                    if workmgr = "" {
                        set sc = %objlasterror
                        quit
                    }
                    set sc = workmgr.Queue("##class(Ens.Director).UpdateProduction", timeout)
                    if $$$ISERR(sc) {
                        quit
                    }
                }
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    quit sc
}

Method OnPhase(
	pPhase As %String,
	ByRef pParams,
	Output pResourceHandled As %Boolean = 0) As %Status
{
    set sc = $$$OK
    try {
        if (pPhase = "Clean") {
            set pResourceHandled = 1

            set sc = ##class(Ens.Director).GetProductionStatus(.runningName, .state)
            if $$$ISERR(sc) {
                quit
            }

            if (state '= 0) && (runningName = ..Name) {
                set timeout = ##class(Ens.Director).GetRunningProductionShutdownTimeout()
                set sc = ##class(Ens.Director).StopProduction(timeout)
                if $$$ISERR(sc) {
                    quit
                }
            }

            if ..AutoStart {
                set sc = ##class(Ens.Director).SetAutoStart("")
                if $$$ISERR(sc) {
                    quit
                }
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    quit sc
}

}
