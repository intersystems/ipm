Class LockModG.Class1
{

ClassMethod MethodA()
{
    write !, "This is ##class(LockModG.Class1).MethodA()"

    write !, "Now calling dependency classes (LockModRemote, LockModORAS, LockModC)"
    do ##class(LockModRemote.Class1).MethodA()
    do ##class(LockModORAS.Class1).MethodA()
    do ##class(LockModC.Class1).MethodA()
}

}
