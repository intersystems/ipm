Include %IPM.Common

Class %IPM.General.LogManager Extends %IPM.General.Singleton
{

Parameter logLevels As STRING = "TRACE,INFO,WARNING,ERROR";

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

/// Unix timestamp marking the start time of logging
Property TimeStampStart As %String;

/// Unix timestamp marking the end time of logging
Property TimeStampEnd As %String;

/// The module object for this operation
Property Module As %IPM.Storage.Module;

/// Initialize log files and write headers.
/// @Argument command       Full command passed into the shell (e.g., "install package-name 1.2.0 -quiet -force")
/// @Argument module        The %IPM.Storage.Module object for version info
/// @Argument commandName   The name of the command being logged (e.g., "install", "load", "update", "uninstall")
Method InitializeLog(fullCommand As %String, module As %IPM.Storage.Module, commandName As %String ) As %Status
{
    set ..TimeStampStart = $zdatetime($horolog,-2)
    // TO-DO: obfuscate sensitive information like credentials in the command before logging
    set ..Command = fullCommand
    set ..Module = module

    try {
        // Namespaces are case-insensitive; '%' (e.g. %SYS) is path-hostile and can't collide once mapped to '_'.
        set normalizedNamespace = $translate($zconvert(..%namespace, "L"), "%", "_")

        // Create log directory: <IRIS-mgr>/<namespace>/ipm-logs/
        set mgr = ##class(%Library.File).ManagerDirectory()
        set logDir = ##class(%File).NormalizeDirectory(mgr _ normalizedNamespace _ "/ipm-logs/")
        $$$ThrowOnError(##class(%File).CreateDirectoryChain(logDir))

        // Set file paths with timestamp
        set baseFileName = commandName _ "_" _ module.Name _ "_" _ ..TimeStampStart
        set ..JSONFilePath = logDir _ baseFileName _ ".jsonl"
        set ..TxtFilePath = logDir _ baseFileName _ ".txt"

        // Get IPM version. GetVersion() returns per-module info in versionInfo("zpm") as $lb(namespace, version).
        $$$ThrowOnError(##class(%IPM.Main).GetVersion("zpm", .versionInfo))
        set ipmVersion = $listget($get(versionInfo("zpm")), 2)

        // Write TXT header
        set txtStream = ##class(%Stream.FileCharacter).%New()
        set txtStream.Filename = ..TxtFilePath
        do txtStream.WriteLine("IPM Version: " _ ipmVersion)
        // TODO: Replace hardcoded schema version with global IPM log schema setting
        do txtStream.WriteLine("Schema Version: 1.0.0")
        do txtStream.WriteLine("Command: " _ fullCommand)
        do txtStream.WriteLine("")
        $$$ThrowOnError(txtStream.%Save())

        // Write the JSON Lines header as the first record; subsequent lines are log entries.
        set header = ##class(%DynamicObject).%New()
        // TODO: Replace hardcoded schema path with global IPM log schema setting
        do header.%Set("$schema", "https://raw.githubusercontent.com/intersystems/ipm/main/schemas/ipm-log/1.0.0")
        set header.ipm = ipmVersion
        set header.command = fullCommand

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
        if '$listfind($listfromstring(..#logLevels), level) {
            do ..WriteLogLine("Log has incorrect logLevel "_level_". Please ensure log level is one of: "_..#logLevels_$$$NL_"Attempted message to log was: "_message, "ERROR")
        }
        set entry = ##class(%DynamicObject).%New()
        set entry.level = level
        set entry.message = message
        set entry.timestamp = $zdatetime($ztimestamp, 3) _ " UTC"

        // Append one NDJSON record; no full-file read/parse required.
        set jsonStream = ##class(%Stream.FileCharacter).%New()
        set jsonStream.Filename = ..JSONFilePath
        $$$ThrowOnError(jsonStream.MoveToEnd())
        do jsonStream.WriteLine(entry.%ToJSON())
        $$$ThrowOnError(jsonStream.%Save())

        // Append to TXT file
        set txtStream = ##class(%Stream.FileCharacter).%New()
        set txtStream.Filename = ..TxtFilePath
        $$$ThrowOnError(txtStream.MoveToEnd())
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
