Include (%IPM.Common, %IPM.Formatting)

/// Abstract superclass of %IPM.General.History and %IPM.General.HistoryTemp for history logs
/// %IPM.General.HistoryTemp is stored in IRISTEMP so that history logs are not affected when transactions are rolled back due to install/load failure
/// %IPM.General.History is where the permanent data is persisted and where all record getting methods are defined
/// All history logging attempts should create and modify an instance of %IPM.General.HistoryTemp,
/// which will be persisted to %IPM.General.History on init and when the object falls out of scope
Class %IPM.General.AbstractHistory Extends %Persistent [ Abstract, NoExtent ]
{

/// Action of this history record. Can be load, install, ci, uninstall or update
Property Action As %String(VALUELIST = ",load,install,ci,uninstall,update") [ Required ];

/// Name of the package being logged. This is not necessarily required, e.g. when loading a nonexistent directory.
Property Package As %IPM.DataType.ModuleName;

/// Version of the package being logged. This will sometimes be the default 0.0.0-0 until the actual version is found.
Property Version As %IPM.General.SemanticVersion [ Required ];

/// Name of the repository where the package is being installed. For load and uninstall this will be empty.
Property SourceName As %IPM.DataType.RepoName;

/// Moniker of the repository where the package is being installed. For load and uninstall this will be empty.
Property SourceMoniker As %IPM.DataType.RepoMoniker;

/// Details of the repository where the package is being installed. For load and uninstall this will be empty.
Property SourceDetails As %String(MAXLEN = "");

/// Time when the action started
Property TimeStart As %TimeStamp [ InitialExpression = {$zdatetime($now(), 3)}, Required ];

/// Time when the action ended. This will be empty if the action is still in progress or ended abnormally.
Property TimeEnd As %TimeStamp;

/// User who initiated the action
Property UserName As %Library.Username [ InitialExpression = {$username}, Required ];

/// Status of the action. If the action is still in progress, this will be 0. Otherwise, it will be the status code of the action.
Property Success As %Status [ InitialExpression = 0, Required ];

/// Whether the action has been permanantly written "to disk". A non-committed action has been rolled back.
/// In non developer mode, this indicates whether the action was successful. In developer mode, this is always true.
Property Committed As %Boolean [ InitialExpression = 0, Required ];

/// The command string that triggered the action
Property CommandString As %String(MAXLEN = "") [ Required ];

Property Phases As list Of %IPM.General.HistoryPhase;

ClassMethod Init(
	Action As %String,
	Package As %IPM.DataType.ModuleName) As %IPM.General.AbstractHistory [ Private ]
{
    set log = ..%New()
    set log.Action = Action
    set log.Package = Package
    set log.CommandString = $get($$$ZPMCommandToLog, "<unset>")
    set log.UserName = $username
    $$$ThrowOnError(log.SetVersion()) // Set the version to placeholder 0.0.0-0; will be updated before finalizing
    $$$ThrowOnError(log.%Save()) // Save it now in case Finalize isn't called
    quit log
}

ClassMethod InstallInit(Package As %IPM.DataType.ModuleName) As %IPM.General.AbstractHistory
{
    quit ..Init("install", Package)
}

ClassMethod CleanInstallInit(Package As %IPM.DataType.ModuleName) As %IPM.General.AbstractHistory
{
    quit ..Init("ci", Package)
}

ClassMethod LoadInit(Package As %IPM.DataType.ModuleName = "") As %IPM.General.AbstractHistory
{
    // Package name may not known at this point, so use a placeholder
    quit ..Init("load", Package)
}

ClassMethod UninstallInit(Package As %IPM.DataType.ModuleName) As %IPM.General.AbstractHistory
{
    quit ..Init("uninstall", Package)
}

ClassMethod UpdateInit(Package As %IPM.DataType.ModuleName) As %IPM.General.AbstractHistory
{
    quit ..Init("update", Package)
}

Method SetSource(ServerName As %String) As %Status
{
    $$$ThrowOnError(..%Reload())
    set server = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(ServerName, 0)
    if '$isobject(server) {
        quit $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is not defined.", ServerName))
    }
    set ..SourceName = ServerName
    set ..SourceMoniker = server.#MONIKER
    set ..SourceDetails = server.Details
    quit ..%Save()
}

Method SetVersion(pVersion As %IPM.General.SemanticVersion) As %Status
{
    // If object is being initialized, this will fail, so set placeholder instead
    if ..%Id() '= "" {
        $$$ThrowOnError(..%Reload())
    }
    if $get(pVersion) = "" {
        set pVersion = "0.0.0-0"
    }
    set ..Version = $select($isobject(pVersion): pVersion, 1: ##class(%IPM.General.SemanticVersion).FromString(pVersion))
    quit ..%Save()
}

Method SetName(pName As %String) As %Status
{
    $$$ThrowOnError(..%Reload())
    set ..Package = pName
    quit ..%Save()
}

Method Finalize(
	status As %Status,
	dev As %Boolean = 0) As %Status
{
    $$$ThrowOnError(..%Reload())
    set ..Success = status
    set ..Committed = (dev = 1) || $$$ISOK(status)
    set ..TimeEnd = $zdatetime($now(), 3)
    return ..%Save()
}

Method InitPhase(name As %String)
{
    set phase = ##class(%IPM.General.HistoryPhase).%New()
    set phase.Name = name
    $$$ThrowOnError(..Phases.Insert(phase))
    $$$ThrowOnError(..%Save()) // Save it now in case Finalize isn't called
}

Method FinalizePhase(
	name As %String,
	status As %Status)
{
    if ..Phases.Size = 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "No phase logs found"))
    }
    // Most likely the last phase in the list so check there first
    set phase = ..Phases.GetAt(..Phases.Size)
    if phase.Name = name {
        set phase.Success = status
        set phase.TimeEnd = $zdatetime($now(), 3)
        $$$ThrowOnError(..%Save())
    } else {
        // look through the rest of the phases
        set key = ""
        for {
            set phase = ..Phases.GetNext(.key)
            if phase.Name = name {
                set phase.Success = status
                set phase.TimeEnd = $zdatetime($now(), 3)
                $$$ThrowOnError(..%Save())
                quit
            }
            if key = "" {
                $$$ThrowStatus($$$ERROR($$$GeneralError, "No log for phase " _ name _ " found"))
            }
        }
    }
}

}
