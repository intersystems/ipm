Include (%IPM.Common, %IPM.Formatting)

/// Integration tests for OutputLog tee functionality.
Class Test.PM.Integration.OutputLog Extends %UnitTest.TestCase
{

Parameter NEEDSREGISTRY As BOOLEAN = 0;

Property TempDir As %String;

Property SavedLogDir As %String;

Property SavedAutoLog As %String;

Method OnBeforeOneTest(testname As %String) As %Status
{
    set ..TempDir = ##class(%File).NormalizeDirectory(##class(%File).ManagerDirectory() _ "ipm-test-outputlog-" _ $job)
    do ##class(%File).CreateDirectoryChain(..TempDir)
    set ..SavedLogDir = ##class(%IPM.Repo.UniversalSettings).GetValue(##class(%IPM.Repo.UniversalSettings).#LogDirectory)
    set ..SavedAutoLog = ##class(%IPM.Repo.UniversalSettings).GetValue(##class(%IPM.Repo.UniversalSettings).#AutoLog)
    return $$$OK
}

Method OnAfterOneTest(testname As %String) As %Status
{
    // Clean up any leaked OutputLog state
    do ##class(%IPM.General.OutputLog).Stop()
    // The AutoLog path is deliberately per-process, so it must be cleared between tests
    do ##class(%IPM.General.OutputLog).ClearAutoLog()
    // Clean up any leaked BeginCaptureOutput state
    if $data(^||%capture) {
        set junk = ""
        do ##class(%IPM.Utils.Module).EndCaptureOutput(.junk, .junk)
    }
    // Restore settings
    if ..SavedLogDir '= "" {
        do ##class(%IPM.Repo.UniversalSettings).UpdateOne(##class(%IPM.Repo.UniversalSettings).#LogDirectory, ..SavedLogDir)
    } else {
        do ##class(%IPM.Repo.UniversalSettings).ResetToDefault(##class(%IPM.Repo.UniversalSettings).#LogDirectory)
    }
    if ..SavedAutoLog '= "" {
        do ##class(%IPM.Repo.UniversalSettings).UpdateOne(##class(%IPM.Repo.UniversalSettings).#AutoLog, ..SavedAutoLog)
    } else {
        do ##class(%IPM.Repo.UniversalSettings).ResetToDefault(##class(%IPM.Repo.UniversalSettings).#AutoLog)
    }
    do ##class(%File).RemoveDirectoryTree(..TempDir)
    return $$$OK
}

ClassMethod ReadFile(path As %String) As %String
{
    set s = ##class(%Stream.FileCharacter).%New()
    do s.LinkToFile(path)
    return s.Read(s.Size)
}

/// Explicit -log-file: file created with header and command output.
Method TestExplicitLogFile()
{
    set logPath = ..TempDir _ "explicit.log"
    set sc = ##class(%IPM.Main).Shell("version -log-file " _ logPath)
    do $$$AssertStatusOK(sc, "version with -log-file succeeded")
    do $$$AssertTrue(##class(%File).Exists(logPath), "Log file created")
    set content = ..ReadFile(logPath)
    do $$$AssertTrue(content '= "", "Log file not empty")
    do $$$AssertTrue(content [ "---", "Log has header delimiter")
    do $$$AssertTrue(content [ $namespace, "Log has namespace")
}

/// Tee equivalence: command output (beyond the file-only header) appears on the device.
Method TestTeeEquivalence()
{
    set logPath = ..TempDir _ "tee-equiv.log"
    set capSC = ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    if $$$ISERR(capSC) {
        do $$$AssertStatusOK(capSC, "BeginCaptureOutput succeeded")
        return
    }
    set sc = ##class(%IPM.Main).Shell("version -log-file " _ logPath)
    do ##class(%IPM.General.OutputLog).Stop()
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .captured)

    do $$$AssertStatusOK(sc, "version command succeeded")

    set rawFile = ..ReadFile(logPath)
    do $$$AssertTrue(rawFile '= "", "File copy non-empty")

    // Build ANSI-stripped capture string
    set strippedCapture = ""
    set i = ""
    for {
        set i = $order(captured(i), 1, line)
        quit:i=""
        set strippedCapture = strippedCapture _ $zstrip(line,"*C")
    }
    do $$$AssertTrue(strippedCapture '= "", "Device output captured")

    // Skip the file-only header by finding the second LF in the raw file.
    // WriteCommandHeader writes: LF + "--- [...] ---" + LF + content
    // Avoid line-by-line parsing which is fragile across CRLF/LF platforms.
    set pos1 = $find(rawFile, $char(10))
    set pos2 = $select(pos1 > 0: $find(rawFile, $char(10), pos1), 1: 0)
    if pos2 > 0 {
        set fileBody = $zstrip($extract(rawFile, pos2, *), "*C")
        if fileBody '= "" {
            set token = $extract(fileBody, 1, 15)
            do $$$AssertTrue(strippedCapture [ token, "Tee body appears on device: "_token)
        } else {
            do $$$AssertTrue(0, "File has no content beyond header")
        }
    } else {
        do $$$AssertTrue(0, "File missing expected header structure")
    }
}

/// ANSI stripping: log file must not contain ESC or the printable tail of a CSI sequence.
Method TestANSIStripping()
{
    set logPath = ..TempDir _ "ansi.log"
    set sc = ##class(%IPM.Main).Shell("version -log-file " _ logPath)
    do $$$AssertStatusOK(sc, "version succeeded")
    if ##class(%File).Exists(logPath) {
        set content = ..ReadFile(logPath)
        do $$$AssertTrue(content '[ $char(27), "No ESC character in log file")
        do $$$AssertTrue(content '[ "[0m", "No CSI reset residue in log file")
        do $$$AssertTrue(content '[ "[39m", "No CSI color residue in log file")
    }
}

/// Column tracking: `write ?n` indentation and non-ASCII bullets survive into the log.
Method TestIndentationAndEncoding()
{
    set logPath = ..TempDir _ "indent.log"
    set sc = ##class(%IPM.Main).Shell("help help -log-file " _ logPath)
    do $$$AssertStatusOK(sc, "help help succeeded")
    set content = ..ReadFile(logPath)
    do $$$AssertTrue(content [ ($char(10) _ "    " _ $char(9632)), "?n indentation present before bullet")
    do $$$AssertTrue(content [ $char(9632), "Black square preserved (UTF8 translate table)")
    do $$$AssertTrue(content [ $char(9675), "Bullet point preserved (UTF8 translate table)")
}

/// Append mode: second invocation grows the file.
Method TestAppendMode()
{
    set logPath = ..TempDir _ "append.log"
    set sc = ##class(%IPM.Main).Shell("version -log-file " _ logPath)
    do $$$AssertStatusOK(sc, "First version succeeded")
    set size1 = ##class(%File).GetFileSize(logPath)
    do $$$AssertTrue(size1 > 0, "File created after first run")

    set sc = ##class(%IPM.Main).Shell("version -log-file " _ logPath)
    do $$$AssertStatusOK(sc, "Second version succeeded")
    set size2 = ##class(%File).GetFileSize(logPath)
    do $$$AssertTrue(size2 > size1, "File grew (append mode)")
}

/// Bare-name resolution: bare filename resolves under LogDirectory.
Method TestBareNameResolution()
{
    set sc = ##class(%IPM.Repo.UniversalSettings).UpdateOne(##class(%IPM.Repo.UniversalSettings).#LogDirectory, ..TempDir)
    $$$ThrowOnError(sc)
    set sc = ##class(%IPM.Main).Shell("version -log-file bare.log")
    do $$$AssertStatusOK(sc, "version with bare name succeeded")
    set expectedPath = ..TempDir _ "bare.log"
    do $$$AssertTrue(##class(%File).Exists(expectedPath), "Bare name resolved under LogDirectory")
}

/// Header format: log header contains timestamp brackets, namespace, and command.
Method TestHeaderFormat()
{
    set logPath = ..TempDir _ "header.log"
    set sc = ##class(%IPM.Main).Shell("version -log-file " _ logPath)
    do $$$AssertStatusOK(sc, "version succeeded")
    set content = ..ReadFile(logPath)
    do $$$AssertTrue(content [ "--- [", "Header has opening delimiter")
    do $$$AssertTrue(content [ "] [", "Header has namespace bracket")
    do $$$AssertTrue(content [ "version", "Header contains command name")
    do $$$AssertTrue(content [ $namespace, "Header contains namespace")
}

/// AutoLog: session log created automatically when AutoLog=1.
Method TestAutoLog()
{
    set sc = ##class(%IPM.Repo.UniversalSettings).UpdateOne(##class(%IPM.Repo.UniversalSettings).#LogDirectory, ..TempDir)
    $$$ThrowOnError(sc)
    set sc = ##class(%IPM.Repo.UniversalSettings).UpdateOne(##class(%IPM.Repo.UniversalSettings).#AutoLog, "1")
    $$$ThrowOnError(sc)
    set sc = ##class(%IPM.Main).Shell("version")
    do ##class(%IPM.General.OutputLog).Stop()
    do $$$AssertStatusOK(sc, "version under AutoLog succeeded")
    // ipm-*.log file should exist in TempDir
    set found = 0
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Name FROM %Library.File_FileSet(?, ?)",
        ..TempDir, "ipm-*.log")
    while rs.%Next() { set found = found + 1 }
    do $$$AssertTrue(found >= 1, "AutoLog created ipm-*.log file")
}

/// AutoLog: separate commands in one process share a single log file.
Method TestAutoLogSharedFile()
{
    set sc = ##class(%IPM.Repo.UniversalSettings).UpdateOne(##class(%IPM.Repo.UniversalSettings).#LogDirectory, ..TempDir)
    $$$ThrowOnError(sc)
    set sc = ##class(%IPM.Repo.UniversalSettings).UpdateOne(##class(%IPM.Repo.UniversalSettings).#AutoLog, "1")
    $$$ThrowOnError(sc)
    for i = 1:1:3 {
        set sc = ##class(%IPM.Main).Shell("version")
        do $$$AssertStatusOK(sc, "version " _ i _ " under AutoLog succeeded")
        do ##class(%IPM.General.OutputLog).Stop()
    }
    set found = 0
    set path = ""
    set rs = ##class(%SQL.Statement).%ExecDirect(,
        "SELECT Name FROM %Library.File_FileSet(?, ?)",
        ..TempDir, "ipm-*.log")
    while rs.%Next() {
        set found = found + 1
        set path = rs.Name
    }
    do $$$AssertEquals(found, 1, "Three commands wrote one AutoLog file")
    if found = 1 {
        set content = ..ReadFile(path)
        do $$$AssertEquals($length(content, "--- [") - 1, 3, "Log holds three command headers")
    }
}

/// Config validation: AutoLog rejects non-boolean.
Method TestAutoLogValidation()
{
    set sc = ##class(%IPM.Repo.UniversalSettings).UpdateOne(##class(%IPM.Repo.UniversalSettings).#AutoLog, "2")
    do $$$AssertStatusNotOK(sc, "AutoLog=2 rejected")
    set sc = ##class(%IPM.Repo.UniversalSettings).UpdateOne(##class(%IPM.Repo.UniversalSettings).#AutoLog, "abc")
    do $$$AssertStatusNotOK(sc, "AutoLog=abc rejected")
    set sc = ##class(%IPM.Repo.UniversalSettings).UpdateOne(##class(%IPM.Repo.UniversalSettings).#AutoLog, "1")
    do $$$AssertStatusOK(sc, "AutoLog=1 accepted")
    set sc = ##class(%IPM.Repo.UniversalSettings).UpdateOne(##class(%IPM.Repo.UniversalSettings).#AutoLog, "0")
    do $$$AssertStatusOK(sc, "AutoLog=0 accepted")
}

/// Zero-cost path: without -log-file and AutoLog off, OutputLog stays inactive.
Method TestZeroCostPath()
{
    do ##class(%IPM.General.OutputLog).Stop()
    do $$$AssertTrue('##class(%IPM.General.OutputLog).IsActive(), "No log active before command")
    set sc = ##class(%IPM.Main).Shell("version")
    do $$$AssertStatusOK(sc, "version without log succeeded")
    do $$$AssertTrue('##class(%IPM.General.OutputLog).IsActive(), "OutputLog inactive after plain version")
}

}
