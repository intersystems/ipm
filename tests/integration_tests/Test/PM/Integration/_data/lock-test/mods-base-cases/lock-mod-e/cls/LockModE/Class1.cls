Class LockModE.Class1
{

ClassMethod MethodA()
{
    write !, "This is ##class(LockModE.Class1).MethodA()"

    write !, "Now calling dependency classes (LockModA)"
    do ##class(LockModA.Class1).MethodA()
}

}
