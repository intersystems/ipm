# ObjectScript Package Manager Client - ZPM

[![Gitter](https://img.shields.io/badge/chat-on%20telegram-blue.svg)](https://t.me/joinchat/FoZ4Mw58zQJwtbLzQrty3Q)

Helps to install ObjectScript, CSP and Frontend packages into InterSystems IRIS published on [ZPM Registry](https://pm.community.intersystems.com/packages/-/all)

## Installing ObjectScript Package Manager Client:

1. Download the  [latest version](https://pm.community.intersystems.com/packages/zpm/latest/installer) of zpm from the registry
2. Import the zpm.xml into IRIS and compile via any desired way (Managemenet Portal, Studio or Terminal)
 
 After that you can use PackageManager to install modules from [community repository](pm.community.intersystems.com) in any namespace.

3. Check if you call a zpm in command line and get the following:
USER>zpm
zpm: USER>
 
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
This is described int the [following set of aticles](https://community.intersystems.com/tags/objectscript-package-manager)

The simplest and template repository [could be found here](https://openexchange.intersystems.com/package/objectscript-package-example).
Here is the [alternative supported folder structure.](https://openexchange.intersystems.com/package/objectscript-package-template)


## Support and Collaboration
ObjectScript Package Manager is a community supported project and thus open to collaboration via Pull Requests.
Issues and feature requests [are very welcome](https://github.com/intersystems-community/zpm/issues)
