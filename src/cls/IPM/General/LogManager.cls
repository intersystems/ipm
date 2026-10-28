Include (%IPM.Common, %IPM.Formatting)

Class %IPM.General.LogManager Extends %IPM.General.Singleton
{

Parameter LogLevels As STRING = "TRACE,INFO,WARNING,ERROR";

Parameter SupportedCommands As STRING = "install,load,update,uninstall";

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

Property SchemaVersion As %String [ InitialExpression = "1.0.0" ];

/// Default verbosity of terminal logging in the log manager for this command. Set by the verbose modifier in the command input.
Property Verbose As %Boolean [ InitialExpression = 1 ];

/// Indicates whether the log manager has been initialized (currently writing to .txt and .jsonl log files)
Property Initialized As %Boolean [ Calculated, ReadOnly ];

Method InitializedGet() As %Boolean
{
    return (..TxtFilePath '= "")
}

/// Initialize log files and write headers.
/// @Argument fullCommand           The full shell command as entered by the user
/// @Argument ByRef commandInfo     Contains the parsed shell command (for format, see output of ##class(%IPM.CLI).%ParseCommandInput())
Method InitializeLog(
	fullCommand As %String,
	ByRef commandInfo) As %Status
{
    // Still want to set verbosity even for commands that don't initialize log files
    if '..Initialized {
        set ..Verbose = $$$GetDataDef(commandInfo,"Verbose", 0)
    }

    if $$$HasData(commandInfo,"NoLog") {
        $$$LogLine("Modifier -no-log is present, file logging will be disabled.", $$$Warning)
    }

    // Skip log initialization if -no-log flag was given, command does not support a log file, or log is already initialized
    if $$$GetDataDef(commandInfo, "NoLog", 0) || '$listfind($listfromstring(..#SupportedCommands), $get(commandInfo)) || ..Initialized {
        return $$$OK
    }

    set ..TimeStampStart = $zdatetime($horolog,-2)
    // TO-DO: obfuscate sensitive information like credentials in the command before logging
    set ..Command = fullCommand
    set moduleName = $get(commandInfo("parameters","module"), "module-not-parsed")

    try {
        // Convert namespace to lowercase and replace % in namespace with _ so filepath is valid
        set normalizedNamespace = $translate($zconvert(..%namespace, "L"), "%", "_")

        // Create log directory: Either the path specified in the LogFileDir modifier or default <IRIS-mgr>/<namespace>/ipm-logs/
        if $$$HasData(commandInfo,"LogFileDir") {
            set logDir = ##class(%File).NormalizeDirectory($$$GetData(commandInfo, "LogFileDir"))
        } else {
            set mgr = ##class(%Library.File).ManagerDirectory()
            set logDir = ##class(%File).NormalizeDirectory(mgr _ normalizedNamespace _ "/ipm-logs/")
        }
        $$$ThrowOnError(##class(%File).CreateDirectoryChain(logDir))

        // Set file paths with timestamp
        set baseFileName = $get(commandInfo, "command-not-parsed") _ "_" _ moduleName _ "_" _ ..TimeStampStart
        set jsonFilePath = logDir _ baseFileName _ ".jsonl"
        set txtFilePath = logDir _ baseFileName _ ".txt"

        // Write log file path to terminal
        write !, "Writing to the following log files: "_jsonFilePath_" and "_txtFilePath

        // Get IPM version. GetVersion() returns per-module info in versionInfo("zpm") as $lb(namespace, version).
        do ##class(%IPM.Main).GetVersion("zpm", .versionInfo)
        set ipmVersion = $listget($get(versionInfo("zpm")), 2, "IPM version not found")


        // Write TXT header
        set txtStream = ##class(%Stream.FileCharacter).%New()
        set txtStream.Filename = txtFilePath
        do txtStream.WriteLine("IPM Version: " _ ipmVersion)
        do txtStream.WriteLine("Command: "_"'"_..Command_"'")
        $$$ThrowOnError(txtStream.%Save())

        // Write the JSON Lines header as the first record; subsequent lines are log entries.
        set header = ##class(%DynamicObject).%New()
        // TODO: Replace hardcoded schema path with global IPM log schema setting
        do header.%Set("$schema", "https://raw.githubusercontent.com/intersystems/ipm/main/schemas/ipm-log/" _ ..SchemaVersion)
        set header.ipm = ipmVersion
        set header.command = ..Command

        set jsonStream = ##class(%Stream.FileCharacter).%New()
        set jsonStream.Filename = jsonFilePath
        do jsonStream.WriteLine(header.%ToJSON())
        $$$ThrowOnError(jsonStream.%Save())

        // Only set properties after initialization was completed without errors
        set ..JSONFilePath = jsonFilePath
        set ..TxtFilePath = txtFilePath

        return $$$OK
    }
    catch ex
    {
        return ex.AsStatus()
    }
}

/// Write a log entry to both the JSON Lines and TXT files.
/// @Argument message           The human-readable log message to append
/// @Argument level             The log level: TRACE, INFO, WARNING, or ERROR. If none supplied, defaults to INFO
/// @Argument writeToTerminal   If set to 1, write line to terminal, regardless of the default verbosity setting
Method WriteLogLine(
	message As %String,
	level As %String = "INFO",
	writeToTerminal As %Boolean = 0) As %Status
{
    try
    {
        set verbose = ..Verbose || writeToTerminal
        if (verbose) {
            write !, message
        }
        if '..Initialized {
            return $$$OK
        }

        if '$listfind($listfromstring(..#LogLevels), level) {
            set errMsg = "Attempted to write to log with invalid log level '"_level_"'. Please ensure log level is one of: "_..#LogLevels_$$$NL_"Attempted message to log was: "_message
            do ..WriteLogLine(errMsg, "ERROR")
            $$$ThrowOnError($$$ERROR($$$GeneralError, errMsg))
        }

        set timestamp = $zdatetime($ztimestamp, 3) _ " UTC"

        // Skip writing to .jsonl file if message is empty string
        if (message '= "") {
            set entry = ##class(%DynamicObject).%New()
            set entry.level = level
            // Terminal echo above keeps ANSI color; the log files get a stripped copy.
            set entry.message = ..StripControlSequences(message)
            set entry.timestamp = timestamp

            // Append one NDJSON record; no full-file read/parse required.
            set jsonStream = ##class(%Stream.FileCharacter).%New()
            set jsonStream.Filename = ..JSONFilePath
            $$$ThrowOnError(jsonStream.MoveToEnd())
            do jsonStream.WriteLine(entry.%ToJSON())
            $$$ThrowOnError(jsonStream.%Save())
        }

        // Append to TXT file
        set txtStream = ##class(%Stream.FileCharacter).%New()
        set txtStream.Filename = ..TxtFilePath
        $$$ThrowOnError(txtStream.MoveToEnd())
        do txtStream.WriteLine(timestamp _ " [" _ level _ "] " _ message)
        $$$ThrowOnError(txtStream.%Save())

        return $$$OK
    }
    catch ex
    {
        return ex.AsStatus()
    }
}

/// Write a standard final "Logging Complete" message to both the JSON and TXT log files and mark log as no longer initialized
Method Finalize()
{
    if (..Initialized) {
        $$$ThrowOnError(..WriteLogLine("Logging COMPLETE", "INFO"))
        set ..JSONFilePath = ""
        set ..TxtFilePath = ""
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

/// Install a chained output-capture tee that routes IRIS-native output into the log in real
/// time while still forwarding it live down the redirect chain (terminal or an outer capture).
/// Each logical line (one per newline) is sent to <method>WriteLogLine</method>.
/// Pair with <method>EndChainedCaptureToLog</method>. The predecessor handler is recorded so this
/// coexists with an already-active <class>%IPM.Utils.Module</class> capture or the test harness.
/// @Argument writeToTerminal   Controls live forwarding up the redirect chain. When 0, forwarding
///                             is blocked, so output reaches the log only and not the terminal or
///                             any outer capture.
ClassMethod BeginChainedCaptureToLog(writeToTerminal As %Boolean = 0) [ ProcedureBlock = 0 ]
{
    new priorIOHandler

    if $data($$$IPMLogCapture("active")) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Chained log capture already active"))
    }

    // Record the previous redirect handler so that it can be restored once EndChainedCaptureToLog is called.
    if ##class(%Device).ReDirectIO() {
        set priorIOHandler = $zutil(96,12)
    } else {
        set priorIOHandler = ""
    }
    // This is safeguard for the case that redirection from this method is still on but the $$$IPMLogCapture metadata somehow got wiped,
    // since priorIOHandler = $zname would cause out() to re-enter wstr() in an infinite loop
    if (priorIOHandler = $zname) {
        set priorIOHandler = ""
    }
    set $$$IPMLogCapture("priorIOHandler") = priorIOHandler
    set $$$IPMLogCapture("line") = ""
    set $$$IPMLogCapture("writeToTerminal") = writeToTerminal
    set $$$IPMLogCapture("active") = 1

    // Install this routine's labels as the device mnemonic routine and switch interception on.
    use $io::("^"_$zname)
    do ##class(%Device).ReDirectIO(1)
    quit

    // --- Device redirection entry points (called by the kernel while interception is on) ---
rstr(size,timeout) [result,readExpr,isRedirectOn] public {
    new result,readExpr,isRedirectOn
    set readExpr = "result"
    set isRedirectOn = ##class(%Device).ReDirectIO(0)
    set:$data(size) readExpr = readExpr_"#"_size
    set:$data(timeout) readExpr = readExpr_":"_timeout
    read @readExpr
    do:$data(timeout) $system.Process.IODollarTest($test)
    do ##class(%Device).ReDirectIO(isRedirectOn)
    quit result
}
wchr(char) public { do fwd($char(char)) do buf($char(char)) }
wff() public { do fwd($char(12)) do buf($char(12)) }
wnl() public { do fwd($char(13,10)) do buf($char(10)) }
wstr(string) public { do fwd(string) do buf(string) }
wtab(col) [pad] public {
    new pad
    set pad = $justify("", $select(col>$x:col-$x, 1:0))
    do fwd(pad) do buf(pad)
}
    // Forward raw bytes (ANSI intact) to the predecessor sink so the terminal still sees output
    // live, but only when the caller opted into terminal output.
fwd(string) [priorIOHandler,isRedirectOn] public {
    new priorIOHandler,isRedirectOn
    if '$get($$$IPMLogCapture("writeToTerminal")) { quit }
    set priorIOHandler = $get($$$IPMLogCapture("priorIOHandler"))
    set isRedirectOn = ##class(%Device).ReDirectIO(0)
    if (priorIOHandler '= "") {
        use $io::("^"_priorIOHandler)
        do ##class(%Device).ReDirectIO(1)
        write string
        do ##class(%Device).ReDirectIO(0)
    } else {
        write string
    }
    use $io::("^"_$zname)
    do ##class(%Device).ReDirectIO(isRedirectOn)
}
    // Assemble logical lines; on each newline flush the completed line to the log.
buf(string) [line,nl] public {
    new line,nl
    // After teardown an outer capture may reinstall this routine; without this guard the
    // nodes below would resurrect a half-populated tee and log stray lines.
    if '$data($$$IPMLogCapture("active")) { quit }
    set line = $get($$$IPMLogCapture("line"))
    set nl = $find(string,$char(10))
    while nl {
        set line = line_$extract(string,1,nl-2)
        do ##class(%IPM.General.LogManager).FlushCapturedBuffer(line)
        set line = ""
        set string = $extract(string,nl,*)
        set nl = $find(string,$char(10))
    }
    set $$$IPMLogCapture("line") = line_string
}
}

/// Remove the chained capture tee installed by <method>BeginChainedCaptureToLog</method>,
/// flushing any trailing partial line, and restore the predecessor redirect handler.
ClassMethod EndChainedCaptureToLog() [ ProcedureBlock = 0 ]
{
    new priorIOHandler,line

    if '$data($$$IPMLogCapture("active")) {
        quit
    }

    set line = $get($$$IPMLogCapture("line"))
    if (line '= "") {
        do ##class(%IPM.General.LogManager).FlushCapturedBuffer(line)
    }

    set priorIOHandler = $get($$$IPMLogCapture("priorIOHandler"))

    // Another handler was installed on top of this tee, so it sits above us in the chain and
    // restoring our prior handler would drop it. Release our state and leave the chain alone; the
    // entry points fall through to that handler once our state is gone.
    if ##class(%Device).ReDirectIO(), ($zutil(96,12) '= $zname) {
        kill $$$IPMLogCapture
        quit
    }

    if (priorIOHandler '= "") {
        use $io::("^"_priorIOHandler)
    } else {
        do ##class(%Device).ReDirectIO(0)
        use $io::("")
    }

    kill $$$IPMLogCapture
    quit
}

/// Write one captured logical line to the log. Interception is turned off for the duration so the
/// log write cannot re-enter the tee, and <property>Verbose</property> is forced off so the command's
/// verbosity does not re-echo the line. Terminal echo is handled live by <var>fwd</var> in
/// <method>BeginChainedCaptureToLog</method>, so the log write itself never echoes to the terminal.
ClassMethod FlushCapturedBuffer(pLine As %String)
{
    set st = ##class(%Device).ReDirectIO(0)
    set currentLogMgr = ..%Get(.sc)
    if $isobject(currentLogMgr) {
        set verbose = currentLogMgr.Verbose
        set currentLogMgr.Verbose = 0
        do currentLogMgr.WriteLogLine(pLine)
        set currentLogMgr.Verbose = verbose
    }
    do ##class(%Device).ReDirectIO(st)
}

/// Strip ANSI SGR control sequences (<code>ESC[...m</code>) so color codes written for the
/// terminal do not reach the log files.
ClassMethod StripControlSequences(pText As %String) As %String
{
    set esc = $char(27)_"["
    set out = ""
    set p = $find(pText, esc)
    while p {
        set out = out_$extract(pText, 1, p-$length(esc)-1)
        set pText = $extract(pText, p, *)
        set m = $find(pText, "m")
        if m {
            set pText = $extract(pText, m, *)
        } else {
            set pText = ""
        }
        set p = $find(pText, esc)
    }
    quit out_pText
}

}

