# PackageManager

[![Gitter](https://img.shields.io/badge/chat-on%20telegram-blue.svg)](https://t.me/joinchat/FoZ4Mw58zQJwtbLzQrty3Q)


PackageManager for InterSystems IRIS

# Install PackageManager:

1. Download the  [latest version](https://pm.community.intersystems.com/packages/zpm/latest/installer) of zpm from the registry
2. Load with compile to IRIS in any available way (Managemenet Portal, Studio or Terminal)
 
 Now you can use PackageManager to install modules from global repository.
 
# Install a Module:

1. In the terminal, call this command to inter zpm shell:
> USER> zpm  

2. Now you can load any module that resides in any of the defined repos into IRIS:
> zpm: USER> install webterminal  

3. To see all available modules which you can install:
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
> zpm 0.0.6

# To uninstall a module:
> USER> zpm  
>
> zpm: USER> uninstall webterminal
