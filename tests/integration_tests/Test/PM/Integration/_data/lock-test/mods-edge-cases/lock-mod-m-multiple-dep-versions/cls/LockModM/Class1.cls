Class LockModM.Class1
{

/// Calls dependency modules installed via "install"
ClassMethod MethodInstall()
{
    write !, "This is LockModM ##class(LockModH.Class1).MethodA()"

    write !, "Now calling dependency classes (LockModH v2.1.0)"
    do ##class(LockModH.Class1).MethodB()
}

/// Calls dependency modules installed via lock file
ClassMethod MethodLock()
{
    write !, "This is LockModM ##class(LockModH.Class1).MethodA()"

    write !, "Now calling dependency classes (LockModH v2.0.0)"
    do ##class(LockModH.Class1).MethodA()
}

}
