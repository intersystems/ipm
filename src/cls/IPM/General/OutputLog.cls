Include %IPM.Common

Class %IPM.General.OutputLog
{

/// Starts tee-ing session output to the specified file.
/// When append is 1 (default), output is appended to an existing file.
ClassMethod Start(path As %String, append As %Boolean = 1) As %Status [ ProcedureBlock = 0 ]
{
    new sc,dir
    #dim sc As %Status = $$$OK
    // Checked outside the try because the catch below tears down ^||%IPM.log, which on
    // this path belongs to the tee that is already running.
    if $data(^||%IPM.log("active")) {
        quit $$$ERROR($$$GeneralError,"OutputLog already active")
    }
    try {
        set dir = ##class(%File).GetDirectory(path)
        if (dir '= "") && ('##class(%File).DirectoryExists(dir)) {
            $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(dir))
        }
        // The open both validates writability and creates the file, and the device stays
        // open for the life of the session so each line costs one append rather than a
        // reopen. Sequential file devices are named by path, so nothing stored here is an
        // oref: ppg nodes do not maintain object reference counts.
        if append {
            open path:("WAS"::32767:/IOTABLE="UTF8"):5
        } else {
            open path:("WNS"::32767:/IOTABLE="UTF8"):5
        }
        if '$test {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"Could not open log file "_path))
        }
        set ^||%IPM.log("path") = path
        set ^||%IPM.log("device") = $io
        set ^||%IPM.log("routine") = $zname
        set ^||%IPM.log("buf") = ""
        // Redirection does not maintain $X, so the tee tracks the printable column
        // itself; wtab() needs it to honor `write ?n`.
        set ^||%IPM.log("col") = 0
        if $zutil(82,12) {
            set ^||%IPM.log("prior") = $zutil(96,12)
        } else {
            set ^||%IPM.log("prior") = ""
        }
        // A stale redirect pointing back here would make out() re-enter wstr() until
        // <FRAMESTACK>; there is nothing to chain to in that case.
        if ^||%IPM.log("prior") = $zname {
            set ^||%IPM.log("prior") = ""
        }
        use $io::("^"_$zname)
        do $zutil(82,12,1)
        set ^||%IPM.log("active") = 1
    } catch ex {
        set sc = ex.AsStatus()
        // Nothing installed the redirect, so Stop() will not run; close the device here.
        if $data(^||%IPM.log("path")) {
            close ^||%IPM.log("path")
            kill ^||%IPM.log
        }
    }
    quit sc

    // Echo s to the prior redirect chain (if any) or to the raw device. Every state read
    // goes through $get and detach() covers the missing case: an error raised inside a
    // redirect entry point is reported by writing, which re-enters here until <FRAMESTACK>.
out(s) [rd,rt] public {
    new rd,rt
    set rt=$get(^||%IPM.log("routine"))
    if rt="" { do detach(s) quit }
    if $get(^||%IPM.log("prior")) '= "" {
        use $io::("^"_^||%IPM.log("prior"))
        do $zutil(82,12,1)
        write s
        use $io::("^"_rt)
        do $zutil(82,12,1)
    } else {
        set rd=$zutil(82,12,0)
        use $get(^||%IPM.log("device"))
        write s
        use $io::("^"_rt)
        do $zutil(82,12,rd)
    }
  }
    // Redirection still points here but the tee state is gone, so there is nothing left to
    // forward through. Uninstall and write straight to the device.
detach(s) public {
    do $zutil(82,12,0)
    use $io::("")
    write s
  }
    // Reinstall this routine as the handler and restore rd. With the state gone there is
    // no name to reinstall, so leave redirection off rather than `use $io::("^")`.
reattach(rd) [rt] public {
    new rt
    set rt=$get(^||%IPM.log("routine"))
    if rt="" {
        do $zutil(82,12,0)
        use $io::("")
        quit
    }
    use $io::("^"_rt)
    do $zutil(82,12,rd)
  }
rstr(sz,to) [rt,rd,vr] public {
    new rt,rd,vr set vr="rt"
    set rd=$zutil(82,12,0)
    use $get(^||%IPM.log("device"))
    set:$data(sz) vr=vr_"#"_sz set:$data(to) vr=vr_":"_to
    read @vr
    do:$data(to) $zutil(96,4,$test)
    do reattach(rd)
    quit rt
  }
rchr(to) [rc,rd,vr] public {
    new rc,rd,vr set vr="rc#1"
    set rd=$zutil(82,12,0)
    use $get(^||%IPM.log("device"))
    set:$data(to) vr=vr_":"_to
    read @vr
    do reattach(rd)
    quit rc
  }
    // Echo `write !` or `write #` so a terminal gets CR+LF and a prior redirect chain
    // gets its own wnl()/wff() entry point.
outctl(c) [rd,rt] public {
    new rd,rt
    set rt=$get(^||%IPM.log("routine"))
    if rt="" { do detach($select(c="!":$char(13,10),1:$char(12))) quit }
    if $get(^||%IPM.log("prior")) '= "" {
        use $io::("^"_^||%IPM.log("prior"))
        do $zutil(82,12,1)
        if c="!" { write ! } else { write # }
        use $io::("^"_rt)
        do $zutil(82,12,1)
    } else {
        set rd=$zutil(82,12,0)
        use $get(^||%IPM.log("device"))
        if c="!" { write ! } else { write # }
        use $io::("^"_rt)
        do $zutil(82,12,rd)
    }
  }
    // Buffer is kept ANSI-stripped so flushes and column tracking need no rescan.
    // $x is restored last because out() issues `use`, which zeroes it.
buf(s) [clean] public {
    new clean
    // Without this the nodes below would resurrect a half-populated tee after Stop().
    if '$data(^||%IPM.log("active")) { quit }
    set clean=$replace(##class(%IPM.General.OutputLog).StripAnsi(s),$char(13),"")
    set ^||%IPM.log("buf")=$get(^||%IPM.log("buf"))_clean
    // A payload can carry its own newlines, so count only what follows the last one.
    if clean[$char(10) {
        set ^||%IPM.log("col")=$length($piece(clean,$char(10),$length(clean,$char(10))))
    } else {
        set ^||%IPM.log("col")=$get(^||%IPM.log("col"))+$length(clean)
    }
    set $x=^||%IPM.log("col")
  }
flush(tail) public {
    if '$data(^||%IPM.log("active")) { set $x=0 quit }
    set ^||%IPM.log("buf")=$get(^||%IPM.log("buf"))_tail
    do ##class(%IPM.General.OutputLog).FlushBuffer()
    set ^||%IPM.log("col")=0
    set $x=0
  }
    // Control characters go to the device only, so the buffer cannot capture part of an
    // escape sequence written one character at a time.
wchr(s) public { do out($char(s)) do:s'<32 buf($char(s)) }
wff() public { do outctl("#") do flush($char(12)) }
wnl() public { do outctl("!") do flush($char(10)) }
wstr(s) public { do out(s) do buf(s) }
wtab(s) [col,pad] public {
    new col,pad
    set col=$get(^||%IPM.log("col"))
    set pad=$justify("",$select(s>col:s-col,1:0))
    do out(pad) do buf(pad)
  }
}

/// Removes ANSI escape sequences, including the printable parameter and final bytes of
/// a CSI sequence.
ClassMethod StripAnsi(text As %String) As %String
{
    if text '[ $char(27) {
        return text
    }
    set stripped = ""
    set pos = 1
    for {
        // $find returns the position past the ESC, so the ESC itself is at afterEsc-1
        set afterEsc = $find(text, $char(27), pos)
        if 'afterEsc {
            set stripped = stripped _ $extract(text, pos, *)
            quit
        }
        set stripped = stripped _ $extract(text, pos, afterEsc - 2)
        if $extract(text, afterEsc) = "[" {
            // CSI parameter and intermediate bytes are 0x20-0x3F, final byte is 0x40-0x7E
            set i = afterEsc + 1
            while (i <= $length(text)) && ($ascii(text, i) < 64) {
                set i = i + 1
            }
            set pos = i + 1
        } else {
            set pos = afterEsc + 1
        }
    }
    return stripped
}

/// Appends pending output to the log file and clears the buffer.
ClassMethod FlushBuffer()
{
    set buffer = $get(^||%IPM.log("buf"))
    if buffer = "" {
        return
    }
    set ^||%IPM.log("buf") = ""
    set logPath = $get(^||%IPM.log("path"))
    if logPath = "" {
        return
    }
    // Redirection is process-wide, so it must be off while writing to the log device or
    // the write is captured and recurses.
    set principal = $io
    // The installed handler is not necessarily this tee: BeginCaptureOutput() and friends
    // layer on top of it, and reinstalling ourselves would take their writes.
    set handler = $select($zutil(82,12): $zutil(96,12), 1: "")
    set redirect = $zutil(82,12,0)
    try {
        use logPath
        write buffer
    } catch {
        // This runs inside device redirection, where throwing would surface as a
        // failure of whatever unrelated code was writing. Drop the path instead so
        // the tee degrades to terminal-only output.
        set ^||%IPM.log("path") = ""
    }
    if handler = "" {
        use principal::("")
        return
    }
    use principal::("^"_handler)
    do $zutil(82,12,redirect)
}

/// Appends a delimiter line to the active log file marking the start of a command.
/// The header is file-only; it does not appear on the terminal.
ClassMethod WriteCommandHeader(command As %String, namespace As %String)
{
    if '$data(^||%IPM.log("active")) {
        return
    }
    set h = $horolog
    set timestamp = $zdate(h,3)_" "_$ztime($piece(h,",",2))
    // Appended to the buffer rather than written directly so the header cannot
    // overtake output still pending from the previous command.
    set header = $char(10)_"--- ["_timestamp_"] ["_namespace_"] "_command_" ---"_$char(10)
    set ^||%IPM.log("buf") = $get(^||%IPM.log("buf"))_header
    do ..FlushBuffer()
}

/// Starts a tee to this process's AutoLog file. The path is chosen on first use and
/// reused (in append mode) for the rest of the process, so the many commands a single
/// process may run (a test run drives dozens) all land in one transcript.
ClassMethod StartAutoLog() As %Status
{
    if $get(^||%IPM.autolog("failed")) {
        return $$$OK
    }
    set path = $get(^||%IPM.autolog("path"))
    if path '= "" {
        set sc = ..Start(path, 1)
    } else {
        set dir = ##class(%IPM.Repo.UniversalSettings).GetLogDirectory()
        set h = $horolog
        set stem = dir _ "ipm-" _ $zdate(h,3) _ "-" _ $translate($ztime($piece(h,",",2)), ":") _ "-" _ $job
        set path = stem _ ".log"
        set suffix = 0
        while ##class(%File).Exists(path) {
            set suffix = suffix + 1
            set path = stem _ "-" _ suffix _ ".log"
        }
        set sc = ..Start(path, 0)
    }
    if $$$ISERR(sc) {
        // Recorded so later commands in this process neither retry nor re-warn.
        set ^||%IPM.autolog("failed") = 1
        return sc
    }
    set ^||%IPM.autolog("path") = path
    return $$$OK
}

/// Forgets the AutoLog path and any recorded failure, so the next StartAutoLog() picks
/// a fresh file. Intended for tests; a real process keeps one AutoLog for its lifetime.
ClassMethod ClearAutoLog() [ Internal ]
{
    kill ^||%IPM.autolog
}

/// Reinstalls this tee if it is active but interception has been switched off, which is
/// what an excursion that suspended redirection and did not restore it leaves behind.
/// Called at command boundaries so a missed $$$RestoreRedirection costs one command's output
/// rather than the rest of the session. Must be called from a namespace with the %IPM.*
/// routine mapping, since `use` names the handler routine.
ClassMethod Resume()
{
    if '$data(^||%IPM.log("active")) {
        return
    }
    if $zutil(82,12) {
        return
    }
    set routine = $get(^||%IPM.log("routine"))
    if routine = "" {
        return
    }
    use $io::("^"_routine)
    do $zutil(82,12,1)
}

/// Stops the active tee, flushing and closing the log file.
/// Safe to call when no log is active.
ClassMethod Stop() As %Status
{
    set sc = $$$OK
    set logPath = $get(^||%IPM.log("path"))
    try {
        if '$data(^||%IPM.log("active")) {
            return $$$OK
        }
        do ..FlushBuffer()
        // Another handler was installed after this tee, so it sits on top of the chain and
        // restoring our prior would drop it. Release the file and leave the chain alone;
        // the entry points fall through to the device once the state is gone.
        if $zutil(82,12), $zutil(96,12) '= $get(^||%IPM.log("routine")) {
            if logPath '= "" { close logPath }
            kill ^||%IPM.log
            return $$$OK
        }
        set prior = $get(^||%IPM.log("prior"))
        if prior '= "" {
            use $io::("^"_prior)
        } else {
            do $zutil(82,12,0)
            use $io::("")
        }
    } catch ex {
        set sc = ex.AsStatus()
        do $zutil(82,12,0)
        use $io::("")
    }
    if logPath '= "" { close logPath }
    kill ^||%IPM.log
    return sc
}

/// Returns 1 if a log session is currently active, 0 otherwise.
ClassMethod IsActive() As %Boolean
{
    return $data(^||%IPM.log("active")) > 0
}

/// Returns the path of the active log file, or "" if no log is active.
ClassMethod GetActivePath() As %String
{
    return $get(^||%IPM.log("path"))
}

}
