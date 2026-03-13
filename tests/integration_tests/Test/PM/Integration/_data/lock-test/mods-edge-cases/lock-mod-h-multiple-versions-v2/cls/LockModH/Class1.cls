Class LockModH.Class1
{

ClassMethod MethodA()
{
    write !, "This is LockModH v2 ##class(LockModH.Class1).MethodA()"

    write !, "Now calling dependency classes (LockModB, LockModE)"
    do ##class(LockModB.Class1).MethodA()
    do ##class(LockModE.Class1).MethodA()
}

}
