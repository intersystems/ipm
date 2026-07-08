Include %IPM.Common

Class %IPM.General.OutputLog
{

/// Starts tee-ing session output to the specified file.
/// When append is 1 (default), output is appended to an existing file.
ClassMethod Start(path As %String, append As %Boolean = 1) As %Status [ ProcedureBlock = 0 ]
{
    new sc,dir,testStream
    #dim sc As %Status = $$$OK
    try {
        if $data(^||%IPM.log("active")) {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"OutputLog already active"))
        }
        set dir = ##class(%File).GetDirectory(path)
        if (dir '= "") && ('##class(%File).DirectoryExists(dir)) {
            $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(dir))
        }
        // Validate the path is writable and create the file on disk. testStream is
        // new'd so the oref is freed when Start() returns — ppg nodes do not maintain
        // object reference counts, so we never store orefs in ^||%IPM.log.
        set testStream = ##class(%Stream.FileCharacter).%New()
        $$$ThrowOnError(testStream.LinkToFile(path))
        if append { $$$ThrowOnError(testStream.MoveToEnd()) }
        $$$ThrowOnError(testStream.%Save())
        set ^||%IPM.log("path") = path
        set ^||%IPM.log("device") = $io
        set ^||%IPM.log("routine") = $zname
        set ^||%IPM.log("buf") = ""
        if $zutil(82,12) {
            set ^||%IPM.log("prior") = $zutil(96,12)
        } else {
            set ^||%IPM.log("prior") = ""
        }
        use $io::("^"_$zname)
        do $zutil(82,12,1)
        set ^||%IPM.log("active") = 1
    } catch ex {
        set sc = ex.AsStatus()
    }
    quit sc

   #; Echo s to the prior redirect chain (if any) or to the raw device.
out(s) public {
    if ^||%IPM.log("prior") '= "" {
        use $io::("^"_^||%IPM.log("prior"))
        do $zutil(82,12,1)
        write s
        use $io::("^"_^||%IPM.log("routine"))
        do $zutil(82,12,1)
    } else {
        set rd=$zutil(82,12,0)
        use ^||%IPM.log("device")
        write s
        use $io::("^"_^||%IPM.log("routine"))
        do $zutil(82,12,rd)
    }
  }
rstr(sz,to) [rt] public {
    new rt set vr="rt"
    set rd=$zutil(82,12,0)
    use ^||%IPM.log("device")
    set:$data(sz) vr=vr_"#"_sz set:$data(to) vr=vr_":"_to
    read @vr
    do:$data(to) $zutil(96,4,$test)
    use $io::("^"_^||%IPM.log("routine"))
    do $zutil(82,12,rd)
    quit rt
  }
rchr(to) [rc] public {
    new rc set vr="rc#1"
    set rd=$zutil(82,12,0)
    use ^||%IPM.log("device")
    set:$data(to) vr=vr_":"_to
    read @vr
    use $io::("^"_^||%IPM.log("routine"))
    do $zutil(82,12,rd)
    quit rc
  }
wchr(s) public { do out($char(s)) set ^||%IPM.log("buf")=$get(^||%IPM.log("buf"))_$char(s) }
wff() public {
    do out($char(12))
    set %ipmLogPath=$get(^||%IPM.log("path"))
    if %ipmLogPath '= "" {
        set %ipmLogSt=##class(%Stream.FileCharacter).%New()
        do %ipmLogSt.LinkToFile(%ipmLogPath) do %ipmLogSt.MoveToEnd()
        do %ipmLogSt.Write($zstrip($get(^||%IPM.log("buf")),"*C")_$char(12))
        do %ipmLogSt.%Save()
    }
    set ^||%IPM.log("buf")=""
  }
wnl() public {
    do out($char(10))
    set %ipmLogPath=$get(^||%IPM.log("path"))
    if %ipmLogPath '= "" {
        set %ipmLogSt=##class(%Stream.FileCharacter).%New()
        do %ipmLogSt.LinkToFile(%ipmLogPath) do %ipmLogSt.MoveToEnd()
        do %ipmLogSt.Write($zstrip($get(^||%IPM.log("buf")),"*C"))
        do %ipmLogSt.Write($char(10))
        do %ipmLogSt.%Save()
    }
    set ^||%IPM.log("buf")=""
  }
wstr(s) public { do out(s) set ^||%IPM.log("buf")=$get(^||%IPM.log("buf"))_s }
wtab(s) public { set p=$justify("",s-$x) do out(p) set ^||%IPM.log("buf")=$get(^||%IPM.log("buf"))_p }
}

/// Appends a delimiter line to the active log file marking the start of a command.
/// The header is file-only; it does not appear on the terminal.
ClassMethod WriteCommandHeader(command As %String, namespace As %String)
{
    if '$data(^||%IPM.log("active")) {
        return
    }
    set logPath = $get(^||%IPM.log("path"))
    if logPath = "" { return }
    set h = $horolog
    set timestamp = $zdate(h,3)_" "_$ztime($piece(h,",",2))
    set s = ##class(%Stream.FileCharacter).%New()
    do s.LinkToFile(logPath)
    do s.MoveToEnd()
    do s.Write($char(10))
    do s.WriteLine("--- ["_timestamp_"] ["_namespace_"] "_command_" ---")
    do s.%Save()
}

/// Stops the active tee, flushing and saving the log file.
/// Safe to call when no log is active.
ClassMethod Stop() As %Status
{
    set sc = $$$OK
    try {
        if '$data(^||%IPM.log("active")) {
            return $$$OK
        }
        set remaining = $get(^||%IPM.log("buf"))
        if remaining '= "" {
            set logPath = $get(^||%IPM.log("path"))
            if logPath '= "" {
                set s = ##class(%Stream.FileCharacter).%New()
                do s.LinkToFile(logPath)
                do s.MoveToEnd()
                do s.Write($zstrip(remaining,"*C"))
                set sc = s.%Save()
            }
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
