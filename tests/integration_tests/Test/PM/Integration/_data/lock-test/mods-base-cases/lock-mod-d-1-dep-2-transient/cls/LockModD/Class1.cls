Class LockModD.Class1
{

ClassMethod MethodA()
{
    write !, "This is ##class(LockModD.Class1).MethodA()"

    write !, "Now calling dependency classes (LockModC)"
    do ##class(LockModC.Class1).MethodA()
}

}
