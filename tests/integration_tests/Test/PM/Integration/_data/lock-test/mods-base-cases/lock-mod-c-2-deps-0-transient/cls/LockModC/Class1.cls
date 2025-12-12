Class LockModC.Class1
{

ClassMethod MethodA()
{
    write !, "This is ##class(LockModC.Class1).MethodA()"

    write !, "Now calling dependency classes (LockModA, LockModB)"
    do ##class(LockModA.Class1).MethodA()
    do ##class(LockModB.Class1).MethodA()
}

}
