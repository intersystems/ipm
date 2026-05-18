Class Test.PM.Unit.Module Extends %UnitTest.TestCase
{

Method TestEvaluateAttribute()
{
  set tModule = ##class(%IPM.Storage.Module).%New()
  set tModule.Root = "/tmp/foo/bar"

  set tests = $listbuild(
    "${cspdir}","{$cspdir}",
    "${cspdir}","{$cspdir}",
    "${namespace}","{$namespace}",
    "${ns}","{$ns}",
    "${mgrdir}","{$mgrdir}",
    "${cspdir}","{$cspdir}",
    "${root}","{$root}",
    "${bindir}","{$bindir}",
    "${libdir}","{$libdir}",
    "${verbose}","{$verbose}",
    "${packagename}","{$packagename}",
    "${version}","{$version}"
  )
  for i=1:1:$listlength(tests) {
    set test = $listget(tests, i)
    do $$$AssertNotTrue(tModule.%Evaluate(test)=test, test)
  }
  do $$$AssertEquals(tModule.%Evaluate("#{..Root}"),tModule.Root)
}

Method TestEvaluateMacro()
{
  do $$$AssertEquals(##class(%IPM.Utils.Module).%EvaluateMacro("$$$ "), "$$$ ")
  do $$$AssertEquals(##class(%IPM.Utils.Module).%EvaluateMacro("Hello $$$OK $$$RandomJibberish123 World"), "Hello 1  World")
  do $$$AssertEquals(##class(%IPM.Utils.Module).%EvaluateMacro("Hello $$$OK$$$RandomJibberish123 World"), "Hello 1 World")
  do $$$AssertEquals(##class(%IPM.Utils.Module).%EvaluateMacro("$$$AutheUnauthenticated + $$$AutheCache + MAGIC"), $$$AutheUnauthenticated _ " + " _ $$$AutheCache _ " + MAGIC")
}

Method TestGetModuleDefaultsFromXML()
{
  do ##class(%IPM.Utils.Module).GetModuleDefaultsFromXML("/home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/module-defaults/", .defaults)
  do $$$AssertEquals(defaults("ArbitraryDefault"), 1234)
  do $$$AssertEquals(defaults("NoLock"), 1)
  do $$$AssertEquals(defaults("Verbose"), 1)

  set count = 0
  set key = $order(defaults(""))
  while (key'="") {
    set count = count + 1
    set key = $order(defaults(key))
  }
  do $$$AssertEquals(count, 3)
}

Method TestFixUndefinedCLIGenCommand()
{
	set webAppList = "/test/test"
	set path = ##class(%File).NormalizeDirectory("test-path")
    set template = ##class(%IPM.Storage.ModuleTemplate).NewTemplate(path, "testmodule", "1.0.0", "test module verification", "testmod")
    set sc = template.AddWebApps(webAppList, .tCSPapps)
    do $$$AssertStatusOK(sc, "AddWebApps method must now process web app list without error.")
}

Method TestResolveAllVariables()
{
    //Setup Test Data
    set customParams("count") = 7
    set customParams("version") = "1.0.0"
    set customParams("datadefaultcspdir") = "${cspdir}"
    set customParams("datadefaultmgrdir") = "${mgrdir}"
    set customParams("dataversion") = "${version}"
    set customParams("dataDefaultTest2") = "${datadefaultcspdir}xdata"
    set customParams("dataDefaultTest3") = "${dataDefaultTest2}xtest"
    set customParams("datapath") = "${libdir}data/"
    set customParams("ipmdir") = "/usr/irissys/mgr/user/mts"
    set customParams("datapath1") = "${ipmdir}data/"
    set customParams("mTestVersion") = "${dataDefaultTest2}/xtest/${version}"
    set customParams("mTestPlaceHolder") = "${dataDefaultTest2}/xtest/${version}${mgrdir}${mTestVersion}${datapath1}"

    //  Frankenstein Variable Assembly
    // These variables test the "Multi-Pass" capability of the resolver.
    // It must first resolve 'start', 'middle', and 'end' to build a new
    // valid placeholder string ("${namespace}"), and then resolve that
    // string against the System Dictionary in a subsequent pass.
    set customParams("start") = "${"
    set customParams("middle") = "namespace"
    set customParams("end") = "}"
    set customParams("frankenstein") = "${start}${middle}${end}"

    merge customParamsIn = customParams
    // output
    set customParamsOut("count")=7
    set customParamsOut("dataDefaultTest2")="/usr/irissys/csp/xdata"
    set customParamsOut("dataDefaultTest3")="/usr/irissys/csp/xdataxtest"
    set customParamsOut("datadefaultcspdir")=##class(%IPM.Utils.Module).%EvaluateSystemExpression("${cspdir}")
    set customParamsOut("datadefaultmgrdir")=##class(%IPM.Utils.Module).%EvaluateSystemExpression("${mgrdir}")
    set customParamsOut("datapath")=##class(%IPM.Utils.Module).%EvaluateSystemExpression("${libdir}")_"data/"
    set customParamsOut("datapath1")="/usr/irissys/mgr/user/mtsdata/"
    set customParamsOut("dataversion")="1.0.0"
    set customParamsOut("ipmdir")="/usr/irissys/mgr/user/mts"
    set customParamsOut("mTestPlaceHolder")="/usr/irissys/csp/xdata/xtest/1.0.0/usr/irissys/mgr//usr/irissys/csp/xdata/xtest/1.0.0/usr/irissys/mgr/user/mtsdata/"
    set customParamsOut("mTestVersion")="/usr/irissys/csp/xdata/xtest/1.0.0"
    set customParamsOut("version")="1.0.0"
    set customParamsOut("start") = "${"
    set customParamsOut("middle") = "namespace"
    set customParamsOut("end") = "}"
    set customParamsOut("frankenstein") = "USER"
    do ##class(%IPM.Storage.ModuleSetting.Default).ResolvePlaceholders(.customParams)

    do $$$LogMessage("Validate all placholder variables")
    set variable=""
    for {
        set variable = $order(customParams(variable))
        quit:variable=""
        do $$$AssertEquals(customParams(variable), customParamsOut(variable), variable_" is resolved correctly and the placeholder "_customParamsIn(variable)_" value is "_customParamsOut(variable))
    }
}

}
