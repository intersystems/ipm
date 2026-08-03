Class SimpleModule.Main
{

ClassMethod GetMessage() As %String
{
    return "Hello from Simple DB Module"
}

ClassMethod Add(
	a As %Integer,
	b As %Integer) As %Integer
{
    return a + b
}

}
