/// I/O redirect routine that discards all writes.
/// Used as the mnemonic device routine for BeginSuppressOutput / EndSuppressOutput.
/// Unlike BeginCaptureOutput, suppress does not use ^||%capture, so it is safe
/// to call while a capture is already active.
Class %IPM.Utils.OutputSuppressor
{

ClassMethod Begin(Output pCookie As %String) As %Status [ ProcedureBlock = 0 ]
{
    new tSC,e

    #dim tSC As %Status = $$$OK
    #dim e As %Exception.AbstractException

    try {
        if $zutil(82,12) {
            set pCookie=$zutil(96,12)
        } else {
            set pCookie=""
        }

        use $io::("^"_$zname)

        do $zutil(82,12,1)

    } catch (e) {
        set tSC=e.AsStatus()
    }
    quit tSC

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

ClassMethod End(pCookie As %String) As %Status
{
    if pCookie '= "" {
        use $io::("^"_pCookie)
    } else {
        do $zutil(82,12,0)
        use $io::("")
    }
    quit $$$OK
}

}
