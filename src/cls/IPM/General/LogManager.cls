Include %IPM.Common

Class %IPM.General.LogManager Extends %IPM.General.Singleton
{

/// Has hashes of unique messages (with data equal to the index in ..Messages of that message)
Property UniqueMessageHashes [ MultiDimensional, Private ];

Property Messages As list Of %IPM.General.LogManager.Message;

Property Threshold As %Integer [ InitialExpression = {$$$ZPMLogWARNING} ];

/// Command being logged (with credentials obfuscated)
Property Command As %String;

/// Absolute path to the JSON Lines (NDJSON) log file
Property JSONFilePath As %String;

/// Absolute path to the TXT log file
Property TxtFilePath As %String;

/// Starting Unix timestamp for this log
Property Timestamp As %Integer;

/// The module object for this operation
Property Module As %IPM.Storage.Module;

/// Initialize log files and write headers.
/// @Argument command       The command verb being logged (e.g., "install", "load", "update", "uninstall")
/// @Argument module        The %IPM.Storage.Module object for version info
Method InitializeLog(command As %String, module As %IPM.Storage.Module) As %Status
{
    set ..Timestamp = $now()
    set ..Command = command
    set ..Module = module

    try {
        // Namespaces are case-insensitive; '%' (e.g. %SYS) is path-hostile and can't collide once mapped to '_'.
        set normalizedNamespace = $translate($zconvert(..%namespace, "L"), "%", "_")

        // Create log directory: <IRIS-mgr>/ipm-logs/<namespace>/
        set mgr = ##class(%File).GetDirectory("")
        set logDir = ##class(%File).NormalizeDirectory(mgr _ "ipm-logs/" _ normalizedNamespace _ "/")
        $$$ThrowOnError(##class(%File).CreateDirectoryChain(logDir))

        // Set file paths with timestamp
        set unixTimestamp = $zdatetime($horolog,-2)
        set baseFileName = command _ "_" _ module.Name _ "_" _ unixTimestamp
        set ..JSONFilePath = logDir _ baseFileName _ ".jsonl"
        set ..TxtFilePath = logDir _ baseFileName _ ".txt"

        // Get IPM version
        set versionInfo = ""
        $$$ThrowOnError(##class(%IPM.Main).GetVersion("zpm", .versionInfo))
        set ipmVersion = $listget(versionInfo, 2)

        // Write TXT header
        set txtStream = ##class(%Stream.FileCharacter).%New()
        set txtStream.Filename = ..TxtFilePath
        do txtStream.WriteLine("IPM Version: " _ ipmVersion)
        // TODO: Replace hardcoded schema version with global IPM log schema setting
        do txtStream.WriteLine("Schema Version: 1.0.0")
        do txtStream.WriteLine("Command: " _ command)
        do txtStream.WriteLine("")
        $$$ThrowOnError(txtStream.%Save())

        // Write the JSON Lines header as the first record; subsequent lines are log entries.
        set header = ##class(%DynamicObject).%New()
        set header.ipm = ipmVersion
        // TODO: Replace hardcoded schema version with global IPM log schema setting
        set header.schema = "1.0.0"
        set header.command = command

        set jsonStream = ##class(%Stream.FileCharacter).%New()
        set jsonStream.Filename = ..JSONFilePath
        do jsonStream.WriteLine(header.%ToJSON())
        $$$ThrowOnError(jsonStream.%Save())

        return $$$OK
    }
    catch ex
    {
        return ex.AsStatus()
    }
}

/// Write a log entry to both the JSON Lines and TXT files.
/// @Argument level         The log level: TRACE, INFO, WARNING, or ERROR
/// @Argument message       The human-readable log message to append
Method WriteLogLine(level As %String, message As %String) As %Status
{
    try
    {
        set entry = ##class(%DynamicObject).%New()
        set entry.level = level
        set entry.message = message
        set entry.timestamp = $zdatetime($ztimestamp, 3) _ " UTC"

        // Append one NDJSON record; no full-file read/parse required.
        set jsonStream = ##class(%Stream.FileCharacter).%New()
        set jsonStream.Filename = ..JSONFilePath
        $$$ThrowOnError(jsonStream.%Open("A"))
        do jsonStream.WriteLine(entry.%ToJSON())
        $$$ThrowOnError(jsonStream.%Save())

        // Append to TXT file
        set txtStream = ##class(%Stream.FileCharacter).%New()
        set txtStream.Filename = ..TxtFilePath
        $$$ThrowOnError(txtStream.%Open("A"))  // Append mode
        do txtStream.WriteLine(entry.timestamp _ " [" _ level _ "] " _ message)
        $$$ThrowOnError(txtStream.%Save())

        return $$$OK
    }
    catch ex
    {
        return ex.AsStatus()
    }
}

Method Flush(pThreshold As %Integer = {..Threshold})
{
    set tLastMessage = $$$NULLOREF
    for tMessageIndex=1:1:..Messages.Count() {
        set tMessage = ..Messages.GetAt(tMessageIndex)
        if (tMessage.Severity >= pThreshold) {
            if $isobject(tLastMessage) && (tMessage.GetHash() = tLastMessage.GetHash()) {
                // Don't repeat the same message, just track the count.
                set tMessage.Count = tLastMessage.Count + tMessage.Count
            } elseif $isobject(tLastMessage) && (tLastMessage.Severity >= pThreshold) {
                do tLastMessage.Display()
            }
            set tLastMessage = tMessage
        }
    }
    if $isobject(tLastMessage) {
        do tLastMessage.Display()
    }

    do ..Messages.Clear()
    kill ..UniqueMessageHashes
}

/// Flushes out the log of messages before doing the standard singleton cleanup.
Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
    set tSC = ##super()
    do ..Flush()
    quit tSC
}

/// @API.Method
ClassMethod Trace(
	pMessage As %String,
	pUnique As %Boolean = 0)
{
    do ..CreateMessage(pMessage, pUnique, $$$ZPMLogTRACE)
}

/// @API.Method
ClassMethod Info(
	pMessage As %String,
	pUnique As %Boolean = 0)
{
    do ..CreateMessage(pMessage, pUnique, $$$ZPMLogINFO)
}

/// @API.Method
ClassMethod Warning(
	pMessage As %String,
	pUnique As %Boolean = 0)
{
    do ..CreateMessage(pMessage, pUnique, $$$ZPMLogWARNING)
}

/// @API.Method
ClassMethod Error(
	pMessage As %String,
	pUnique As %Boolean = 0)
{
    do ..CreateMessage(pMessage, pUnique, $$$ZPMLogERROR)
}

ClassMethod CreateMessage(
	pMessage As %String,
	pUnique As %Boolean = 0,
	pSeverity As %Integer) [ Private ]
{
    set tMessage = ##class(%IPM.General.LogManager.Message).%New(pMessage,pSeverity)
    set tInstance = ..%Get(.tSC)
    if $$$ISOK(tSC) {
        do tInstance.AddMessage(tMessage,pUnique)
    } else {
        do tMessage.Display()
    }
}

Method AddMessage(
	pMessage As %IPM.General.LogManager.Message,
	pUnique As %Boolean = 0) [ Private ]
{
    set tHash = pMessage.GetHash()
    if $data(..UniqueMessageHashes(tHash),tIndex) {
        set ..Messages.GetAt(tIndex).Count = ..Messages.GetAt(tIndex).Count + 1
    } else {
        do ..Messages.Insert(pMessage)
        if pUnique {
            set ..UniqueMessageHashes(tHash) = ..Messages.Count()
        }
    }
}

}
