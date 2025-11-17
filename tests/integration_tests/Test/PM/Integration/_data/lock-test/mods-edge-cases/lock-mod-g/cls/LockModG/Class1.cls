Class LockModG.Class1
{

ClassMethod MethodA()
{
    write !, "This is ##class(LockModG.Class1).MethodA()"

    write !, "Now calling dependency classes (LockModRemote, LockModORAS, LockModHTTP, LockModC, LockModPerforce)"
    do ##class(LockModRemote.Class1).MethodA()
    do ##class(LockModORAS.Class1).MethodA()
    do ##class(LockModHTTP.Class1).MethodA()
    do ##class(LockModC.Class1).MethodA()
    do ##class(LockModPerforce.Class1).MethodA()
}

}
