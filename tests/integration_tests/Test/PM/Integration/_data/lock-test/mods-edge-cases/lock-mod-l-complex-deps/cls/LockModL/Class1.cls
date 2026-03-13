Class LockModL.Class1
{

ClassMethod MethodA()
{
    write !, "This is ##class(LockModL.Class1).MethodA()"

    write !, "Now calling dependency classes (LockModD, LockModE, LockModF)"
    do ##class(LockModD.Class1).MethodA()
    do ##class(LockModE.Class1).MethodA()
    do ##class(LockModF.Class1).MethodA()
}

}
