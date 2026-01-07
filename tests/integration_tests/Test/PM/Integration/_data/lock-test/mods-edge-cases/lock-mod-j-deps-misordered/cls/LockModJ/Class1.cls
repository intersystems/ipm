Class LockModJ.Class1
{

ClassMethod MethodA()
{
    write !, "This is ##class(LockModJ.Class1).MethodA()"

    write !, "Now calling dependency classes (LockModC)"
    do ##class(LockModC.Class1).MethodA()
}

}
