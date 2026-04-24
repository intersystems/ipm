/// I/O redirect routine that discards all writes.
/// Modeled after CaptureOutput, but instead of capturing output to a variable, it simply discards it.
/// Used as the mnemonic device routine for BeginSuppressOutput / EndSuppressOutput.
/// Unlike BeginCaptureOutput, suppress does not use ^||%capture, so it is safe
/// to call while a capture is already active.
Class %IPM.Utils.OutputSuppressor
{

ClassMethod Begin(Output cookie As %String) As %Status [ ProcedureBlock = 0 ]
{
    new sc,ex

    #dim sc As %Status = $$$OK
    #dim ex As %Exception.AbstractException

    try {
        if $zutil(82,12) {
            set cookie=$zutil(96,12)
        } else {
            set cookie=""
        }

        use $io::("^"_$zname)

        do $zutil(82,12,1)

    } catch (ex) {
        set sc=ex.AsStatus()
    }
    quit sc

rstr(sz,to) [rt] public {
    new rt set vr="rt"
    set rd=$zutil(82,12,0)
    set:$data(sz) vr=vr_"#"_sz set:$data(to) vr=vr_":"_to
    read @vr
    do:$data(to) $zutil(96,4,$test)
    do $zutil(82,12,rd)
    quit rt
  }
wchr(s) public { }
wff() public { }
wnl() public { }
wstr(s) public { }
wtab(s) public { }
write(s) public { }
}

ClassMethod End(cookie As %String) As %Status
{
    if cookie '= "" {
        use $io::("^"_cookie)
    } else {
        do $zutil(82,12,0)
        use $io::("")
    }
    quit $$$OK
}

}
