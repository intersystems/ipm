Class LockModH.Class1
{

ClassMethod MethodA()
{
    write !, "This is LockModH v3 ##class(LockModH.Class1).MethodA()"

    write !, "Now calling dependency classes (LockModA, LockModB, LockModE)"
    do ##class(LockModA.Class1).MethodA()
    do ##class(LockModB.Class1).MethodA()
    do ##class(LockModE.Class1).MethodA()
}

}
