Class LockModH.Class1
{

/// Method renamed from MethodA in v2 to MethodB in v3
ClassMethod MethodB()
{
    write !, "This is LockModH v3 ##class(LockModH.Class1).MethodB()"

    write !, "Now calling dependency classes (LockModE, LockModB)"
    do ##class(LockModE.Class1).MethodA()
    do ##class(LockModB.Class1).MethodA()
}

}
