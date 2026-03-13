Class LockModK.Class1
{

ClassMethod MethodA()
{
    write !, "This is ##class(LockModK.Class1).MethodA()"

    write !, "Now calling dependency classes (LockModC, LockModE)"
    do ##class(LockModC.Class1).MethodA()
    do ##class(LockModE.Class1).MethodA()
}

}
