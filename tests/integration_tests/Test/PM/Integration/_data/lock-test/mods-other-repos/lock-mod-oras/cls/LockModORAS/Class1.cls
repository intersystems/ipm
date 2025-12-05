Class LockModORAS.Class1
{

ClassMethod MethodA()
{
    write !, "This is ##class(LockModORAS.Class1).MethodA()"

    write !, "Now calling dependency classes (LockModRemote, LockModC)"
    do ##class(LockModRemote.Class1).MethodA()
    do ##class(LockModC.Class1).MethodA()
}

}
