Class %IPM.Repo.Oras.ArtifactMetadata Extends (%RegisteredObject, %JSON.Adaptor)
{

/// See https://github.com/opencontainers/image-spec/blob/main/annotations.md
Property ImageTitle As %IPM.DataType.ModuleName(%JSONFIELDNAME = "org.opencontainers.image.title");

Property ImageDescription As %IPM.DataType.LongString(%JSONFIELDNAME = "org.opencontainers.image.description");

Property ImageVersion As %IPM.DataType.LongString(%JSONFIELDNAME = "org.opencontainers.image.version");

Property ImageSource As %IPM.DataType.LongString(%JSONFIELDNAME = "org.opencontainers.image.source");

Property ImageCreated As %String(%JSONFIELDNAME = "org.opencontainers.image.created");

Property IPMAllVersions As %IPM.DataType.LongString(%JSONFIELDNAME = "com.intersystems.ipm.allVersions");

Property IPMOrigin As %IPM.DataType.LongString(%JSONFIELDNAME = "com.intersystems.ipm.origin");

Property IPMDeployed As %String(%JSONFIELDNAME = "com.intersystems.ipm.deployed");

Property IPMModuleV1XML As %IPM.DataType.LongString(%JSONFIELDNAME = "com.intersystems.ipm.module.v1+xml");

Property IPMPlatformVersion As %String(%JSONFIELDNAME = "com.intersystems.ipm.platformVersion");

}
