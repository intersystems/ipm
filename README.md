# InterSystems Package Manager - IPM

Helps to install ObjectScript classes and routines, globals, Embedded Python modules, CSP and front-end packages, and more into InterSystems IRIS, from a variety of sources:
* InterSystems-official packages from [pm.intersystems.com](https://pm.intersystems.com/#/packages) or an upcoming [ORAS](https://oras.land/)-based registry
* The [Community Package Registry](https://pm.community.intersystems.com/packages/-/all), driven by the [Open Exchange](https://openexchange.intersystems.com/)
* Your own private [ORAS registry](https://oras.land/adopters) or IRIS-based [zpm-registry](https://github.com/intersystems-community/zpm-registry)

## Documentation
* [The official documentation in the wiki](https://github.com/intersystems-community/zpm/wiki/)
* [Articles on the InterSystems Developer Community](https://community.intersystems.com/tags/objectscript-package-manager-zpm)
* [Videos on YouTube](https://www.youtube.com/playlist?list=PLKb2cBVphNQRcmxt4LtYDyLJEPfF4X4-4)

## Installing the InterSystems Package Manager Client:

The simplest way to install the latest version of IPM is to run the following ObjectScript snippet with a user that has the %ALL role.

_In CI/CD scripts, for deterministic behavior, replace `version="latest"` with the specific IPM version desired._

```
s version="latest" s r=##class(%Net.HttpRequest).%New(),r.Server="pm.community.intersystems.com",r.SSLConfiguration="ISC.FeatureTracker.SSL.Config" d r.Get("/packages/zpm/"_version_"/installer"),$system.OBJ.LoadStream(r.HttpResponse.Data,"c")
```

**IPM 0.9.0+ can be installed with different versions and registry settings per namespace, and does not have the [community package registry](https://openexchange.intersystems.com/?zpm=1) enabled by default. If you want the legacy (<=0.7.x) behavior of a system-wide installation and access to community packages in all namespaces, run `zpm "enable -community"` after installing IPM. See `zpm "help enable"` for details.**

To enable the community package registry without the rest of the legacy behavior, run:

```
zpm
repo -r -n registry -url https://pm.community.intersystems.com/ -user "" -pass ""
```

As an alternative installation method, if IRIS does not have access to the internet:

1. Download the [latest version](https://pm.community.intersystems.com/packages/zpm/latest/installer) of zpm from the registry
2. Import `zpm.xml` into IRIS and compile via any available method (Management Portal, Studio or Terminal - `do $System.OBJ.Load("/path/to/zpm.xml","ck")`)
3. (optional) Run `zpm "enable -community"` to enable instance-wide and with a connection to the [community package registry](https://pm.community.intersystems.com)
4. To verify the installation, ensure that you can run `zpm` in Terminal/`iris session` and get the following:

```
USER>zpm
zpm: USER>
```

## InterSystems IRIS / IPM Compatibility Matrix

| IPM Version    | IRIS Version               |
|----------------|----------------------------|
| 0.10.x         | >2022.1                    |
| 0.9.x          | Any                        |
| <0.9.x         | <2025.1                    |

## Compatibility Notes

With IPM version 0.10.4+ "install packagename" will be blocked if `packagename` is installed in the current namespace and the newer version has `UpdatePackage` defined in module.xml. This behavior can be overridden with -force flag.

With the release of IPM v0.9.0 on December 2024, IPM is no longer mapped across namespaces.
This is an intentional change so that users can have different IPM versions and configurations in different namespaces.
If you install IPM on an instance without the legacy 0.7.x version, IPM is only installed to the current namespace.

* To retain the old behavior where %IPM routines and classes mapped across all namespaces, run `zpm "enable -map -globally`. This is automatically performed when upgrading from a legacy version and can be undone by running `zpm "unmap -globally"`.
* You can optionally choose to map IPM repositories across namespaces with `zpm "enable -map -repos -namespaces NS1,NS2,NS3` or `zpm "enable -map -repos -globally`. Repositories are only mapped if %IPM classes and routines are also mapped from the same namespace.
* As a convenience command, `zpm "enable -community"` will make IPM behave essentially the same as legacy versions (v0.7.x) by setting up the the community registry and maping %IPM routines and classes, as well IPM repository settings to all namespaces.

## How to Install a ZPM Module:

1. Call this command to open zpm shell:
> USER> zpm

2. See the list of available modules:
> zpm: USER>repo -list-modules -n registry
>
> deepseebuttons 0.1.7
> dsw 2.1.35
> holefoods 0.1.0
> isc-dev 1.2.0
> mdx2json 2.2.0
> objectscript 1.0.0
> pivotsubscriptions 0.0.3
> restforms 1.6.1
> thirdpartychartportlets 0.0.1
> webterminal 4.8.3
> zpm 0.0.7

3. You can load any module that resides in any of the defined repos into IRIS. E.g. here is the way to install webterminal:
> zpm: USER> install webterminal

## To uninstall a module:
> USER> zpm
>
> zpm: USER> uninstall webterminal

## How to submit modules
This is described in the [following set of articles](https://community.intersystems.com/tags/objectscript-package-manager)

The simplest and template repository [can be found here](https://openexchange.intersystems.com/package/objectscript-package-example).
Here is the [alternative supported folder structure.](https://openexchange.intersystems.com/package/objectscript-package-template)

## Support and Collaboration
Refer to [CONTRIBUTING.md](CONTRIBUTING.md) for best development practices.
ObjectScript Package Manager is a community supported project and thus open to collaboration via Pull Requests.
Issues and feature requests [are very welcome](https://github.com/intersystems-community/zpm/issues)
